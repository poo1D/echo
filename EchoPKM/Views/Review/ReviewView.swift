import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var allEntries: [DiaryEntry]
    @Query(sort: \HabitEntry.date, order: .reverse) private var allHabits: [HabitEntry]

    @State private var weekOffset = 0
    @State private var petObservation: String?
    @State private var isLoadingObservation = false
    @State private var petState = PetState()
    @State private var insightService = InsightService()
    @State private var healthService = HealthKitService()
    @State private var healthSnapshot: HealthSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Week picker
                    weekPickerRow

                    // Module 1: Mood Trend
                    moodTrendCard

                    // Module 2: Habit Heatmap
                    habitHeatmapCard

                    // Module 3: Health Trends
                    healthTrendCard

                    // Module 4: Weekly Letter
                    weeklyLetterCard
                }
                .padding()
                .modifier(GlassEffectContainerModifier())
            }
            .background { WarmGradientBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("回顾")
                        .font(.yuanti(20, weight: .bold))
                }
            }
            .task(id: weekOffset) {
                await loadPetObservation()
                await loadHealthData()
            }
        }
    }

    // MARK: - Week Picker

    private var weekPickerRow: some View {
        HStack {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.claudeAccent)
            }

            Spacer()

            Text(weekLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                if weekOffset < 0 { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
                    .foregroundStyle(weekOffset < 0 ? Color.claudeAccent : Color.claudeWarmGray.opacity(0.3))
            }
            .disabled(weekOffset >= 0)
        }
        .padding(.horizontal, 4)
    }

    private var weekLabel: String {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart)!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        if weekOffset == 0 {
            return "本周 (\(fmt.string(from: weekStart)) - \(fmt.string(from: weekEnd)))"
        }
        return "\(fmt.string(from: weekStart)) - \(fmt.string(from: weekEnd))"
    }

    private var currentWeekStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }

    // MARK: - Week Data

    private var selectedWeekStart: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart)!
    }

    private var selectedWeekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart)!
    }

    private var weekEntries: [DiaryEntry] {
        allEntries.filter { $0.createdAt >= selectedWeekStart && $0.createdAt < selectedWeekEnd }
    }

    // MARK: - Module 1: Mood Trend

    private struct MoodDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let dayLabel: String
        let score: Double
        let emoji: String
    }

    private var moodDataPoints: [MoodDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: weekEntries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }

        // Generate all 7 days of the week
        return (0..<7).compactMap { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: selectedWeekStart)!
            let dayStart = calendar.startOfDay(for: date)
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "zh_CN")
            fmt.dateFormat = "EEE"
            let label = fmt.string(from: date)

            if let dayEntries = grouped[dayStart] {
                let scores = dayEntries.compactMap(\.moodScore)
                guard !scores.isEmpty else { return nil }
                let avg = Double(scores.reduce(0, +)) / Double(scores.count)
                let emoji = MoodUtils.emoji(forScore: Int(avg.rounded()))
                return MoodDataPoint(date: date, dayLabel: label, score: avg, emoji: emoji)
            }
            return nil
        }
    }

    private var moodTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("心情趋势", systemImage: "heart.fill")
                    .font(.yuantiHeadline)
                    .foregroundStyle(.primary)

                Spacer()

                if !moodDataPoints.isEmpty {
                    let trend = MoodUtils.trendLabel(from: moodDataPoints.map { Int($0.score.rounded()) })
                    Text("\(trend.text) \(trend.arrow)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.claudeAccent)
                }
            }

            if weekEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
                    Text("这周还没有记录哦")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            } else {
                // Chart
                Chart(moodDataPoints) { point in
                    LineMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Mood", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.claudeAccent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Mood", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.claudeAccent.opacity(0.3), Color.claudeAccent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Mood", point.score)
                    )
                    .foregroundStyle(Color.claudeAccent)
                    .annotation(position: .top, spacing: 4) {
                        Text(point.emoji)
                            .font(.system(size: 14))
                    }
                }
                .chartYScale(domain: 0.5...5.5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(MoodUtils.emoji(forScore: v))
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
                .frame(height: 180)

                // Footer
                HStack {
                    let scores = moodDataPoints.map { $0.score }
                    let avg = scores.reduce(0, +) / Double(scores.count)
                    Text("平均: \(String(format: "%.1f", avg))")
                        .font(.caption)
                        .foregroundStyle(Color.claudeWarmGray)

                    Text("|")
                        .foregroundStyle(Color.claudeDivider)

                    Text("\(weekEntries.count)篇记录")
                        .font(.caption)
                        .foregroundStyle(Color.claudeWarmGray)
                }
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    // MARK: - Module 2: Habit Tracker

    private enum DayStatus {
        case completed, missed, future
    }

    private struct HabitWeekRow: Identifiable {
        let id = UUID()
        let habitName: String
        let emoji: String
        let dailyStatus: [DayStatus] // 7 entries: Mon-Sun
        let weekCount: Int
    }

    private var habitWeekRows: [HabitWeekRow] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Collect all unique habit names ever recorded
        let allNames = Set(allHabits.map { $0.name.lowercased() })
        guard !allNames.isEmpty else { return [] }

        // Build a set of (habitName, dayStart) for the selected week
        let weekHabits = allHabits.filter { $0.date >= selectedWeekStart && $0.date < selectedWeekEnd }
        var completedSet: Set<String> = [] // "name|dayIndex"
        for habit in weekHabits {
            let dayStart = calendar.startOfDay(for: habit.date)
            let dayIndex = calendar.dateComponents([.day], from: selectedWeekStart, to: dayStart).day ?? 0
            if dayIndex >= 0 && dayIndex < 7 {
                completedSet.insert("\(habit.name.lowercased())|\(dayIndex)")
            }
        }

        // Build rows
        var rows: [HabitWeekRow] = []
        for name in allNames {
            let emoji = HabitStreakData.emojiFor(name)
            var statuses: [DayStatus] = []
            var count = 0
            for dayIndex in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayIndex, to: selectedWeekStart)!
                let dayStart = calendar.startOfDay(for: date)
                if dayStart > today {
                    statuses.append(.future)
                } else if completedSet.contains("\(name)|\(dayIndex)") {
                    statuses.append(.completed)
                    count += 1
                } else {
                    statuses.append(.missed)
                }
            }
            rows.append(HabitWeekRow(habitName: name, emoji: emoji, dailyStatus: statuses, weekCount: count))
        }

        // Sort: by week count descending, then alphabetically
        rows.sort { lhs, rhs in
            if lhs.weekCount != rhs.weekCount { return lhs.weekCount > rhs.weekCount }
            return lhs.habitName < rhs.habitName
        }

        return rows
    }

    private var habitHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("习惯追踪", systemImage: "square.grid.3x3.fill")
                    .font(.yuantiHeadline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            if allHabits.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3")
                        .font(.largeTitle)
                        .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
                    Text("还没有记录习惯哦")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("和Echo聊天时提到你的日常习惯，就会自动记录在这里")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                let rows = habitWeekRows
                let dayLabels = ["一", "二", "三", "四", "五", "六", "日"]

                // Day-of-week header row
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 72)

                    ForEach(dayLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Color.claudeWarmGray)
                            .frame(maxWidth: .infinity)
                    }

                    Text("")
                        .frame(width: 52)
                }

                // Per-habit rows
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        // Emoji + name
                        HStack(spacing: 4) {
                            Text(row.emoji)
                                .font(.system(size: 14))
                            Text(row.habitName)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(width: 72, alignment: .leading)

                        // 7-day status circles
                        ForEach(0..<7, id: \.self) { dayIndex in
                            Group {
                                switch row.dailyStatus[dayIndex] {
                                case .completed:
                                    Circle()
                                        .fill(Color.claudeAccent)
                                        .frame(width: 10, height: 10)
                                case .missed:
                                    Circle()
                                        .strokeBorder(Color.claudeDivider, lineWidth: 1.5)
                                        .frame(width: 10, height: 10)
                                case .future:
                                    Text("·")
                                        .font(.caption)
                                        .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Week count
                        if row.weekCount > 0 {
                            Text("本周\(row.weekCount)次")
                                .font(.caption2)
                                .foregroundStyle(Color.claudeWarmGray)
                                .frame(width: 52, alignment: .trailing)
                        } else {
                            Text("")
                                .frame(width: 52)
                        }
                    }
                }

                // Legend
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.claudeAccent)
                            .frame(width: 8, height: 8)
                        Text("已完成")
                            .font(.caption2)
                            .foregroundStyle(Color.claudeWarmGray)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .strokeBorder(Color.claudeDivider, lineWidth: 1)
                            .frame(width: 8, height: 8)
                        Text("未记录")
                            .font(.caption2)
                            .foregroundStyle(Color.claudeWarmGray)
                    }
                    HStack(spacing: 4) {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
                        Text("未到")
                            .font(.caption2)
                            .foregroundStyle(Color.claudeWarmGray)
                    }

                    Spacer()

                    let totalWeek = rows.reduce(0) { $0 + $1.weekCount }
                    if totalWeek > 0 {
                        Text("本周共完成 \(totalWeek) 个习惯打卡")
                            .font(.caption2)
                            .foregroundStyle(Color.claudeWarmGray)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .glassCard(tint: .glassHabitTint)
    }

    // MARK: - Module 3: Health Trends Card

    private var healthTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("健康趋势", systemImage: "heart.text.square.fill")
                    .font(.yuantiHeadline)
                    .foregroundStyle(.primary)

                Spacer()

                if let hs = healthSnapshot {
                    Text("今日\(hs.steps)步")
                        .font(.caption)
                        .foregroundStyle(Color.claudeWarmGray)
                }
            }

            if let hs = healthSnapshot {
                // Sleep bar chart (7 days)
                if !hs.weeklySleep.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("睡眠 (小时)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Chart(Array(hs.weeklySleep.enumerated()), id: \.offset) { index, item in
                            BarMark(
                                x: .value("Day", dayLabel(for: item.date)),
                                y: .value("Hours", item.hours)
                            )
                            .foregroundStyle(
                                item.hours >= 7 ? Color(hex: "7B68EE").opacity(0.8) :
                                item.hours >= 5 ? Color(hex: "7B68EE").opacity(0.5) :
                                Color(hex: "FF6B35").opacity(0.7)
                            )
                            .cornerRadius(4)
                        }
                        .chartYScale(domain: 0...10)
                        .frame(height: 120)
                    }
                }

                // Steps line chart (7 days)
                if !hs.weeklySteps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("步数")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Chart(Array(hs.weeklySteps.enumerated()), id: \.offset) { index, item in
                            LineMark(
                                x: .value("Day", dayLabel(for: item.date)),
                                y: .value("Steps", item.steps)
                            )
                            .foregroundStyle(Color(hex: "4CAF50"))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Day", dayLabel(for: item.date)),
                                y: .value("Steps", item.steps)
                            )
                            .foregroundStyle(Color(hex: "4CAF50"))
                        }
                        .frame(height: 100)
                    }
                }

                // Correlation annotation
                let correlations = computeCorrelations()
                if !correlations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(correlations.enumerated()), id: \.offset) { _, corr in
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption2)
                                    .foregroundStyle(Color.claudeAccent)
                                Text(corr.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Health insights
                if !hs.insights.isEmpty {
                    ForEach(Array(hs.insights.prefix(2).enumerated()), id: \.offset) { _, insight in
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.caption2)
                                .foregroundStyle(Color.claudeAccent)
                            Text(insight.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.largeTitle)
                        .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
                    Text("健康数据加载中...")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            }
        }
        .padding(16)
        .glassCard(tint: .glassHealthTint)
    }

    private func dayLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    private func computeCorrelations() -> [CorrelationEngine.Correlation] {
        guard let hs = healthSnapshot else { return [] }
        let entryMoodData = weekEntries.compactMap { entry -> CorrelationEngine.EntryMoodData? in
            guard let score = entry.moodScore else { return nil }
            return CorrelationEngine.EntryMoodData(date: entry.createdAt, moodScore: score)
        }
        return CorrelationEngine.analyze(entries: entryMoodData, healthData: hs)
    }

    // MARK: - Module 4: Weekly Letter Card

    private var weeklyLetterCard: some View {
        VStack(spacing: 0) {
            // Envelope flap (triangle)
            EnvelopeFlap()
                .fill(
                    LinearGradient(
                        colors: [Color.claudeAccent.opacity(0.15), Color.claudeAccent.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 50)

            // Card body
            VStack(spacing: 12) {
                // Mini penguin
                PetView(petState: petState)
                    .scaleEffect(0.3)
                    .frame(width: 50, height: 60)
                    .allowsHitTesting(false)

                if weekEntries.isEmpty {
                    Text("这周还没有记录，Echo还没法给你写信哦")
                        .font(.subheadline)
                        .foregroundStyle(Color.claudeWarmGray)
                        .multilineTextAlignment(.center)
                } else if isLoadingObservation {
                    ProgressView()
                        .tint(Color.claudeAccent)
                    Text("Echo正在写信中...")
                        .font(.subheadline)
                        .foregroundStyle(Color.claudeWarmGray)
                } else if let observation = petObservation {
                    Text("叮~ Echo给你写了一封信！")
                        .font(.yuantiSubheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(observation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    NavigationLink {
                        WeeklyLettersView()
                    } label: {
                        Text("查看所有来信")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.claudeAccent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.claudeAccent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .glassCard(tint: .glassLetterTint)
    }

    // MARK: - LLM Observation (with cache)

    private func loadPetObservation() async {
        guard !weekEntries.isEmpty else {
            petObservation = nil
            return
        }
        isLoadingObservation = true
        defer { isLoadingObservation = false }

        petObservation = await insightService.weeklyObservation(
            entries: weekEntries,
            modelContext: modelContext
        )
    }

    private func loadHealthData() async {
        await healthService.requestAuthorization()
        healthSnapshot = await healthService.buildSnapshot()
    }
}

// MARK: - Envelope Flap Shape

private struct EnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
