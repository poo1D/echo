import SwiftUI
import SwiftData

struct UnifiedView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var entries: [DiaryEntry]
    @Query(sort: \ScheduleItem.date) private var allSchedules: [ScheduleItem]
    @Query(sort: \HabitEntry.date, order: .reverse) private var allHabits: [HabitEntry]

    @State private var petState = PetState()
    @State private var greetingService = ProactiveGreetingService()

    @State private var showConversation = false
    @State private var selectedEntry: DiaryEntry?
    @State private var editingEntry: DiaryEntry?
    @State private var entryToDelete: DiaryEntry?
    @State private var showDeleteConfirmation = false
    @State private var selectedTags: Set<String> = []
    @State private var showTagFilter = false
    @State private var showMoodPicker = false
    @State private var todayMoodEmoji: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // Echo Hub (penguin + proactive bubbles)
                    EchoHubSection(
                        petState: petState,
                        greeting: greetingService.generateGreeting(
                            entries: Array(entries),
                            habits: Array(allHabits)
                        ),
                        averageMoodAtmosphere: todayMoodAtmosphere,
                        onTapEcho: {
                            showConversation = true
                        }
                    )

                    // Diary timeline
                    DiaryTimelineSection(
                        entries: Array(entries),
                        selectedEntry: $selectedEntry,
                        editingEntry: $editingEntry,
                        showTagFilter: $showTagFilter,
                        selectedTags: selectedTags,
                        onDeleteRequest: { entry in
                            entryToDelete = entry
                            showDeleteConfirmation = true
                        }
                    )
                }
            }

            // Floating mood picker button
            Button {
                showMoodPicker = true
            } label: {
                Text(todayMoodEmoji ?? "😊")
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .modifier(GlassCircleModifier())
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .background(
            LinearGradient(
                stops: [
                    Gradient.Stop(color: todayMoodAtmosphere.gradient.first ?? Color.claudeSurfaceTint, location: 0),
                    Gradient.Stop(color: Color.claudeBackground, location: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.5), value: todayMoodAtmosphere)
        )
        .fullScreenCover(isPresented: $showConversation) {
            ConversationView(
                petState: petState,
                dismiss: {
                    showConversation = false
                }
            )
        }
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
        .sheet(isPresented: $showTagFilter) {
            TagFilterSheet(
                allTopics: allTopics,
                selectedTags: $selectedTags
            )
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
        .sheet(isPresented: $showMoodPicker) {
            MoodPickerPopover(
                isPresented: $showMoodPicker,
                todayMoodEmoji: $todayMoodEmoji
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            loadTodayMood()
        }
    }

    // MARK: - All Topics

    private var allTopics: [String] {
        var topics = Set<String>()
        for entry in entries {
            topics.formUnion(entry.topics)
        }
        return topics.sorted()
    }

    // MARK: - Load Today's Mood

    private var todayMoodAtmosphere: MoodAtmosphere {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEntries = entries.filter { $0.createdAt >= todayStart }
        let scores = todayEntries.compactMap(\.moodScore)
        guard !scores.isEmpty else { return .neutral }
        let avg = scores.reduce(0, +) / scores.count
        return MoodAtmosphere.from(moodScore: avg)
    }

    private func loadTodayMood() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let sentinel = MoodUtils.moodCheckinTopic
        let todayEntries = entries.filter { $0.createdAt >= todayStart }
        if let existing = todayEntries.first(where: { $0.topics.contains(sentinel) }) {
            todayMoodEmoji = existing.moodEmoji
        }
    }

    // MARK: - Delete Entry

    private func deleteEntry(_ entry: DiaryEntry) {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        for fileName in entry.audioFileNames {
            try? fileManager.removeItem(at: docs.appendingPathComponent(fileName))
        }
        for fileName in entry.photoFileNames {
            try? fileManager.removeItem(at: docs.appendingPathComponent(fileName))
        }
        for fileName in entry.videoFileNames {
            try? fileManager.removeItem(at: docs.appendingPathComponent(fileName))
        }

        let entryID = entry.id
        if let schedules = try? modelContext.fetch(
            FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.sourceEntryID == entryID })
        ) {
            for item in schedules { modelContext.delete(item) }
        }

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

#Preview {
    UnifiedView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
