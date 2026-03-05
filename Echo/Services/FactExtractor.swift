import Foundation

/// LLM 事实提取服务 — 从日记文本中提取结构化事实
/// 属于写入管线的核心环节
@Observable @MainActor
final class FactExtractor {
    
    static let shared = FactExtractor()
    
    private let apiEndpoint = APIConfig.apiEndpoint
    private var apiKey: String { APIConfig.apiKey }
    private let modelId = "moonshotai/Kimi-K2.5"
    
    var isExtracting = false
    
    private init() {}
    
    // MARK: - 提取结构化事实
    
    /// 从日记文本中提取关键事实信息
    /// - Parameters:
    ///   - text: 日记文本
    ///   - entryID: 来源日记 ID
    /// - Returns: 提取出的事实记忆数组
    func extractFacts(from text: String, entryID: UUID) async -> [FactMemory] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        isExtracting = true
        defer { isExtracting = false }
        
        let prompt = """
        你是一个记忆提取助手。请从以下日记中提取关键信息，返回严格的 JSON 格式。
        
        ## 日记内容
        \(text)
        
        ## 请提取以下信息，返回 JSON 数组（不要有其他文字）：
        [
          {
            "category": "people/event/habit/preference/milestone",
            "content": "简洁描述这条事实",
            "keywords": ["关键词1", "关键词2"],
            "importance": 1到5的整数
          }
        ]
        
        ## 提取规则：
        - people: 提到的人物及关系（如"小明是同学"）
        - event: 重要事件或活动（如"参加了数学竞赛"）
        - habit: 习惯或日常行为（如"每天跑步"）
        - preference: 喜好或厌恶（如"喜欢喝咖啡"）
        - milestone: 里程碑式的成就（如"毕业了"）
        - 如果没有值得提取的信息，返回空数组 []
        - 每条事实尽量简洁，不超过30字
        - importance: 1=琐碎细节, 3=日常记录, 5=重大事件
        """
        
        do {
            let response = try await callAPI(prompt: prompt)
            return parseFactsResponse(response, entryID: entryID)
        } catch {
            print("❌ [FactExtractor] 提取失败: \(error)")
            return []
        }
    }
    
    // MARK: - 提取情绪评分
    
    /// 提取日记的情绪评分 (1-10)
    func extractMoodScore(from text: String) async -> Double? {
        guard !text.isEmpty else { return nil }
        
        let prompt = """
        请为以下日记内容打一个情绪分数（1-10，1=非常消极，5=中性，10=非常积极）。
        只返回一个数字，不要其他文字。
        
        日记：\(text)
        """
        
        do {
            let response = try await callAPI(prompt: prompt)
            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned)
        } catch {
            return nil
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
            "max_tokens": 500,
            "temperature": 0.3  // 低温度，确保结构化输出稳定
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
    
    // MARK: - 解析 LLM 返回的 JSON
    
    private func parseFactsResponse(_ response: String, entryID: UUID) -> [FactMemory] {
        // 尝试提取 JSON 数组部分
        var jsonString = response
        if let startIndex = response.firstIndex(of: "["),
           let endIndex = response.lastIndex(of: "]") {
            jsonString = String(response[startIndex...endIndex])
        }
        
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("⚠️ [FactExtractor] 无法解析 JSON: \(response.prefix(200))")
            return []
        }
        
        var facts: [FactMemory] = []
        
        for item in jsonArray {
            guard let category = item["category"] as? String,
                  let content = item["content"] as? String else {
                continue
            }
            
            let fact = FactMemory(
                category: category,
                content: content,
                sourceEntryID: entryID
            )
            
            if let keywords = item["keywords"] as? [String] {
                fact.keywords = keywords
            }
            if let importance = item["importance"] as? Int {
                fact.importance = min(max(importance, 1), 5)
            }
            
            facts.append(fact)
        }
        
        print("✅ [FactExtractor] 成功提取 \(facts.count) 条事实")
        return facts
    }
}
