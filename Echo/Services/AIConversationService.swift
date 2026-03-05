import Foundation
import SwiftData

/// AI对话服务 - 集成 ModelScope Kimi-K2.5 API
@Observable @MainActor
final class AIConversationService {
    // MARK: - Properties
    var messages: [ConversationMessage] = []
    var isStreaming = false
    var currentStreamingText = ""
    var errorMessage: String?
    
    // 记忆系统
    private let memoryManager = MemoryManager.shared
    private var augmentedSystemPrompt: String?
    private var userMessageCount = 0           // 追踪用户消息数，用于每 3 条刷新记忆
    private var injectedFactIDs: Set<UUID> = [] // 已注入的事实 ID，避免重复
    
    // ModelScope API 配置（从 APIConfig 读取）
    private let apiEndpoint = APIConfig.apiEndpoint
    private var apiKey: String { APIConfig.apiKey }
    private let modelId = "moonshotai/Kimi-K2.5"
    
    // MARK: - Message Types
    struct ConversationMessage: Identifiable, Equatable {
        let id = UUID()
        let role: Role
        var content: String
        let timestamp: Date
        var moodColor: MoodColor?
        
        enum Role: String, Codable {
            case user
            case assistant
            case system
        }
        
        enum MoodColor: String {
            case positive = "positive"
            case neutral = "neutral"
            case needsCare = "needsCare"
        }
    }
    
    // MARK: - System Prompt
    private let baseSystemPrompt = """
    你是 Echo，一个温暖的日记伙伴。用户正在通过和你对话来写今天的日记。
    
    你的任务：
    1. 用温柔的追问帮用户展开今天的经历和感受
    2. 识别情绪线索，引导用户表达更多细节
    3. 适时总结和共情，让用户感到被理解
    
    风格要求：
    - 每次回复只说 1-2 句话，像朋友聊天一样自然
    - 提问要具体，不要空泛（比如"什么事让你累？"而不是"今天怎么样？"）
    - 适时使用 emoji 增加亲和力
    - 不说教、不给建议，除非用户主动问
    - 如果用户只说了一句话，温柔地追问细节
    """

    
    /// 获取当前使用的 system prompt（优先使用记忆增强版本）
    private var systemPrompt: String {
        augmentedSystemPrompt ?? baseSystemPrompt
    }
    
    // MARK: - Public Methods
    
    func startConversation(with journalContent: String) async {
        let userMessage = ConversationMessage(
            role: .user,
            content: journalContent,
            timestamp: Date()
        )
        messages.append(userMessage)
        await generateResponse()
    }
    
    /// 带记忆增强的对话启动 — 会检索相关记忆注入 system prompt
    func startConversation(with journalContent: String, modelContext: ModelContext) async {
        // 检索记忆上下文
        let memoryContext = await memoryManager.retrieveContext(
            for: journalContent,
            modelContext: modelContext
        )
        
        // 构建增强 prompt
        augmentedSystemPrompt = memoryManager.buildAugmentedSystemPrompt(
            context: memoryContext,
            basePrompt: baseSystemPrompt
        )
        
        print("🧠 [AIConversation] 记忆增强已注入，事实数: \(memoryContext.relevantFacts.count)，相关日记数: \(memoryContext.relevantEntries.count)")
        
        let userMessage = ConversationMessage(
            role: .user,
            content: journalContent,
            timestamp: Date()
        )
        messages.append(userMessage)
        await generateResponse()
    }
    
    /// 带记忆增强的发送消息 — 每 3 条用户消息做一次完整记忆检索
    func sendMessage(_ content: String, modelContext: ModelContext) async {
        userMessageCount += 1
        
        // 每 3 条用户消息刷新一次记忆上下文（平衡性能和准确性）
        if userMessageCount % 3 == 0 {
            let memoryContext = await memoryManager.retrieveContext(
                for: content,
                modelContext: modelContext
            )
            augmentedSystemPrompt = memoryManager.buildAugmentedSystemPrompt(
                context: memoryContext,
                basePrompt: baseSystemPrompt
            )
            
            // 更新已注入事实集合
            injectedFactIDs = Set(memoryContext.relevantFacts.map { $0.id })
            print("🧠 [AIConversation] 第 \(userMessageCount) 条消息，刷新记忆上下文")
        }
        
        let userMessage = ConversationMessage(
            role: .user,
            content: content,
            timestamp: Date()
        )
        messages.append(userMessage)
        await generateResponse()
    }
    
    func sendMessage(_ content: String) async {
        let userMessage = ConversationMessage(
            role: .user,
            content: content,
            timestamp: Date()
        )
        messages.append(userMessage)
        await generateResponse()
    }
    
    func clearConversation() {
        messages.removeAll()
        currentStreamingText = ""
        isStreaming = false
        augmentedSystemPrompt = nil
        userMessageCount = 0
        injectedFactIDs.removeAll()
    }
    
    // MARK: - API Call
    
    private func generateResponse() async {
        isStreaming = true
        currentStreamingText = ""
        
        var aiMessage = ConversationMessage(
            role: .assistant,
            content: "",
            timestamp: Date()
        )
        messages.append(aiMessage)
        let messageIndex = messages.count - 1
        
        do {
            // 构建API请求
            var request = URLRequest(url: URL(string: apiEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 构建消息历史
            var apiMessages: [[String: Any]] = [
                ["role": "system", "content": systemPrompt]
            ]
            
            for msg in messages.dropLast() {
                apiMessages.append([
                    "role": msg.role.rawValue,
                    "content": msg.content
                ])
            }
            
            let body: [String: Any] = [
                "model": modelId,
                "messages": apiMessages,
                "stream": true
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            // 发起流式请求
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            // 解析SSE流
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { break }
                    
                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        currentStreamingText += content
                        messages[messageIndex].content = currentStreamingText
                    }
                }
            }
            
            // 分析情绪色彩
            let userContent = messages.dropLast().last?.content ?? ""
            messages[messageIndex].moodColor = analyzeMoodColor(from: userContent)
            
        } catch {
            errorMessage = "API请求失败: \(error.localizedDescription)"
            // 降级到Mock回复
            let mockResponse = generateMockResponse(for: messages.dropLast().last?.content ?? "")
            messages[messageIndex].content = mockResponse
        }
        
        isStreaming = false
        currentStreamingText = ""
    }
    
    // MARK: - Fallback Mock
    private func generateMockResponse(for content: String) -> String {
        let lowercased = content.lowercased()
        
        if lowercased.contains("累") || lowercased.contains("疲") {
            return "听起来你今天挺累的 😔 是工作上的压力，还是有其他事情让你感到疲惫呢？"
        }
        if lowercased.contains("开心") || lowercased.contains("高兴") {
            return "太好了！能感受到你今天的好心情 🌟 是什么事情让你这么开心呀？"
        }
        return "谢谢你和我分享今天的心情 ☺️ 有什么是你特别想聊聊的吗？"
    }
    
    private func analyzeMoodColor(from content: String) -> ConversationMessage.MoodColor {
        let positiveWords = ["开心", "高兴", "满足", "感恩", "幸福", "兴奋", "happy", "joy"]
        let negativeWords = ["累", "疲", "焦虑", "压力", "担心", "难过", "tired", "anxious"]
        
        let hasPositive = positiveWords.contains { content.contains($0) }
        let hasNegative = negativeWords.contains { content.contains($0) }
        
        if hasPositive && !hasNegative { return .positive }
        if hasNegative { return .needsCare }
        return .neutral
    }
}

