import Foundation
import SwiftData

@Observable @MainActor
final class InsightService {
    var isGenerating = false

    private let apiEndpoint = "https://api-inference.modelscope.cn/v1/chat/completions"
    private let modelId = "moonshotai/Kimi-K2.5"
    private var apiKey: String {
        let key = APIConfig.modelScopeAPIKey
        if !key.isEmpty { return key }
        if let key = ProcessInfo.processInfo.environment["MODELSCOPE_API_KEY"], !key.isEmpty {
            return key
        }
        return ""
    }

    // MARK: - Generate Insight for a Single Entry

    func generateInsight(for entry: DiaryEntry, modelContext: ModelContext) async {
        guard entry.aiInsight == nil else { return }
        guard !apiKey.isEmpty else { return }

        let prompt = """
        Based on this diary entry, write ONE short encouraging insight or observation (15 words max). \
        Be warm, specific, and personal. No quotes.

        Entry: \(entry.summary)
        Mood: \(entry.moodEmoji ?? "") (score: \(entry.moodScore ?? 3)/5)
        Topics: \(entry.topics.joined(separator: ", "))
        """

        if let response = await callLLM(userPrompt: prompt) {
            entry.aiInsight = response
            try? modelContext.save()
        }
    }

    // MARK: - Weekly Observation with Cache

