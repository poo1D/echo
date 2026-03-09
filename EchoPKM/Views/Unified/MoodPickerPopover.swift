import SwiftUI
import SwiftData

struct MoodPickerPopover: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @Binding var todayMoodEmoji: String?

    @State private var showToast = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(spacing: 16) {
            Text("今天心情如何？")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MoodUtils.emojis, id: \.self) { emoji in
                    Button {
                        selectMood(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 48, height: 48)
                            .background(
                                todayMoodEmoji == emoji
                                    ? Color.claudeAccent.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            if showToast {
                Text("心情已记录")
                    .font(.caption)
                    .foregroundStyle(Color.claudeAccent)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(Color.claudeCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
    }

    private func selectMood(_ emoji: String) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        saveMoodCheckin(emoji: emoji)
        todayMoodEmoji = emoji

        withAnimation(.easeIn(duration: 0.2)) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                isPresented = false
                showToast = false
            }
        }
    }

    private func saveMoodCheckin(emoji: String) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let sentinel = MoodUtils.moodCheckinTopic

        // Find existing mood check-in for today
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> {
                $0.createdAt >= todayStart && $0.createdAt < tomorrowStart
            }
        )

        let todayEntries = (try? modelContext.fetch(descriptor)) ?? []
        let existing = todayEntries.first { $0.topics.contains(sentinel) }

        if let entry = existing {
            entry.summary = "心情记录: \(emoji)"
            entry.moodEmoji = emoji
            entry.moodScore = MoodUtils.score(for: emoji)
        } else {
            let entry = DiaryEntry(
                summary: "心情记录: \(emoji)",
                moodEmoji: emoji,
                moodScore: MoodUtils.score(for: emoji),
                topics: [sentinel]
            )
            modelContext.insert(entry)
        }

        try? modelContext.save()
    }
}
