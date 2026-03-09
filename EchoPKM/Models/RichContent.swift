import Foundation

// MARK: - Rich Content Cards (embedded in assistant messages)

enum RichContent: Identifiable {
    case memoryRecall(MemoryRecallData)
    case moodTrend(MoodTrendData)
    case scheduleConfirm(ScheduleConfirmData)
    case habitStreak(HabitStreakData)
    case patternInsight(PatternInsightData)

    var id: String {
        switch self {
        case .memoryRecall(let d): return "memory-\(d.id)"
        case .moodTrend(let d): return "mood-\(d.id)"
        case .scheduleConfirm(let d): return "schedule-\(d.id)"
        case .habitStreak(let d): return "habit-\(d.id)"
        case .patternInsight(let d): return "pattern-\(d.id)"
        }
    }
}

// MARK: - Memory Recall

struct MemoryRecallData: Identifiable {
    let id = UUID()
    let date: Date
    let summary: String
    let moodEmoji: String?
    let relevanceReason: String

    init(date: Date, summary: String, moodEmoji: String? = nil, relevanceReason: String) {
        self.date = date
        self.summary = summary
        self.moodEmoji = moodEmoji
        self.relevanceReason = relevanceReason
    }

    init(from entry: DiaryEntry, reason: String) {
        self.date = entry.createdAt
        self.summary = entry.summary
        self.moodEmoji = entry.moodEmoji
        self.relevanceReason = reason
    }
}

// MARK: - Mood Trend

struct MoodTrendData: Identifiable {
    let id = UUID()
    let scores: [(date: Date, score: Int)]
    let trend: String       // "improving", "stable", "declining"
    let insight: String     // e.g., "Your mood has been improving this week"
}

// MARK: - Schedule Confirm

struct ScheduleConfirmData: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let notes: String?
    let isNew: Bool         // true if just extracted from this message

    init(title: String, date: Date, notes: String? = nil, isNew: Bool = true) {
        self.title = title
        self.date = date
        self.notes = notes
        self.isNew = isNew
    }
}

// MARK: - Habit Streak

struct HabitStreakData: Identifiable {
    let id = UUID()
    let habitName: String
    let streakCount: Int
    let change: Int         // +1, -1, 0
    let emoji: String

    init(habitName: String, streakCount: Int, change: Int = 1, emoji: String = "") {
        self.habitName = habitName
        self.streakCount = streakCount
        self.change = change
        self.emoji = emoji.isEmpty ? HabitStreakData.emojiFor(habitName) : emoji
    }

    static func emojiFor(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("exercise") || lower.contains("gym") || lower.contains("workout") { return "💪" }
        if lower.contains("cook") { return "🍳" }
        if lower.contains("read") { return "📚" }
        if lower.contains("walk") { return "🚶" }
        if lower.contains("meditat") { return "🧘" }
        if lower.contains("run") || lower.contains("jog") { return "🏃" }
        if lower.contains("yoga") { return "🧘" }
        if lower.contains("sleep") { return "😴" }
        if lower.contains("water") || lower.contains("drink") { return "💧" }
        if lower.contains("study") { return "📝" }
        if lower.contains("music") { return "🎵" }
        if lower.contains("clean") { return "🧹" }
        return "🔄"
    }
}

// MARK: - Pattern Insight

struct PatternInsightData: Identifiable {
    let id = UUID()
    let pattern: String     // e.g., "Exercise improves your mood"
    let evidence: String    // e.g., "Mood is 4.2/5 on exercise days vs 2.8/5 on others"
    let occurrences: Int
}
