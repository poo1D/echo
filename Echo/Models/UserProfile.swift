import SwiftData
import Foundation

/// 用户核心档案 — L1 层记忆，每次对话全量注入 system prompt
@Model
final class UserProfile {
    var id: UUID
    var updatedAt: Date
    
    // 基本信息
    var nickname: String?               // 用户昵称/称呼
    var personalSummary: String?        // AI 生成的用户总结（一段话）
    
    // 情绪基线
    var averageMoodScore: Double?       // 近30天平均情绪 1-10
    var moodTrend: String?              // "improving" / "stable" / "declining"
    
    // 重要偏好与关切
    var preferences: [String]           // ["喜欢听音乐", "爱喝咖啡"]
    var concerns: [String]              // ["学业压力", "睡眠不足"]
    
    // 统计
    var totalJournalCount: Int          // 累计日记篇数
    var lastJournalDate: Date?          // 最近一篇日记日期
    
    init() {
        self.id = UUID()
        self.updatedAt = Date()
        self.preferences = []
        self.concerns = []
        self.totalJournalCount = 0
    }
    
    /// 生成注入 prompt 的文本摘要
    func toPromptText() -> String {
        var parts: [String] = []
        
        if let nickname = nickname {
            parts.append("用户称呼：\(nickname)")
        }
        if let summary = personalSummary {
            parts.append("用户概况：\(summary)")
        }
        if let mood = averageMoodScore, let trend = moodTrend {
            let trendCN: String
            switch trend {
            case "improving": trendCN = "好转中"
            case "declining": trendCN = "下滑中"
            default: trendCN = "稳定"
            }
            parts.append("情绪基线：平均 \(String(format: "%.1f", mood))/10，趋势\(trendCN)")
        }
        if !preferences.isEmpty {
            parts.append("偏好：\(preferences.joined(separator: "、"))")
        }
        if !concerns.isEmpty {
            parts.append("关切：\(concerns.joined(separator: "、"))")
        }
        parts.append("累计日记：\(totalJournalCount) 篇")
        
        return parts.joined(separator: "\n")
    }
}
