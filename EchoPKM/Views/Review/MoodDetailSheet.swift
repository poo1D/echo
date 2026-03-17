import SwiftUI
import Charts

struct MoodDetailSheet: View {
    let weekEntries: [DiaryEntry]
    let weekLabel: String
    let weekStart: Date

    @Environment(\.dismiss) private var dismiss

    // MARK: - Data

    private struct MoodDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let dayLabel: String
        let score: Double
        let emoji: String
        let entries: [DiaryEntry]
    }

    private var dataPoints: [MoodDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: weekEntries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "EEE"
        return (0..<7).compactMap { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEntries = grouped[dayStart], !dayEntries.isEmpty else { return nil }
            let scores = dayEntries.compactMap(\.moodScore)
            guard !scores.isEmpty else { return nil }
            let avg = Double(scores.reduce(0, +)) / Double(scores.count)
            return MoodDataPoint(
                date: date,
                dayLabel: fmt.string(from: date),
                score: avg,
                emoji: MoodUtils.emoji(forScore: Int(avg.rounded())),
                entries: dayEntries.sorted { $0.createdAt < $1.createdAt }
            )
        }
    }

    private var avgScore: Double {
        guard !dataPoints.isEmpty else { return 0 }
        return dataPoints.map(\.score).reduce(0, +) / Double(dataPoints.count)
    }

    private var bestDay: MoodDataPoint? { dataPoints.max(by: { $0.score < $1.score }) }
    private var worstDay: MoodDataPoint? { dataPoints.min(by: { $0.score < $1.score }) }

    /// Distribution: score bucket → day count
    private var distribution: [(score: Int, label: String, emoji: String, count: Int)] {
        var counts: [Int: Int] = [:]
        for pt in dataPoints { counts[Int(pt.score.rounded()), default: 0] += 1 }
        return [5, 4, 3, 2, 1].compactMap { s in
            guard let c = counts[s], c > 0 else { return nil }
            return (score: s, label: scoreName(s), emoji: MoodUtils.emoji(forScore: s), count: c)
        }
    }

    private let fullDayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE"
        return f
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Chart
                    chartSection

                    // 2. Stats strip
                    statsStrip

                    // 3. Distribution
                    if !distribution.isEmpty {
                        distributionSection
                    }

                    // 4. Day-by-day detail
                    if !dataPoints.isEmpty {
                        dailyDetailSection
                    }
                }
                .padding()
            }
            .background { WarmGradientBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("心情趋势")
                            .font(.yuantiHeadline)
                        Text(weekLabel)
                            .font(.yuantiCaption)
                            .foregroundStyle(Color.claudeWarmGray)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.claudeWarmGray.opacity(0.6))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if weekEntries.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Mood", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.claudeAccent)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Mood", point.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.claudeAccent.opacity(0.35), Color.claudeAccent.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Mood", point.score)
                    )
                    .foregroundStyle(Color.claudeAccent)
                    .symbolSize(60)
                    .annotation(position: .top, spacing: 6) {
                        VStack(spacing: 1) {
                            Text(point.emoji)
                                .font(.system(size: 16))
                            Text(String(format: "%.1f", point.score))
                                .font(.yuantiCaption2)
                                .foregroundStyle(Color.claudeWarmGray)
                        }
                    }
                }
                .chartYScale(domain: 0.5...5.5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine().foregroundStyle(Color.claudeDivider)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(MoodUtils.emoji(forScore: v))
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
            Text("这周还没有记录哦")
                .font(.yuantiSubheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(
                label: "平均心情",
                value: String(format: "%.1f", avgScore),
                sub: MoodUtils.emoji(forScore: Int(avgScore.rounded()))
            )
            Divider().frame(height: 36)
            statCell(
                label: "最佳",
                value: bestDay.map { fullDayFmt.string(from: $0.date) } ?? "--",
                sub: bestDay?.emoji ?? ""
            )
            Divider().frame(height: 36)
            statCell(
                label: "最低",
                value: worstDay.map { fullDayFmt.string(from: $0.date) } ?? "--",
                sub: worstDay?.emoji ?? ""
            )
            Divider().frame(height: 36)
            statCell(
                label: "记录",
                value: "\(weekEntries.count)篇",
                sub: "共 \(dataPoints.count) 天"
            )
        }
        .padding(.vertical, 12)
        .glassCard(tint: .glassMoodTint)
    }

    private func statCell(label: String, value: String, sub: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.yuantiCaption)
                .foregroundStyle(Color.claudeWarmGray)
            Text(value)
                .font(.yuanti(14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.yuantiCaption2)
                .foregroundStyle(Color.claudeWarmGray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Distribution

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("心情分布")
                .font(.yuantiHeadline)
                .foregroundStyle(.primary)

            let maxCount = distribution.map(\.count).max() ?? 1
            VStack(spacing: 10) {
                ForEach(distribution, id: \.score) { item in
                    HStack(spacing: 10) {
                        Text(item.emoji)
                            .font(.system(size: 18))
                            .frame(width: 26)

                        GeometryReader { geo in
                            let barW = geo.size.width * CGFloat(item.count) / CGFloat(maxCount)
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.claudeAccent.opacity(0.1))
                                    .frame(maxWidth: .infinity)
                                Capsule()
                                    .fill(Color.claudeAccent.opacity(0.55))
                                    .frame(width: max(barW, 4))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: item.count)
                            }
                        }
                        .frame(height: 12)

                        Text("\(item.count)天")
                            .font(.yuantiCaption)
                            .foregroundStyle(Color.claudeWarmGray)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    // MARK: - Daily Detail

    private var dailyDetailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日详情")
                .font(.yuantiHeadline)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                ForEach(dataPoints) { point in
                    VStack(alignment: .leading, spacing: 8) {
                        // Day header
                        HStack(spacing: 8) {
                            Text(point.emoji)
                                .font(.system(size: 20))
                            Text(fullDayFmt.string(from: point.date))
                                .font(.yuanti(15, weight: .medium))
                            Spacer()
                            Text(String(format: "%.1f / 5", point.score))
                                .font(.yuantiCaption)
                                .foregroundStyle(Color.claudeWarmGray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.claudeAccent.opacity(0.08))
                                .clipShape(Capsule())
                        }

                        // Entry list for this day
                        ForEach(point.entries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.yuantiCaption)
                                    .foregroundStyle(Color.claudeWarmGray)
                                    .frame(width: 44, alignment: .leading)
                                Text(entry.summary)
                                    .font(.yuantiCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .padding(12)
                    .background(Color.claudeAccent.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    // MARK: - Helpers

    private func scoreName(_ score: Int) -> String {
        switch score {
        case 5: return "非常好"
        case 4: return "较好"
        case 3: return "一般"
        case 2: return "较差"
        default: return "很差"
        }
    }
}
