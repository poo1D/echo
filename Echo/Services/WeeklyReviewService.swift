import Foundation

/// 周度复盘报告生成服务
@Observable @MainActor
final class WeeklyReviewService {
    static let shared = WeeklyReviewService()
    
    private let apiEndpoint = APIConfig.apiEndpoint
    private var apiKey: String { APIConfig.apiKey }
    private let modelId = "moonshotai/Kimi-K2.5"
    
    var isGenerating = false
    var cachedReview: WeeklyReview?
    var cachedWeekKey: String? // "2026-W09" 格式，避免重复生成
    
    private init() {}
    
    // MARK: - 生成周度复盘
    
    func generateWeeklyReview(from entries: [JournalEntry]) async -> WeeklyReview {
        let weekKey = currentWeekKey()
        
        // 如果本周已生成过，直接返回缓存
        if let cached = cachedReview, cachedWeekKey == weekKey {
            return cached
        }
        
        guard !entries.isEmpty else {
            return WeeklyReview.empty(weekKey: weekKey)
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        // 准备日记内容
        let journalSummary = entries.enumerated().map { index, entry in
            let date = formatDate(entry.createdAt)
            let mood = entry.moodEmoji ?? "😐"
            return "【\(date) \(mood)】\(entry.textContent.prefix(200))"
        }.joined(separator: "\n\n")
        
        let prompt = """
        你是一个温暖的日记复盘助手。以下是用户过去一周的日记内容，请生成一份简洁的周度复盘报告。
        
        用户日记：
        \(journalSummary)
        
        请严格按以下 JSON 格式返回（不要加 markdown 代码块标记）：
        {
            "highlights": "本周亮点（1-2句话，提炼最重要的事）",
            "moodSummary": "心情走势（1句话概括整周情绪变化）",
            "growthNote": "成长观察（1句话，发现的进步或模式）",
            "suggestion": "下周建议（1句话，温柔的建议）"
        }
        """
        
        do {
            let response = try await callAPI(prompt: prompt)
            let review = parseReview(from: response, weekKey: weekKey, entryCount: entries.count)
            cachedReview = review
            cachedWeekKey = weekKey
            return review
        } catch {
            print("❌ [WeeklyReviewService] 生成失败: \(error)")
            return fallbackReview(entries: entries, weekKey: weekKey)
        }
    }
    
    // MARK: - API 调用
    
    private func callAPI(prompt: String) async throws -> String {
        guard let url = URL(string: apiEndpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 500
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
    
    // MARK: - 解析结果
    
    private func parseReview(from response: String, weekKey: String, entryCount: Int) -> WeeklyReview {
        var jsonString = response
        if let start = response.firstIndex(of: "{"),
           let end = response.lastIndex(of: "}") {
            jsonString = String(response[start...end])
        }
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return fallbackReview(entries: [], weekKey: weekKey)
        }
        
        return WeeklyReview(
            weekKey: weekKey,
            highlights: json["highlights"] as? String ?? "暂无亮点",
            moodSummary: json["moodSummary"] as? String ?? "心情平稳",
            growthNote: json["growthNote"] as? String ?? "持续记录中",
            suggestion: json["suggestion"] as? String ?? "保持记录的习惯",
            entryCount: entryCount,
            generatedAt: Date()
        )
    }
    
    // MARK: - 本地备用
    
    private func fallbackReview(entries: [JournalEntry], weekKey: String) -> WeeklyReview {
        let count = entries.count
        return WeeklyReview(
            weekKey: weekKey,
            highlights: count > 0 ? "本周你记录了 \(count) 篇日记，坚持记录本身就是最大的亮点 ✨" : "本周还没有日记记录",
            moodSummary: "继续保持对生活的感知和记录",
            growthNote: count >= 5 ? "高频率的记录说明你很重视自我觉察" : "试试每天花几分钟和 Echo 聊聊",
            suggestion: "下周试试在不同的时间段记录，发现更多生活的细节",
            entryCount: count,
            generatedAt: Date()
        )
    }
    
    // MARK: - 工具
    
    private func currentWeekKey() -> String {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(components.yearForWeekOfYear ?? 2026)-W\(String(format: "%02d", components.weekOfYear ?? 1))"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 数据模型

struct WeeklyReview {
    let weekKey: String
    let highlights: String
    let moodSummary: String
    let growthNote: String
    let suggestion: String
    let entryCount: Int
    let generatedAt: Date
    
    static func empty(weekKey: String) -> WeeklyReview {
        WeeklyReview(
            weekKey: weekKey,
            highlights: "本周还没有日记，开始和 Echo 聊聊吧 💬",
            moodSummary: "",
            growthNote: "",
            suggestion: "试试每天花几分钟记录，小小的习惯会带来大大的改变",
            entryCount: 0,
            generatedAt: Date()
        )
    }
}
