import Foundation

/// AI气泡分析服务 - 使用大模型分析日记生成气泡内容
@Observable @MainActor
final class AIBubbleAnalyzer {
    static let shared = AIBubbleAnalyzer()
    
    private let apiEndpoint = APIConfig.apiEndpoint
    private var apiKey: String { APIConfig.apiKey }
    private let modelId = "moonshotai/Kimi-K2.5"
    
    var isAnalyzing = false
    
    private init() {}
    
    /// 分析日记内容，返回4个气泡的内容
    func analyzeJournal(_ content: String) async -> BubbleContents {
        guard !content.isEmpty else {
            return BubbleContents.default
        }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let prompt = """
        你是一个温暖的情感陪伴助手。请分析以下日记内容，并返回JSON格式的4条回复：

        日记内容：
        \(content)

        请返回严格的JSON格式（不要有其他文字）：
        {
            "mood": "一句话描述用户今天的心情，温暖共情，如'今天有点累呢，抱抱你'",
            "hug": "一句温暖的陪伴话语，如'无论发生什么，我都在这里'",
            "schedule": "如果日记提到任何日程/会议/约会/截止日期，提醒用户，如'明天9点的会议，我陪你准备！'；如果没有日程就写'今天专注当下就好~'",
            "growth": "关于成长或鼓励的话，如'每一天的记录都是成长的印记'"
        }
        """
        
        do {
            let response = try await callAPI(prompt: prompt)
            return parseBubbleContents(from: response)
        } catch {
            print("AI分析失败: \(error)")
            return BubbleContents.default
        }
    }
    
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
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    private func parseBubbleContents(from response: String) -> BubbleContents {
        // 尝试提取JSON部分
        var jsonString = response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            jsonString = String(response[startIndex...endIndex])
        }
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return BubbleContents.default
        }
        
        return BubbleContents(
            mood: json["mood"] ?? BubbleContents.default.mood,
            hug: json["hug"] ?? BubbleContents.default.hug,
            schedule: json["schedule"] ?? BubbleContents.default.schedule,
            growth: json["growth"] ?? BubbleContents.default.growth
        )
    }
}

// MARK: - Bubble Contents
struct BubbleContents {
    let mood: String
    let hug: String
    let schedule: String
    let growth: String
    
    static let `default` = BubbleContents(
        mood: "今天心情如何？",
        hug: "我一直在这里",
        schedule: "今天专注当下就好~",
        growth: "每一天的记录都是成长的印记"
    )
}