    func weeklyObservation(entries: [DiaryEntry], habits: [HabitEntry] = [], schedules: [ScheduleItem] = [], modelContext: ModelContext) async -> String? {
        guard !entries.isEmpty else { return nil }

        let calendar = Calendar.current
        let referenceDate = entries.first?.createdAt ?? Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate))!

        // Check cache
        var descriptor = FetchDescriptor<WeeklyReview>(
            predicate: #Predicate { $0.weekStartDate == weekStart }
        )
        descriptor.fetchLimit = 1

        if let cached = try? modelContext.fetch(descriptor).first,
           cached.entryCount == entries.count {
            return cached.observation
        }

        // Generate new observation

        // --- Cross-week context ---
        let threeWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -3, to: weekStart)!
        let pastEntries = fetchEntries(from: threeWeeksAgo, to: weekStart, modelContext: modelContext)

        let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
        let previousLetter = fetchWeeklyReview(for: prevWeekStart, modelContext: modelContext)

        let recurringTopics = analyzeRecurringTopics(currentWeek: entries, pastEntries: pastEntries)
        let moodTrajectory = analyzeMoodTrajectory(currentWeekEntries: entries, pastEntries: pastEntries, weekStart: weekStart)
        let pastContext = buildPastWeeksContext(pastEntries: pastEntries, weekStart: weekStart)

        // --- Current week summaries ---
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        weekdayFormatter.dateFormat = "EEEE"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"

        let entrySummaries = entries.map { entry in
            let weekday = weekdayFormatter.string(from: entry.createdAt)
            let date = dateFormatter.string(from: entry.createdAt)
            let mood = entry.moodEmoji ?? "😐"
            let score = entry.moodScore ?? 3
            let topicStr = entry.topics.isEmpty ? "" : "\n话题: \(entry.topics.joined(separator: "、"))"
            return "[\(weekday) \(date)] \(mood)(\(score)/5) — \(entry.summary)\(topicStr)"
        }.joined(separator: "\n\n")

        // --- Build cross-week insight sections ---
        var crossWeekSection = ""

        if !pastContext.isEmpty {
            crossWeekSection += "\n\n\(pastContext)"
        }

        if !recurringTopics.isEmpty {
            let topicLines = recurringTopics.map { "\"\($0.topic)\" 出现\($0.count)次" }.joined(separator: "、")
            crossWeekSection += "\n\n跨周重复话题（最近4周）:\n\(topicLines)"
        }

        if !moodTrajectory.isEmpty {
            crossWeekSection += "\n\n\(moodTrajectory)"
        }

        if let prevLetter = previousLetter {
            let trimmed = String(prevLetter.observation.prefix(200))
            crossWeekSection += "\n\n上封信的主要内容（请勿重复类似的表述）:\n\(trimmed)"
        }

        // --- Prompts ---
        let systemPrompt = """
        你是Echo，一只住在用户日记本里的小企鹅。你性格活泼、观察力强、偶尔有点调皮，\
        但内心很温暖。你会认真读用户每一篇日记，像一个贴心的老朋友一样写信给他们。\
        写信风格：口语化、有温度、偶尔带点幽默和俏皮，但不过分。\
        你的信要让人觉得"这只企鹅真的在认真看我的日记"。\
        只输出信件正文，不加"亲爱的"开头和落款。
        """

        let hasCrossWeekData = !pastContext.isEmpty
        let crossWeekRequirements = hasCrossWeekData ? """

        6. 如果往期背景中有和本周相关的话题或事件，自然地提起来（比如"你上周也提到过..."或"这个月你已经第三次说到..."），不要生硬罗列
        7. 如果情绪趋势有明显变化（好转或下滑），温和地点出来，像朋友一样关心而非分析
        8. 不要重复上封信已经说过的话
        """ : ""

        // --- Habit & Schedule context ---
        let habitContext = buildHabitContext(habits: habits)
        let scheduleContext = buildScheduleContext(schedules: schedules)
        let habitMoodCorrelation = buildHabitMoodCorrelation(habits: habits, entries: entries)
        var behaviorSection = ""
        if !habitContext.isEmpty        { behaviorSection += "\n\n\(habitContext)" }
        if !scheduleContext.isEmpty     { behaviorSection += "\n\n\(scheduleContext)" }
        if !habitMoodCorrelation.isEmpty { behaviorSection += "\n\n习惯×心情关联:\n\(habitMoodCorrelation)" }
        let behaviorRequirement = behaviorSection.isEmpty ? "" : """

        \(hasCrossWeekData ? 9 : 6). 如果习惯或日程数据与心情有规律性关联，可以轻描淡写带出，不要像数据报告
        """

        let userPrompt = """
        根据本周的日记，写一封信给用户（3-4段，每段2-3句）。

        要求：
        1. 提及至少2-3条具体的日记内容（引用具体事件或话题，不要笼统概括）
        2. 如果发现情绪变化的规律，点出来（比如"周三心情低落，但周五又开心起来了"）
        3. 如果有重复出现的话题或习惯，提一下
        4. 语气像朋友聊天，不要像AI回复
        5. 最后给一句轻松的鼓励，不要太鸡汤\(crossWeekRequirements)\(behaviorRequirement)

        本周日记（共\(entries.count)篇）:
        \(entrySummaries)\(behaviorSection)\(crossWeekSection)
        """

        guard let observation = await callLLM(systemPrompt: systemPrompt, userPrompt: userPrompt) else {
            // Build a basic observation from local data when API fails
            let moodEmojis = entries.compactMap(\.moodEmoji).joined()
            let topTopics = Array(Set(entries.flatMap(\.topics)).prefix(3)).joined(separator: "、")
            let base = "这周你写了\(entries.count)篇日记"
            let topicPart = topTopics.isEmpty ? "" : "，聊到了\(topTopics)"
            let moodPart = moodEmojis.isEmpty ? "" : "，心情是\(moodEmojis)"
            return "\(base)\(topicPart)\(moodPart)。Echo会继续陪着你的！"
        }

        // Cache the result
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.observation = observation
            existing.entryCount = entries.count
            existing.generatedAt = Date()
        } else {
            let review = WeeklyReview(
                weekStartDate: weekStart,
                observation: observation,
                entryCount: entries.count
            )
            modelContext.insert(review)
        }
        try? modelContext.save()

        return observation
    }

    // MARK: - Cross-Week Data Helpers

    private func fetchEntries(from startDate: Date, to endDate: Date, modelContext: ModelContext) -> [DiaryEntry] {
        let start = startDate
        let end = endDate
        var descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.createdAt >= start && entry.createdAt < end
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchWeeklyReview(for weekStart: Date, modelContext: ModelContext) -> WeeklyReview? {
        let targetDate = weekStart
        var descriptor = FetchDescriptor<WeeklyReview>(
            predicate: #Predicate<WeeklyReview> { $0.weekStartDate == targetDate }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func analyzeRecurringTopics(currentWeek: [DiaryEntry], pastEntries: [DiaryEntry]) -> [(topic: String, count: Int)] {
        var topicCounts: [String: Int] = [:]
        for entry in pastEntries + currentWeek {
            for topic in entry.topics {
                topicCounts[topic.lowercased(), default: 0] += 1
            }
        }
        return topicCounts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (topic: $0.key, count: $0.value) }
    }

    private func analyzeMoodTrajectory(currentWeekEntries: [DiaryEntry], pastEntries: [DiaryEntry], weekStart: Date) -> String {
        let calendar = Calendar.current
        var weeklyMoods: [(weekLabel: String, avgMood: Double)] = []

        for offset in -3...0 {
            let wStart = calendar.date(byAdding: .weekOfYear, value: offset, to: weekStart)!
            let wEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: wStart)!

            let weekEntries = offset == 0
                ? currentWeekEntries
                : pastEntries.filter { $0.createdAt >= wStart && $0.createdAt < wEnd }

            let scores = weekEntries.compactMap(\.moodScore)
            guard !scores.isEmpty else { continue }

            let avg = Double(scores.reduce(0, +)) / Double(scores.count)
            let label = offset == 0 ? "本周" : "\(-offset)周前"
            weeklyMoods.append((weekLabel: label, avgMood: avg))
        }

        guard weeklyMoods.count >= 2 else { return "" }

        let first = weeklyMoods.first!.avgMood
        let last = weeklyMoods.last!.avgMood
        let diff = last - first
        let detail = weeklyMoods.map { "\($0.weekLabel)\(String(format: "%.1f", $0.avgMood))" }.joined(separator: " → ")

        if diff > 0.5 {
            return "情绪走势: 心情在好转 (\(detail))"
        } else if diff < -0.5 {
            return "情绪走势: 心情有所下滑 (\(detail))"
        } else {
            return "情绪走势: 心情比较稳定 (\(detail))"
        }
    }

    private func buildPastWeeksContext(pastEntries: [DiaryEntry], weekStart: Date) -> String {
        let calendar = Calendar.current
        var sections: [String] = []

        for offset in [-3, -2, -1] {
            let wStart = calendar.date(byAdding: .weekOfYear, value: offset, to: weekStart)!
            let wEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: wStart)!

            let weekEntries = pastEntries.filter {
                $0.createdAt >= wStart && $0.createdAt < wEnd
            }
            guard !weekEntries.isEmpty else { continue }

            let scores = weekEntries.compactMap(\.moodScore)
            let avgMood = scores.isEmpty ? "无" : String(format: "%.1f", Double(scores.reduce(0, +)) / Double(scores.count))
            let topics = Array(Set(weekEntries.flatMap(\.topics))).prefix(5).joined(separator: "、")
            let summaries = weekEntries.prefix(3).map { "  - \($0.summary)" }.joined(separator: "\n")

            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "M/d"
            let label = dateFmt.string(from: wStart)

            sections.append("""
            [\(-offset)周前 \(label)起] \(weekEntries.count)篇日记, 心情均分\(avgMood)
            主要话题: \(topics.isEmpty ? "无" : topics)
            摘要:
            \(summaries)
            """)
        }

        return sections.isEmpty ? "" : "往期背景（最近3周）:\n" + sections.joined(separator: "\n\n")
    }

    // MARK: - Behavior Context Helpers

    private func buildHabitContext(habits: [HabitEntry]) -> String {
        guard !habits.isEmpty else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "EEE"
        let grouped = Dictionary(grouping: habits) { $0.name }
        let lines = grouped.sorted { $0.key < $1.key }.map { name, entries -> String in
            let done = entries.filter { $0.completed }
            let days = done.map { fmt.string(from: $0.date) }.joined(separator: " ")
            let dayStr = days.isEmpty ? "" : "（\(days)）"
            return "  - \(name): 完成\(done.count)/\(entries.count)次\(dayStr)"
        }
        return "本周习惯记录:\n" + lines.joined(separator: "\n")
    }

    private func buildScheduleContext(schedules: [ScheduleItem]) -> String {
        guard !schedules.isEmpty else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M/d EEE"
        let done = schedules.filter { $0.isCompleted }.count
        let lines = schedules.sorted { $0.date < $1.date }.map { item -> String in
            "\(item.isCompleted ? "✓" : "✗") \(fmt.string(from: item.date)) \(item.title)"
        }
        return "本周日程（\(done)/\(schedules.count)已完成）:\n" + lines.map { "  - \($0)" }.joined(separator: "\n")
    }

    private func buildHabitMoodCorrelation(habits: [HabitEntry], entries: [DiaryEntry]) -> String {
        guard !habits.isEmpty, !entries.isEmpty else { return "" }
        let cal = Calendar.current

        // mood score keyed by day
        var moodByDay: [Date: Double] = [:]
        for entry in entries {
            guard let score = entry.moodScore else { continue }
            let day = cal.startOfDay(for: entry.createdAt)
            moodByDay[day] = moodByDay[day].map { ($0 + Double(score)) / 2 } ?? Double(score)
        }

        var correlations: [String] = []
        for habitName in Set(habits.map { $0.name }).sorted() {
            let doneDays = Set(habits.filter { $0.name == habitName && $0.completed }
                .map { cal.startOfDay(for: $0.date) })
            let doneMoods   = doneDays.compactMap { moodByDay[$0] }
            let notMoods    = Set(moodByDay.keys).subtracting(doneDays).compactMap { moodByDay[$0] }
            guard doneMoods.count >= 2, !notMoods.isEmpty else { continue }
            let avgDone = doneMoods.reduce(0, +) / Double(doneMoods.count)
            let avgNot  = notMoods.reduce(0,  +) / Double(notMoods.count)
            guard abs(avgDone - avgNot) >= 0.5 else { continue }
            let dir = avgDone > avgNot ? "更高" : "更低"
            correlations.append("完成\(habitName)那天心情均分\(String(format: "%.1f", avgDone))，未完成为\(String(format: "%.1f", avgNot))（完成时\(dir)）")
        }
        return correlations.joined(separator: "\n")
    }

    // MARK: - LLM Call Helper

    private func callLLM(systemPrompt: String = "你是一个温暖简洁的助手。只输出要求的内容，不要额外格式。", userPrompt: String) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
            }

            do {
                var request = URLRequest(url: URL(string: apiEndpoint)!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "model": modelId,
                    "messages": [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": userPrompt]
                    ],
                    "stream": false
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)

                // Retry on 429 rate limit
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                    print("InsightService got 429, retry \(attempt + 1)/3")
                    continue
                }

                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = obj["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                print("InsightService LLM call failed (attempt \(attempt + 1)/3): \(error)")
            }
        }
        return nil
    }
}
