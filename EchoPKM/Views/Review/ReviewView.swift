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
    @State private var showLetterSheet = false

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

                    // Module 3: Weekly Letter
                    weeklyLetterCard
                }
                .padding()
            }
            .background(Color.claudeBackground)
            .navigationTitle("回顾")
            .task(id: weekOffset) {
                await loadPetObservation()
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
                    .font(.headline)
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
        .background(Color.claudeCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Module 2: Habit Heatmap

    private struct HeatmapDay: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
        let isFuture: Bool
    }

    private var heatmapData: [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the Monday of 4 weeks ago
        let currentWeekday = calendar.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ... 7=Sat. Convert to Mon=1 based.
        let daysFromMonday = (currentWeekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6
        let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let startMonday = calendar.date(byAdding: .weekOfYear, value: -4, to: thisMonday)!

        // Count habits per day
        var habitsByDay: [Date: Int] = [:]
        for habit in allHabits {
            let day = calendar.startOfDay(for: habit.date)
            if day >= startMonday {
                habitsByDay[day, default: 0] += 1
            }
        }

        // Generate 35 days (5 weeks x 7 days)
        return (0..<35).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startMonday)!
            let dayStart = calendar.startOfDay(for: date)
            let count = habitsByDay[dayStart] ?? 0
            let isFuture = dayStart > today
            return HeatmapDay(date: date, count: count, isFuture: isFuture)
        }
    }

    private func heatmapColor(for count: Int, isFuture: Bool) -> Color {
        if isFuture { return Color.claudeSurfaceTint.opacity(0.3) }
        switch count {
        case 0: return Color.claudeSurfaceTint
        case 1: return Color.claudeAccent.opacity(0.3)
        case 2: return Color.claudeAccent.opacity(0.6)
        default: return Color.claudeAccent.opacity(0.9)
        }
    }

    private var habitHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("习惯热力图", systemImage: "square.grid.3x3.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("近5周")
                    .font(.caption)
                    .foregroundStyle(Color.claudeWarmGray)
            }

            // Day-of-week header
            let dayLabels = ["一", "二", "三", "四", "五", "六", "日"]
            HStack(spacing: 0) {
                // Week label spacer
                Text("")
                    .frame(width: 36)

                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(Color.claudeWarmGray)
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid: 5 rows x 7 columns
            let weeks = stride(from: 0, to: 35, by: 7).map { start in
                Array(heatmapData[start..<min(start + 7, heatmapData.count)])
            }

            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                HStack(spacing: 0) {
                    // Week start label
                    let weekDate = week.first?.date ?? Date()
                    let fmt = DateFormatter()
                    let _ = fmt.dateFormat = "M/d"
                    Text(fmt.string(from: weekDate))
                        .font(.caption2)
                        .foregroundStyle(Color.claudeWarmGray)
                        .frame(width: 36, alignment: .leading)

                    ForEach(week) { day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatmapColor(for: day.count, isFuture: day.isFuture))
                            .aspectRatio(1, contentMode: .fit)
                            .padding(2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("少")
                    .font(.caption2)
                    .foregroundStyle(Color.claudeWarmGray)

                ForEach([0, 1, 2, 3], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(for: level, isFuture: false))
                        .frame(width: 12, height: 12)
                }

                Text("多")
                    .font(.caption2)
                    .foregroundStyle(Color.claudeWarmGray)

                Spacer()

                let totalCompleted = heatmapData.filter { !$0.isFuture }.reduce(0) { $0 + $1.count }
                Text("共\(totalCompleted)个完成")
                    .font(.caption2)
                    .foregroundStyle(Color.claudeWarmGray)
            }
        }
        .padding(16)
        .background(Color.claudeCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Module 3: Weekly Letter Card

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
                } else if petObservation != nil {
                    Text("叮~ Echo给你写了一封信！")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Button {
                        showLetterSheet = true
                    } label: {
                        Text("点击阅读")
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
        .background(Color.claudeCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        .sheet(isPresented: $showLetterSheet) {
            if let observation = petObservation {
                WeeklyLetterSheet(
                    observation: observation,
                    entryCount: weekEntries.count,
                    weekLabel: weekLabel
                )
                .presentationDragIndicator(.visible)
            }
        }
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
