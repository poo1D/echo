import Foundation

/// Generates proactive feed cards from local SwiftData queries — no LLM calls.
@Observable @MainActor
final class ProactiveGreetingService {

    /// Generate proactive cards based on current data
    func generateFeedCards(
        entries: [DiaryEntry],
        schedules: [ScheduleItem],
        habits: [HabitEntry],
        healthSnapshot: HealthSnapshot? = nil
    ) -> [FeedItem] {
        var cards: [FeedItem] = []
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // 1. Today's / tomorrow's schedule reminders
        let todaySchedules = schedules.filter { !$0.isCompleted && calendar.isDate($0.date, inSameDayAs: today) }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowSchedules = schedules.filter { !$0.isCompleted && calendar.isDate($0.date, inSameDayAs: tomorrow) }

        for schedule in todaySchedules.prefix(2) {
            let timeStr = schedule.date.formatted(date: .omitted, time: .shortened)
            cards.append(.proactiveCard(ProactiveCardData(
                icon: "calendar",
                iconColor: "4A90D9",
                title: schedule.title,
                subtitle: "今天 \(timeStr)",
                type: .schedule
            )))
        }

        for schedule in tomorrowSchedules.prefix(1) {
            let timeStr = schedule.date.formatted(date: .omitted, time: .shortened)
            cards.append(.proactiveCard(ProactiveCardData(
                icon: "calendar.badge.clock",
                iconColor: "7B68EE",
                title: schedule.title,
                subtitle: "明天 \(timeStr)",
                type: .schedule
            )))
        }

        // 2. Habit streak celebration (3+ consecutive days this week)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let thisWeekHabits = habits.filter { $0.date >= weekStart }
        var habitDays: [String: Set<Int>] = [:]
        for h in thisWeekHabits {
            let dayOfWeek = calendar.component(.weekday, from: h.date)
            habitDays[h.name, default: []].insert(dayOfWeek)
        }
        for (name, days) in habitDays where days.count >= 3 {
            let emoji = HabitStreakData.emojiFor(name)
            cards.append(.proactiveCard(ProactiveCardData(
                icon: "flame.fill",
                iconColor: "FF6B35",
                title: "\(emoji) \(name.capitalized) 连续: \(days.count)天！",
                subtitle: "继续保持！",
                type: .habit
            )))
        }

        // 3. Low mood care reminder (recent 3 entries avg mood <= 2)
        let recentMoods = entries.prefix(3).compactMap(\.moodScore)
        if recentMoods.count >= 2 {
            let avg = Double(recentMoods.reduce(0, +)) / Double(recentMoods.count)
            if avg <= 2.0 {
                cards.append(.proactiveCard(ProactiveCardData(
                    icon: "heart.fill",
                    iconColor: "E8A0BF",
                    title: "最近似乎不太容易",
                    subtitle: "随时可以和我聊聊",
                    type: .mood
                )))
            }
        }

        // 4. Yesterday's topic follow-up
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let yesterdayEntries = entries.filter { calendar.isDate($0.createdAt, inSameDayAs: yesterday) }
        if let lastEntry = yesterdayEntries.first, !lastEntry.topics.isEmpty {
            let topic = lastEntry.topics.first ?? ""
            cards.append(.proactiveCard(ProactiveCardData(
                icon: "bubble.left.fill",
                iconColor: "66CDAA",
                title: "昨天你提到了\(topic)",
                subtitle: "今天怎么样了？",
                type: .memory
            )))
        }

        // 5. Health-related proactive cards
        if let hs = healthSnapshot {
            // Sleep warning
            for insight in hs.insights {
                switch insight.type {
                case .sleepWarning:
                    cards.append(.proactiveCard(ProactiveCardData(
                        icon: "moon.zzz.fill",
                        iconColor: "7B68EE",
                        title: "昨晚只睡了\(String(format: "%.1f", hs.sleepHours))小时",
                        subtitle: "今天悠着点~",
                        type: .mood
                    )))
                case .exerciseStreak:
                    cards.append(.proactiveCard(ProactiveCardData(
                        icon: "figure.run",
                        iconColor: "4CAF50",
                        title: insight.title,
                        subtitle: insight.detail,
                        type: .habit
                    )))
                default:
                    break
                }
            }
        }

        return cards
    }

    /// Generate a smart greeting based on context
    func generateGreeting(entries: [DiaryEntry], habits: [HabitEntry], healthSnapshot: HealthSnapshot? = nil) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "早上好！"
        case 12..<17: timeGreeting = "下午好！"
        case 17..<22: timeGreeting = "晚上好！"
        default: timeGreeting = "还没睡呀？"
        }

        // Add context-aware suffix
        if let lastEntry = entries.first {
            let calendar = Calendar.current
            if calendar.isDateInYesterday(lastEntry.createdAt), !lastEntry.topics.isEmpty {
                let topic = lastEntry.topics.first ?? ""
                return "\(timeGreeting) 昨天你提到了\(topic)——今天怎么样了？"
            }
        }

        // Check habit streaks
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let weekHabits = habits.filter { $0.date >= weekStart }
        var counts: [String: Int] = [:]
        for h in weekHabits { counts[h.name, default: 0] += 1 }
        if let top = counts.max(by: { $0.value < $1.value }), top.value >= 3 {
            return "\(timeGreeting) \(top.key)已经坚持\(top.value)天了！"
        }

        switch hour {
        case 5..<12: return "\(timeGreeting) 新的一天，有什么想聊的吗？"
        case 12..<17: return "\(timeGreeting) 最近在想些什么？"
        case 17..<22: return "\(timeGreeting) 今天过得怎么样？"
        default: return "睡不着？我在这里陪你。"
        }
    }
}
