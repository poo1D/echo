import SwiftUI

struct TopicDetailSheet: View {
    let weekEntries: [DiaryEntry]
    let weekLabel: String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: String?

    // MARK: - Data

    private struct TopicStat: Identifiable {
        let id: String
        let topic: String
        let count: Int
        let avgMood: Double
        let entries: [DiaryEntry]
    }

    private var topicStats: [TopicStat] {
        var counts: [String: Int] = [:]
        var moodSums: [String: [Int]] = [:]
        var entryMap: [String: [DiaryEntry]] = [:]

        for entry in weekEntries {
            for topic in entry.topics {
                let t = topic.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { continue }
                counts[t, default: 0] += 1
                if let score = entry.moodScore {
                    moodSums[t, default: []].append(score)
                }
                entryMap[t, default: []].append(entry)
            }
        }

        return counts
            .sorted { $0.value > $1.value }
            .map { topic, count in
                let moods = moodSums[topic] ?? []
                let avg = moods.isEmpty ? 3.0 : Double(moods.reduce(0, +)) / Double(moods.count)
                let entries = (entryMap[topic] ?? []).sorted { $0.createdAt < $1.createdAt }
                return TopicStat(id: topic, topic: topic, count: count, avgMood: avg, entries: entries)
            }
    }

    private var displayedStats: [TopicStat] {
        guard let sel = selectedTopic else { return topicStats }
        return topicStats.filter { $0.topic == sel }
    }

    private var totalTopics: Int { topicStats.count }

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Summary row
                    summaryRow

                    // 2. Topic ranking
                    rankingSection

                    // 3. Entries per topic
                    entrySection
                }
                .padding()
            }
            .background { WarmGradientBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("话题分析")
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

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(totalTopics)", label: "话题")
            Divider().frame(height: 36)
            statCell(value: "\(weekEntries.count)", label: "篇记录")
            Divider().frame(height: 36)
            if let top = topicStats.first {
                statCell(value: top.topic, label: "最多话题")
                Divider().frame(height: 36)
                let avgMoodAllWeek: Double = {
                    let scores = weekEntries.compactMap(\.moodScore)
                    guard !scores.isEmpty else { return 3 }
                    return Double(scores.reduce(0, +)) / Double(scores.count)
                }()
                statCell(
                    value: MoodUtils.emoji(forScore: Int(avgMoodAllWeek.rounded())),
                    label: "周均心情"
                )
            }
        }
        .padding(.vertical, 12)
        .glassCard(tint: .glassMoodTint)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.yuanti(15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.yuantiCaption)
                .foregroundStyle(Color.claudeWarmGray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ranking Section

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("频次 & 心情关联")
                    .font(.yuantiHeadline)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedTopic != nil {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTopic = nil
                        }
                    } label: {
                        Text("显示全部")
                            .font(.yuantiCaption)
                            .foregroundStyle(Color.claudeAccent)
                    }
                }
            }

            let maxCount = topicStats.first?.count ?? 1
            VStack(spacing: 10) {
                ForEach(topicStats) { stat in
                    let isSelected = selectedTopic == stat.topic
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTopic = isSelected ? nil : stat.topic
                        }
                    } label: {
                        HStack(spacing: 10) {
                            // Topic name
                            Text(stat.topic)
                                .font(.yuanti(13, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.claudeAccent : .primary)
                                .frame(width: 52, alignment: .leading)
                                .lineLimit(1)

                            // Bar
                            GeometryReader { geo in
                                let barW = geo.size.width * CGFloat(stat.count) / CGFloat(maxCount)
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.claudeAccent.opacity(0.1))
                                        .frame(maxWidth: .infinity)
                                    Capsule()
                                        .fill(isSelected
                                              ? Color.claudeAccent.opacity(0.75)
                                              : Color.claudeAccent.opacity(0.45))
                                        .frame(width: max(barW, 4))
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: stat.count)
                                }
                            }
                            .frame(height: 12)

                            // Count
                            Text("\(stat.count)次")
                                .font(.yuantiCaption)
                                .foregroundStyle(Color.claudeWarmGray)
                                .frame(width: 30, alignment: .trailing)

                            // Avg mood emoji
                            Text(MoodUtils.emoji(forScore: Int(stat.avgMood.rounded())))
                                .font(.system(size: 16))
                                .frame(width: 24)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        isSelected
                            ? Color.claudeAccent.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }

            // Tip
            if selectedTopic == nil {
                Text("点击话题可查看关联日记")
                    .font(.yuantiCaption2)
                    .foregroundStyle(Color.claudeWarmGray.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    // MARK: - Entry Section

    private var entrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedTopic.map { "「\($0)」相关日记" } ?? "话题关联日记")
                    .font(.yuantiHeadline)
                    .foregroundStyle(.primary)
                Spacer()
            }

            if displayedStats.isEmpty {
                Text("没有记录")
                    .font(.yuantiSubheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(displayedStats) { stat in
                    topicEntriesGroup(stat: stat)
                }
            }
        }
        .padding(16)
        .glassCard(tint: .glassMoodTint)
    }

    private func topicEntriesGroup(stat: TopicStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Topic header
            HStack(spacing: 6) {
                Text(stat.topic)
                    .font(.yuanti(14, weight: .medium))
                    .foregroundStyle(Color.claudeAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.claudeAccent.opacity(0.1))
                    .clipShape(Capsule())

                Text("心情均分 \(String(format: "%.1f", stat.avgMood))")
                    .font(.yuantiCaption)
                    .foregroundStyle(Color.claudeWarmGray)

                Spacer()

                Text(MoodUtils.emoji(forScore: Int(stat.avgMood.rounded())))
                    .font(.system(size: 16))
            }

            // Entries
            VStack(spacing: 8) {
                ForEach(stat.entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateFmt.string(from: entry.createdAt))
                                .font(.yuantiCaption2)
                                .foregroundStyle(Color.claudeWarmGray)
                            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.yuantiCaption2)
                                .foregroundStyle(Color.claudeWarmGray.opacity(0.6))
                        }
                        .frame(width: 48)

                        if let emoji = entry.moodEmoji {
                            Text(emoji)
                                .font(.system(size: 16))
                        }

                        Text(entry.summary)
                            .font(.yuantiCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(10)
                    .background(Color.claudeAccent.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
