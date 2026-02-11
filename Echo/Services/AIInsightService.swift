import Foundation

/// AI洞察生成服务
@Observable @MainActor
final class AIInsightService {
    // MARK: - Properties
    var isProcessing = false
    var errorMessage: String?
    
    // 情绪关键词库
    private let positiveKeywords = ["开心", "高兴", "快乐", "满足", "感恩", "幸福", "兴奋", "期待", "放松", "平静", "舒适", "享受", "成功", "进步", "happy", "joy", "grateful", "excited", "peaceful"]
    private let negativeKeywords = ["难过", "伤心", "焦虑", "压力", "疲惫", "烦躁", "失望", "担心", "紧张", "孤独", "沮丧", "frustrated", "stressed", "tired", "sad", "worried", "anxious"]
    private let growthKeywords = ["学习", "进步", "成长", "突破", "尝试", "挑战", "目标", "计划", "反思", "改变", "learn", "grow", "improve", "goal", "challenge"]
    
    // MARK: - Generate Insight
    func generateInsight(for entry: JournalEntry, recentEntries: [JournalEntry] = []) async -> AIInsight {
        isProcessing = true
        defer { isProcessing = false }
        
        let content = entry.textContent
        
        // 分析情绪
        let moodTags = analyzeMood(content)
        let moodAnalysis = generateMoodAnalysis(moodTags: moodTags)
        
        // 生成摘要
        let summary = generateSummary(content)
        
        // 检测模式（如果有历史记录）
        let pattern = detectPattern(currentEntry: entry, recentEntries: recentEntries)
        
        // 生成成长建议
        let suggestion = generateGrowthSuggestion(moodTags: moodTags, content: content)
        
        let insight = AIInsight(summary: summary, moodAnalysis: moodAnalysis)
        insight.moodTags = moodTags
        insight.patternDetected = pattern
        insight.growthSuggestion = suggestion
        
        return insight
    }
    
    // MARK: - Mood Analysis
    private func analyzeMood(_ content: String) -> [String] {
        var tags: [String] = []
        
        // 检测积极情绪
        let positiveCount = positiveKeywords.filter { content.contains($0) }.count
        if positiveCount > 0 {
            tags.append("积极")
        }
        
        // 检测消极情绪
        let negativeCount = negativeKeywords.filter { content.contains($0) }.count
        if negativeCount > 0 {
            tags.append("需要关注")
        }
        
        // 检测成长相关
        let growthCount = growthKeywords.filter { content.contains($0) }.count
        if growthCount > 0 {
            tags.append("成长中")
        }
        
        // 默认标签
        if tags.isEmpty {
            tags.append("平静")
        }
        
        return tags
    }
    
    private func generateMoodAnalysis(moodTags: [String]) -> String {
        if moodTags.contains("积极") && moodTags.contains("成长中") {
            return "今天你的状态非常好，同时还在积极成长！"
        } else if moodTags.contains("积极") {
            return "今天的心情不错，继续保持！"
        } else if moodTags.contains("需要关注") {
            return "注意到一些压力信号，记得给自己一些放松时间。"
        } else if moodTags.contains("成长中") {
            return "你正在不断进步，这是很棒的状态！"
        } else {
            return "今天是平静的一天。"
        }
    }
    
    // MARK: - Summary Generation
    private func generateSummary(_ content: String) -> String {
        // 简单的摘要生成：取前100个字符
        let maxLength = 100
        if content.count <= maxLength {
            return content
        }
        
        let endIndex = content.index(content.startIndex, offsetBy: maxLength)
        return String(content[..<endIndex]) + "..."
    }
    
    // MARK: - Pattern Detection
    private func detectPattern(currentEntry: JournalEntry, recentEntries: [JournalEntry]) -> String? {
        guard recentEntries.count >= 3 else { return nil }
        
        // 分析写作时间模式
        let hours = recentEntries.map { Calendar.current.component(.hour, from: $0.createdAt) }
        let avgHour = hours.reduce(0, +) / hours.count
        
        if avgHour >= 21 || avgHour <= 5 {
            return "你习惯在夜间记录，这是独处反思的好时光"
        } else if avgHour >= 6 && avgHour <= 9 {
            return "晨间日记帮助你更好地规划一天"
        }
        
        // 分析连续记录
        let streak = calculateStreak(entries: recentEntries)
        if streak >= 7 {
            return "连续记录\(streak)天，你的坚持让人钦佩！"
        }
        
        return nil
    }
    
    private func calculateStreak(entries: [JournalEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        
        let sortedEntries = entries.sorted { $0.createdAt > $1.createdAt }
        var streak = 1
        var currentDate = Calendar.current.startOfDay(for: sortedEntries[0].createdAt)
        
        for i in 1..<sortedEntries.count {
            let entryDate = Calendar.current.startOfDay(for: sortedEntries[i].createdAt)
            let expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            
            if Calendar.current.isDate(entryDate, inSameDayAs: expectedDate) {
                streak += 1
                currentDate = entryDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Growth Suggestion
    private func generateGrowthSuggestion(moodTags: [String], content: String) -> String? {
        if moodTags.contains("需要关注") {
            return "试试花5分钟做深呼吸，或者写下三件让你感恩的事情。"
        }
        
        if moodTags.contains("成长中") {
            return "为自己的进步庆祝一下吧！小小的奖励能增强动力。"
        }
        
        if content.count < 50 {
            return "试着多写一点，详细的记录能帮助你更好地回顾和反思。"
        }
        
        return nil
    }
}
