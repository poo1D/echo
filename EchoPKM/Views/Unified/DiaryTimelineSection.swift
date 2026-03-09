import SwiftUI

struct DiaryTimelineSection: View {
    var entries: [DiaryEntry]
    @Binding var selectedEntry: DiaryEntry?
    @Binding var editingEntry: DiaryEntry?
    @Binding var showTagFilter: Bool
    var selectedTags: Set<String>
    var onDeleteRequest: (DiaryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Diary")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showTagFilter = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(selectedTags.isEmpty ? Color.claudeWarmGray : Color.claudeAccent)
                        .padding(8)
                        .background(
                            selectedTags.isEmpty
                                ? Color.claudeSurfaceTint
                                : Color.claudeAccent.opacity(0.12),
                            in: Circle()
                        )
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Week date row
            WeekDateRow()
                .padding(.horizontal)
                .padding(.top, 8)

            // Active tag filter chips
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                            // Individual tag chips are rendered by the parent via binding
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.claudeAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.claudeAccent.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }

            // Entries
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(selectedTags.isEmpty ? "No entries yet" : "No matching entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
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
                                            onDeleteRequest(entry)
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
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Filtering & Grouping

    private var filteredEntries: [DiaryEntry] {
        if selectedTags.isEmpty { return entries }
        return entries.filter { entry in
            !selectedTags.isDisjoint(with: Set(entry.topics))
        }
    }

    private var groupedByDay: [(Date, [DiaryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
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
}
