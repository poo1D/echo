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
                        proactiveCards: proactiveCards,
                        onTapEcho: {
                            showConversation = true
                        },
                        onQuickAction: handleQuickAction
                    )

                    // Gradient fade
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.claudeBackground.opacity(0), Color.claudeBackground],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 20)

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
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .background(Color.claudeBackground)
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

    // MARK: - Proactive Cards

    private var proactiveCards: [ProactiveCardData] {
        var cards: [ProactiveCardData] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Today's schedules
        let todaySchedules = allSchedules.filter { !$0.isCompleted && calendar.isDate($0.date, inSameDayAs: today) }
        for schedule in todaySchedules.prefix(2) {
            let timeStr = schedule.date.formatted(date: .omitted, time: .shortened)
            cards.append(ProactiveCardData(
                icon: "calendar",
                iconColor: "4A90D9",
                title: schedule.title,
                subtitle: "Today at \(timeStr)",
                type: .schedule
            ))
        }

        // Habit streaks
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let thisWeekHabits = allHabits.filter { $0.date >= weekStart }
        var habitDays: [String: Set<Int>] = [:]
        for h in thisWeekHabits {
            let dayOfWeek = calendar.component(.weekday, from: h.date)
            habitDays[h.name, default: []].insert(dayOfWeek)
        }
        for (name, days) in habitDays where days.count >= 3 {
            let emoji = HabitStreakData.emojiFor(name)
            cards.append(ProactiveCardData(
                icon: "flame.fill",
                iconColor: "FF6B35",
                title: "\(emoji) \(name.capitalized) \(days.count)d",
                subtitle: "Keep it up!",
                type: .habit
            ))
        }

        return Array(cards.prefix(4))
    }

    // MARK: - All Topics

    private var allTopics: [String] {
        var topics = Set<String>()
        for entry in entries {
            topics.formUnion(entry.topics)
        }
        return topics.sorted()
    }

    // MARK: - Quick Actions

    private func handleQuickAction(_ card: ProactiveCardData) {
        switch card.type {
        case .schedule:
            // Mark the matching schedule as completed
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            if let schedule = allSchedules.first(where: {
                !$0.isCompleted && $0.title == card.title && calendar.isDate($0.date, inSameDayAs: today)
            }) {
                schedule.isCompleted = true
                try? modelContext.save()
            }
        case .habit:
            // Log habit for today
            let habitName = card.title
                .replacingOccurrences(of: "\\p{So}", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: " ").first?.lowercased() ?? ""
            if !habitName.isEmpty {
                let habit = HabitEntry(name: habitName, date: Date())
                modelContext.insert(habit)
                try? modelContext.save()
            }
        default:
            break
        }
    }

    // MARK: - Load Today's Mood

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
