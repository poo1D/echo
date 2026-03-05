import Foundation

/// 日记整理服务 — 将对话记录通过 LLM 自动整理为日记文本
@Observable @MainActor
final class JournalSummaryService {
    
    static let shared = JournalSummaryService()
    
    private let apiEndpoint = APIConfig.apiEndpoint
    private var apiKey: String { APIConfig.apiKey }
    private let modelId = "moonshotai/Kimi-K2.5"
    
    var isSummarizing = false
    
    private init() {}
    
    // MARK: - 对话整理为日记
    
    /// 将对话消息列表整理为日记文本
    func summarizeConversation(
        _ messages: [AIConversationService.ConversationMessage]
    ) async -> String {
        // 过滤出有意义的用户和 AI 消息
        let conversationText = messages
            .filter { $0.role != .system }
            .map { msg in
                let role = msg.role == .user ? "用户" : "Echo"
                return "\(role): \(msg.content)"
            }
            .joined(separator: "\n")
        
        guard !conversationText.isEmpty else {
            return ""
        }
        
        isSummarizing = true
        defer { isSummarizing = false }
        
        let prompt = """
        请将以下对话记录整理为一篇简洁的日记。
        
        ## 对话记录
        \(conversationText)
        
        ## 整理规则
        - 用第一人称（"我"）书写
        - 保留关键事件、情绪和人物
        - 不要添加对话中没提到的内容
        - 自然流畅，像真实日记
        - 控制在 50-150 字
        - 直接输出日记文本，不需要标题或额外格式
        """
        
        do {
            return try await callAPI(prompt: prompt)
        } catch {
            print("❌ [JournalSummary] 整理失败: \(error)")
            // 降级：直接拼接用户消息
            return messages
                .filter { $0.role == .user }
                .map { $0.content }
                .joined(separator: "\n")
        }
    }
    
    // MARK: - API 调用
    
    private func callAPI(prompt: String) async throws -> String {
        guard let url = URL(string: apiEndpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 300,
            "temperature": 0.5
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw URLError(.cannotParseResponse)
    }
}
