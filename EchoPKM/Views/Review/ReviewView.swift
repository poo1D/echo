import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var allEntries: [DiaryEntry]
    @Query(sort: \ScheduleItem.date, order: .forward) private var allSchedules: [ScheduleItem]
    @Query(sort: \HabitEntry.date, order: .reverse) private var allHabits: [HabitEntry]

    @State private var petObservation: String?
    @State private var isLoadingObservation = false
    @State private var petState = PetState()
    @State private var insightService = InsightService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mood chart
                    moodChartSection

                    // Pet observation
                    petObservationSection

                    // Key moments
                    keyMomentsSection

                    // Topics this week
                    topicFrequencySection

                    // Upcoming schedules
                    upcomingSection

                    // Habits this week
                    habitsSection
                }
                .padding()
            }
            .navigationTitle("Review")
            .task { await loadPetObservation() }
        }
    }

    // MARK: - Week Entries

    private var weekEntries: [DiaryEntry] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return allEntries.filter { $0.createdAt >= weekAgo }
    }

    // MARK: - Mood Chart

    private var moodChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood")
                .font(.headline)

            if weekEntries.isEmpty {
                Text("No entries this week yet")
                    .foregroundStyle(.tertiary)
                    .frame(height: 150)
            } else {
                Chart(moodDataPoints) { point in
                    BarMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Mood", point.score)
                    )
                    .foregroundStyle(barColor(for: point.score))
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5])
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private struct MoodDataPoint: Identifiable {
        let id = UUID()
        let dayLabel: String
        let score: Int
    }

    private var moodDataPoints: [MoodDataPoint] {
        let calendar = Calendar.current
        // Group by day, take average mood score
        let grouped = Dictionary(grouping: weekEntries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }

        let sorted = grouped.sorted { $0.key < $1.key }
        return sorted.map { (date, dayEntries) in
            let scores = dayEntries.compactMap(\.moodScore)
            let total = scores.reduce(0, +)
            let avgScore = scores.isEmpty ? 3 : total / scores.count
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            let label = formatter.string(from: date)
            return MoodDataPoint(dayLabel: label, score: avgScore)
        }
    }

    private func barColor(for score: Int) -> Color {
        switch score {
        case 1...2: return .orange
        case 3: return .yellow
        case 4...5: return .green
        default: return .gray
        }
    }

    // MARK: - Pet Observation

    private var petObservationSection: some View {
        HStack(alignment: .top, spacing: 16) {
            PetView(petState: petState)
                .scaleEffect(0.45)
                .frame(width: 60, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                if isLoadingObservation {
                    ProgressView()
                    Text("Echo is thinking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let observation = petObservation {
                    Text(observation)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else if weekEntries.isEmpty {
                    Text("Start journaling and I'll share my observations at the end of the week!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Key Moments

    private var keyMomentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Key Moments")
                .font(.headline)

            if weekEntries.isEmpty {
                Text("Nothing here yet")
                    .foregroundStyle(.tertiary)
            } else {
                let highlights = weekEntries
                    .sorted { ($0.moodScore ?? 3) > ($1.moodScore ?? 3) }
                    .prefix(5)

                ForEach(Array(highlights)) { entry in
                    HStack(spacing: 8) {
                        let icon = (entry.moodScore ?? 3) >= 4 ? "star.fill" : "thought.bubble"
                        Image(systemName: icon)
                            .foregroundStyle((entry.moodScore ?? 3) >= 4 ? .yellow : .gray)
                            .font(.caption)
                        Text(entry.summary)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Topic Frequency

    private var topicFrequencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Topics this week")
                .font(.headline)

            let topicCounts = aggregateTopics()
            if topicCounts.isEmpty {
                Text("No topics extracted yet")
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(topicCounts.prefix(10), id: \.0) { topic, count in
                        Text("\(topic) \(count)x")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func aggregateTopics() -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for entry in weekEntries {
            for topic in entry.topics {
                counts[topic.lowercased(), default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    // MARK: - Upcoming Schedules

    private var upcomingSchedules: [ScheduleItem] {
        let now = Calendar.current.startOfDay(for: Date())
        return allSchedules.filter { $0.date >= now && !$0.isCompleted }.prefix(5).map { $0 }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Upcoming", systemImage: "calendar")
                .font(.headline)

            if upcomingSchedules.isEmpty {
                Text("No upcoming events")
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(upcomingSchedules, id: \.id) { item in
                    HStack(spacing: 12) {
                        // Date badge
                        VStack(spacing: 2) {
                            Text(item.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("\(Calendar.current.component(.day, from: item.date))")
                                .font(.title3.weight(.bold))
                        }
                        .frame(width: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            if let notes = item.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            item.isCompleted = true
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Habits This Week

    private var weekHabits: [HabitEntry] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return allHabits.filter { $0.date >= weekAgo }
    }

    private var habitCounts: [(String, Int, String)] {
        var counts: [String: Int] = [:]
        for habit in weekHabits {
            counts[habit.name, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { (name, count) in
            (name, count, habitEmoji(for: name))
        }
    }

    private func habitEmoji(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("exercise") || lower.contains("gym") || lower.contains("workout") { return "💪" }
        if lower.contains("cook") { return "🍳" }
        if lower.contains("read") { return "📚" }
        if lower.contains("walk") { return "🚶" }
        if lower.contains("meditat") { return "🧘" }
        if lower.contains("run") { return "🏃" }
        if lower.contains("yoga") { return "🧘" }
        if lower.contains("sleep") { return "😴" }
        if lower.contains("water") || lower.contains("drink") { return "💧" }
        if lower.contains("study") { return "📝" }
        if lower.contains("music") { return "🎵" }
        if lower.contains("clean") { return "🧹" }
        return "🔄"
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Habits This Week", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)

            if habitCounts.isEmpty {
                Text("No habits tracked yet")
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(habitCounts, id: \.0) { name, count, emoji in
                    HStack(spacing: 10) {
                        Text(emoji)
                            .font(.title3)
                        Text(name.capitalized)
                            .font(.subheadline)
                        Spacer()
                        Text("[\(count)x]")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - LLM Observation (with cache)

    private func loadPetObservation() async {
        guard !weekEntries.isEmpty, petObservation == nil else { return }
        isLoadingObservation = true
        defer { isLoadingObservation = false }

        petObservation = await insightService.weeklyObservation(
            entries: weekEntries,
            modelContext: modelContext
        )
    }
}

// MARK: - Flow Layout (for topic tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, offsets: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), offsets)
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
