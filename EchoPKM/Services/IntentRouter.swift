import Foundation

/// Local keyword-based intent classification — zero API calls, zero latency.
/// Routes user messages to the appropriate subset of agents.
struct IntentRouter {

    // MARK: - Intent Types

    enum Intent: String {
        case emotionalShare     // 情感倾诉
        case dailyCheckin       // 日常签到
        case scheduleRequest    // 日程请求
        case habitReport        // 习惯汇报
        case memoryQuery        // 记忆查询
        case healthQuery        // 健康查询
        case complexNarrative   // 复杂叙述 (default fallback)

        var label: String {
            switch self {
            case .emotionalShare: return "情感倾诉"
            case .dailyCheckin: return "日常签到"
            case .scheduleRequest: return "日程安排"
            case .habitReport: return "习惯打卡"
            case .memoryQuery: return "记忆回溯"
            case .healthQuery: return "健康查询"
            case .complexNarrative: return "深度对话"
            }
        }
    }

    // MARK: - Agent Selection

    struct AgentSelection {
        let intent: Intent
        let runEmotion: Bool
        let runMemory: Bool
        let runAction: Bool
        let runHealth: Bool

        var activeAgentCount: Int {
            [runEmotion, runMemory, runAction, runHealth].filter { $0 }.count
        }
    }

    // MARK: - Route

    func route(message: String, hasMedia: Bool = false, healthAuthorized: Bool = false) -> AgentSelection {
        let intent = classify(message: message, hasMedia: hasMedia)
        return selection(for: intent, healthAuthorized: healthAuthorized)
    }

    // MARK: - Classification

    private func classify(message: String, hasMedia: Bool) -> Intent {
        let lower = message.lowercased()
        let length = message.count

        // Schedule keywords (highest priority — very specific intent)
        let scheduleKeywords = ["提醒", "会议", "约会", "日程", "安排", "计划明天", "下周",
                                "remind", "meeting", "schedule", "appointment", "deadline",
                                "待办", "事项", "预约", "几点"]
        if scheduleKeywords.contains(where: { lower.contains($0) }) {
            return .scheduleRequest
        }

        // Health keywords
        let healthKeywords = ["睡眠", "步数", "运动", "锻炼", "健身", "跑步", "瑜伽",
                              "sleep", "steps", "workout", "exercise", "health",
                              "卡路里", "心率", "体重", "睡了", "走了", "健康"]
        let healthMatchCount = healthKeywords.filter { lower.contains($0) }.count
        if healthMatchCount >= 2 {
            return .healthQuery
        }

        // Memory query keywords
        let memoryKeywords = ["上次", "之前", "还记得", "那天", "以前", "回忆",
                              "remember", "last time", "before", "history",
                              "有没有说过", "记不记得", "什么时候"]
        if memoryKeywords.contains(where: { lower.contains($0) }) {
            return .memoryQuery
        }

        // Emotional keywords
        let emotionalKeywords = ["难过", "焦虑", "压力", "烦", "累", "开心", "高兴",
                                 "生气", "害怕", "担心", "郁闷", "沮丧", "崩溃",
                                 "sad", "anxious", "stress", "happy", "angry",
                                 "worried", "depressed", "excited", "frustrated",
                                 "孤独", "寂寞", "感动", "委屈", "心情"]
        let emotionalMatchCount = emotionalKeywords.filter { lower.contains($0) }.count

        // Habit keywords
        let habitKeywords = ["跑步", "阅读", "冥想", "做饭", "散步", "锻炼",
                             "exercise", "reading", "meditation", "cooking",
                             "yoga", "running", "walking", "习惯", "坚持", "打卡"]
        let habitMatchCount = habitKeywords.filter { lower.contains($0) }.count

        // Combined health + emotional check
        if healthMatchCount >= 1 && emotionalMatchCount >= 1 {
            return .emotionalShare
        }

        // Habit report (mentions habits + some emotional or reporting context)
        if habitMatchCount >= 2 {
            return .habitReport
        }

        // Strong emotional content
        if emotionalMatchCount >= 2 {
            return .emotionalShare
        }

        // Short messages → daily check-in
        if length < 30 && !hasMedia {
            return .dailyCheckin
        }

        // Long messages or media → complex narrative
        if length > 100 || hasMedia {
            return .complexNarrative
        }

        // Single health mention
        if healthMatchCount >= 1 {
            return .healthQuery
        }

        // Single emotional keyword
        if emotionalMatchCount >= 1 {
            return .emotionalShare
        }

        // Default: full pipeline
        return .complexNarrative
    }

    // MARK: - Agent Selection Matrix

    private func selection(for intent: Intent, healthAuthorized: Bool) -> AgentSelection {
        switch intent {
        case .emotionalShare:
            return AgentSelection(
                intent: intent,
                runEmotion: true,
                runMemory: true,
                runAction: false,
                runHealth: healthAuthorized
            )
        case .dailyCheckin:
            return AgentSelection(
                intent: intent,
                runEmotion: true,
                runMemory: false,
                runAction: false,
                runHealth: healthAuthorized
            )
        case .scheduleRequest:
            return AgentSelection(
                intent: intent,
                runEmotion: false,
                runMemory: false,
                runAction: true,
                runHealth: false
            )
        case .habitReport:
            return AgentSelection(
                intent: intent,
                runEmotion: true,
                runMemory: true,
                runAction: true,
                runHealth: healthAuthorized
            )
        case .memoryQuery:
            return AgentSelection(
                intent: intent,
                runEmotion: false,
                runMemory: true,
                runAction: false,
                runHealth: false
            )
        case .healthQuery:
            return AgentSelection(
                intent: intent,
                runEmotion: true,
                runMemory: false,
                runAction: false,
                runHealth: healthAuthorized
            )
        case .complexNarrative:
            return AgentSelection(
                intent: intent,
                runEmotion: true,
                runMemory: true,
                runAction: true,
                runHealth: healthAuthorized
            )
        }
    }
}
