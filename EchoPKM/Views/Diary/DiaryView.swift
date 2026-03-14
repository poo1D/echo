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
            .background { WarmGradientBackground() }
            .navigationTitle("日记")
            .sheet(item: $selectedEntry) { entry in
                JournalDetailSheet(entry: entry) { entryToRemove in
                    entryToDelete = entryToRemove
                    showDeleteConfirmation = true
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
            }
            .sheet(item: $editingEntry) { entry in
                EditEntrySheet(entry: entry) {
                    entryToDelete = entry
                    showDeleteConfirmation = true
                }
            }
            .alert("删除条目？", isPresented: $showDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    if let entry = entryToDelete {
                        deleteEntry(entry)
                    }
                }
                Button("取消", role: .cancel) {
                    entryToDelete = nil
                }
            } message: {
                Text("这将永久删除此日记条目及其关联文件。")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("还没有记录")
                .font(.yuantiHeadline)
                .foregroundStyle(.secondary)
            Text("在首页和Echo聊天吧~\n对话会自动保存为日记。")
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
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(daySectionTitle(day))
                            .font(.yuantiTitle3)
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
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE, M月d日, yyyy"
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

        // Remove associated video files
        for fileName in entry.videoFileNames {
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

// DiaryCard and WeekDateRow are now in Views/Shared/

#Preview {
    DiaryView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
