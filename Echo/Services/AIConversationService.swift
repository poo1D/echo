import Foundation

/// AI对话服务 - 集成 ModelScope Kimi-K2.5 API
@Observable @MainActor
final class AIConversationService {
    // MARK: - Properties
    var messages: [ConversationMessage] = []
    var isStreaming = false
    var currentStreamingText = ""
    var errorMessage: String?
    
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
    private let systemPrompt = """
    你是一个温暖、善解人意的情绪陪伴助手。你的任务是：
    1. 认真倾听用户的日记内容
    2. 识别其中的情绪线索
    3. 用温和的追问帮助用户深入反思
    4. 给予适当的情感支持和建议
    
    风格要求：
    - 语气温柔、不说教
    - 提问要具体，避免空泛
    - 每次回复控制在2-3句话
    - 适时使用emoji增加亲和力
    """
    
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

