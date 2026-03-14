import Foundation

// MARK: - Health Snapshot (lightweight struct, no SwiftData)

struct HealthSnapshot {
    let steps: Int
    let sleepHours: Double
    let sleepQuality: SleepQuality
    let workoutMinutes: Int
    let weeklySteps: [(date: Date, steps: Int)]
    let weeklySleep: [(date: Date, hours: Double)]
    let insights: [HealthInsight]

    enum SleepQuality: String {
        case poor       // <5h
        case fair       // 5-6h
        case good       // 6-7.5h
        case excellent  // >7.5h

        var label: String {
            switch self {
            case .poor: return "不足"
            case .fair: return "一般"
            case .good: return "良好"
            case .excellent: return "优秀"
            }
        }

        init(hours: Double) {
            switch hours {
            case ..<5: self = .poor
            case 5..<6: self = .fair
            case 6..<7.5: self = .good
            default: self = .excellent
            }
        }
    }

    static let empty = HealthSnapshot(
        steps: 0,
        sleepHours: 0,
        sleepQuality: .fair,
        workoutMinutes: 0,
        weeklySteps: [],
        weeklySleep: [],
        insights: []
    )
}

// MARK: - Health Insight

struct HealthInsight {
    let type: InsightType
    let title: String
    let detail: String

    enum InsightType {
        case sleepWarning       // 连续睡眠不足
        case exerciseStreak     // 运动连续打卡
        case sleepImproving     // 睡眠改善
        case stepGoal           // 步数目标
    }
}
