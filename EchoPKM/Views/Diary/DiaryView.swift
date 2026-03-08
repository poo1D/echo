import SwiftUI
import SwiftData
import AVFoundation

struct DiaryView: View {
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var entries: [DiaryEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedEntry: DiaryEntry?
    @State private var editingEntry: DiaryEntry?
    @State private var entryToDelete: DiaryEntry?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    timeline
                }
            }
            .navigationTitle("Diary")
            .sheet(item: $selectedEntry) { entry in
                JournalDetailSheet(entry: entry) { entryToRemove in
                    entryToDelete = entryToRemove
                    showDeleteConfirmation = true
                }
            }
            .sheet(item: $editingEntry) { entry in
                EditEntrySheet(entry: entry) {
                    entryToDelete = entry
                    showDeleteConfirmation = true
                }
            }
            .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        deleteEntry(entry)
                    }
                }
                Button("Cancel", role: .cancel) {
                    entryToDelete = nil
                }
            } message: {
                Text("This will permanently delete this diary entry and its associated files.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No entries yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start talking to Echo on the Home tab.\nConversations auto-save as diary entries.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Timeline

    private var timeline: some View {
        ScrollView {
            // Date row
            WeekDateRow()
                .padding(.horizontal)
                .padding(.top, 8)

            LazyVStack(spacing: 16) {
                ForEach(groupedByDay, id: \.0) { day, dayEntries in
                    Section {
                        ForEach(dayEntries) { entry in
                            DiaryCard(entry: entry)
                                .onTapGesture { selectedEntry = entry }
                                .contextMenu {
                                    Button {
                                        editingEntry = entry
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(daySectionTitle(day))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Grouping

    private var groupedByDay: [(Date, [DiaryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func daySectionTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Delete

    private func deleteEntry(_ entry: DiaryEntry) {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Remove associated audio files
        for fileName in entry.audioFileNames {
            let url = docs.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: url)
        }

        // Remove associated photo files
        for fileName in entry.photoFileNames {
            let url = docs.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: url)
        }

        // Delete associated ScheduleItems
        let entryID = entry.id
        if let schedules = try? modelContext.fetch(
            FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.sourceEntryID == entryID })
        ) {
            for item in schedules { modelContext.delete(item) }
        }

        // Delete associated HabitEntries
        if let habits = try? modelContext.fetch(
            FetchDescriptor<HabitEntry>(predicate: #Predicate { $0.sourceEntryID == entryID })
        ) {
            for item in habits { modelContext.delete(item) }
        }

        modelContext.delete(entry)
        try? modelContext.save()

        selectedEntry = nil
        entryToDelete = nil
    }
}

// MARK: - Week Date Row

private struct WeekDateRow: View {
    private let calendar = Calendar.current
    private let today = Date()

    var body: some View {
        HStack {
            ForEach(weekDays, id: \.self) { date in
                VStack(spacing: 4) {
                    Text(dayLetter(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption.weight(calendar.isDateInToday(date) ? .bold : .regular))
                        .foregroundStyle(calendar.isDateInToday(date) ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background(
                            calendar.isDateInToday(date)
                                ? Color.blue
                                : Color.clear
                        )
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekDays: [Date] {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Diary Card (Apple Journal Style)

private struct DiaryCard: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Photo grid
            if !entry.photoFileNames.isEmpty {
                PhotoGridView(photoFileNames: entry.photoFileNames)
            }

            // 2. Audio waveform player
            if let firstAudio = entry.audioFileNames.first {
                AudioWaveformPlayer(fileName: firstAudio)
            }

            // 3. Summary text
            Text(entry.summary)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(4)

            // 4. Bottom info row: mood + location + time
            HStack(spacing: 12) {
                if let emoji = entry.moodEmoji {
                    Text(emoji)
                        .font(.title3)
                }

                if let loc = entry.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(loc)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // 5. Topic tags (max 4)
            if !entry.topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(entry.topics.prefix(4)), id: \.self) { topic in
                        Text(topic)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }

            // 6. AI Insight
            if let insight = entry.aiInsight {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .padding(.horizontal)
    }
}

#Preview {
    DiaryView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
