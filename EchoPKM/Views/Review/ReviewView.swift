import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var allEntries: [DiaryEntry]
    @Query(sort: \HabitEntry.date, order: .reverse) private var allHabits: [HabitEntry]
    @Query(sort: \ScheduleItem.date) private var allSchedules: [ScheduleItem]

    @State private var weekOffset = 0
    @State private var petObservation: String?
    @State private var isLoadingObservation = false
    @State private var petState = PetState()
    @State private var insightService = InsightService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Week picker
                    weekPickerRow

                    // Module 1: Mood Trend
                    moodTrendCard

                    // Module 2: Topic Cloud
                    if !topicFrequencies.isEmpty {
                        topicCloudCard
                    }

                    // Module 3: Weekly Letter
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
                .font(.yuanti(15, weight: .medium))
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

    private var weekHabits: [HabitEntry] {
        allHabits.filter { $0.date >= selectedWeekStart && $0.date < selectedWeekEnd }
    }

    private var weekSchedules: [ScheduleItem] {
        allSchedules.filter { $0.date >= selectedWeekStart && $0.date < selectedWeekEnd }
    }

    private var topicFrequencies: [(topic: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in weekEntries {
            for topic in entry.topics {
                let t = topic.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { continue }
                counts[t, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { (topic: $0.key, count: $0.value) }
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
                        .font(.yuanti(15, weight: .medium))
                        .foregroundStyle(Color.claudeAccent)
                }
            }

            if weekEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
                    Text("这周还没有记录哦")
                        .font(.yuantiSubheadline)
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
                        .font(.yuantiCaption)
                        .foregroundStyle(Color.claudeWarmGray)

                    Text("|")
                        .foregroundStyle(Color.claudeDivider)

                    Text("\(weekEntries.count)篇记录")
                        .font(.yuantiCaption)
                        .foregroundStyle(Color.claudeWarmGray)
                }
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    // MARK: - Module 2: Topic Cloud

    private var topicCloudCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("话题", systemImage: "tag.fill")
                    .font(.yuantiHeadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("共 \(topicFrequencies.count) 个")
                    .font(.yuantiCaption)
                    .foregroundStyle(Color.claudeWarmGray)
            }

            let maxCount = topicFrequencies.first?.count ?? 1
            FlowLayout(spacing: 8) {
                ForEach(topicFrequencies, id: \.topic) { item in
                    topicTag(item.topic, count: item.count, maxCount: maxCount)
                }
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    private func topicTag(_ topic: String, count: Int, maxCount: Int) -> some View {
        let tier = count == maxCount && maxCount >= 2 ? 3 : (count >= 2 ? 2 : 1)
        let sizes: [CGFloat]   = [12, 14, 16]
        let textOps: [Double]  = [0.60, 0.80, 1.00]
        let bgOps: [Double]    = [0.07, 0.12, 0.18]
        let hPads: [CGFloat]   = [9, 10, 12]
        let vPads: [CGFloat]   = [4,  5,  6 ]

        return Text(topic)
            .font(.yuanti(sizes[tier - 1], weight: tier == 3 ? .medium : .regular))
            .foregroundStyle(Color.claudeAccent.opacity(textOps[tier - 1]))
            .padding(.horizontal, hPads[tier - 1])
            .padding(.vertical,   vPads[tier - 1])
            .background(Color.claudeAccent.opacity(bgOps[tier - 1]))
            .clipShape(Capsule())
    }

    // MARK: - Module 3: Weekly Letter Card

    private var weeklyLetterCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.claudeAccent)
                    Text("每周来信")
                        .font(.yuantiHeadline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(weekLabel)
                    .font(.yuantiCaption)
                    .foregroundStyle(Color.claudeWarmGray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.claudeAccent.opacity(0.08))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Dashed divider
            letterDashedDivider

            // Body
            VStack(alignment: .leading, spacing: 12) {
                if weekEntries.isEmpty {
                    HStack(spacing: 12) {
                        miniPet
                        Text("这周还没有记录，多聊聊 Echo 才能给你写信哦")
                            .font(.yuantiSubheadline)
                            .foregroundStyle(Color.claudeWarmGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if isLoadingObservation {
                    HStack(spacing: 12) {
                        miniPet
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView()
                                .tint(Color.claudeAccent)
                                .scaleEffect(0.9)
                            Text("Echo 正在写信…")
                                .font(.yuantiCaption)
                                .foregroundStyle(Color.claudeWarmGray)
                        }
                    }
                } else if let observation = petObservation {
                    HStack(alignment: .top, spacing: 12) {
                        miniPet
                        VStack(alignment: .leading, spacing: 6) {
                            Text("亲爱的主人：")
                                .font(.yuanti(13, weight: .bold))
                                .foregroundStyle(Color.claudeAccent)
                            Text(observation)
                                .font(.yuantiCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack {
                        Spacer()
                        NavigationLink {
                            WeeklyLettersView()
                        } label: {
                            HStack(spacing: 4) {
                                Text("查看完整来信")
                                    .font(.yuanti(14, weight: .medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Color.claudeAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.claudeAccent.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassCard(tint: .glassLetterTint)
    }

    private var letterDashedDivider: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(Color.claudeDivider)
            .frame(height: 1)
            .padding(.horizontal, 18)
    }

    private var miniPet: some View {
        PetView(petState: petState)
            .scaleEffect(0.35)
            .frame(width: 44, height: 52)
            .allowsHitTesting(false)
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
            habits: weekHabits,
            schedules: weekSchedules,
            modelContext: modelContext
        )
    }

}


#Preview {
    ReviewView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
