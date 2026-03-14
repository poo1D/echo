import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var recentEntries: [DiaryEntry]
    @Query(sort: \ScheduleItem.date) private var allSchedules: [ScheduleItem]
    @Query(sort: \HabitEntry.date, order: .reverse) private var allHabits: [HabitEntry]

    @State private var chatService = ChatService()
    @State private var autoSaveService = AutoSaveService()
    @State private var speechService = SpeechService()
    @State private var petState = PetState()
    @State private var photoPickerService = PhotoPickerService()
    @State private var videoPickerService = VideoPickerService()
    @State private var insightService = InsightService()
    @State private var locationService = LocationService()
    @State private var scheduleHabitService = ScheduleHabitService()
    @State private var pipeline = MultiAgentPipeline()
    @State private var greetingService = ProactiveGreetingService()
    @State private var ragService = RAGService()

    @State private var feedItems: [FeedItem] = []
    @State private var inputText = ""
    @State private var inactivityTimer: Timer?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showSaveConfirmation = false
    @State private var hasLoadedProactive = false

    private var hasUserMessages: Bool {
        feedItems.contains { if case .userMessage = $0 { return true } else { return false } }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Pet area (compact)
                petSection
                    .frame(height: 100)

                Divider()

                // Feed (replaces chat section)
                feedSection

                Divider()

                // Voice input bar
                VoiceChatBar(
                    text: $inputText,
                    speechService: speechService,
                    isStreaming: pipeline.isRunning,
                    photoPickerService: photoPickerService,
                    videoPickerService: videoPickerService,
                    locationService: locationService,
                    onSend: sendMessage
                )
            }

            // Save as Diary button
            if hasUserMessages && !pipeline.isRunning && !autoSaveService.isSaving {
                Button(action: manualSave) {
                    Label("保存到日记", systemImage: "book.closed")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .modifier(GlassCapsuleModifier())
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            // Saving indicator
            if autoSaveService.isSaving {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("保存中...")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .modifier(GlassCapsuleModifier())
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            // Toast confirmation
            if showSaveConfirmation {
                Text("已保存到日记")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            Task { await speechService.requestPermissions() }
            loadProactiveCards()
            // Load RAG index; rebuild if empty
            ragService.loadIndex()
            if ragService.indexCount == 0, !recentEntries.isEmpty {
                ragService.rebuildIndex(entries: Array(recentEntries))
            }
        }
        .onDisappear {
            saveIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                saveIfNeeded()
            }
        }
    }

    // MARK: - Pet Section (compact, 100pt)

    private var petSection: some View {
        VStack(spacing: 2) {
            PetView(petState: petState)
                .scaleEffect(0.55)
                .frame(height: 80)

            Text(greetingService.generateGreeting(entries: Array(recentEntries), habits: Array(allHabits)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineLimit(2)
        }
        .padding(.top, 4)
    }

    // MARK: - Feed Section (replaces chatSection)

    private var feedSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(feedItems) { item in
                        FeedItemView(item: item)
                            .id(item.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { scrollProxy = proxy }
            .onChange(of: feedItems.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Load Proactive Cards

    private func loadProactiveCards() {
        guard !hasLoadedProactive else { return }
        hasLoadedProactive = true

        let cards = greetingService.generateFeedCards(
            entries: Array(recentEntries),
            schedules: Array(allSchedules),
            habits: Array(allHabits)
        )
        feedItems.append(contentsOf: cards)
    }

    // MARK: - Send Message (Multi-Agent Pipeline)

    private func sendMessage(_ text: String, photoFileNames: [String] = [], videoFileNames: [String] = [], location: PendingLocation? = nil) {
        // Track audio file from voice recording
        if let audioFile = speechService.currentAudioFileName {
            autoSaveService.sessionAudioFiles.append(audioFile)
            speechService.currentAudioFileName = nil
        }

        // Track photo files
        if !photoFileNames.isEmpty {
            autoSaveService.sessionPhotoFiles.append(contentsOf: photoFileNames)
        }

        // Track video files
        if !videoFileNames.isEmpty {
            autoSaveService.sessionVideoFiles.append(contentsOf: videoFileNames)
        }

        // Track location
        if let loc = location {
            autoSaveService.sessionLocation = loc
        }

        // Also keep messages in chatService for save compatibility
        let userMsg = ChatService.Message(role: .user, content: text, photoFileNames: photoFileNames, videoFileNames: videoFileNames)
        chatService.messages.append(userMsg)

        // Pet reacts to user message
        petState.react(to: text)
        petState.reactToPipeline(.agentsRunning)

        // Reset inactivity timer
        resetInactivityTimer()

        // 1. Add user message to feed
        feedItems.append(.userMessage(UserMessageData(
            content: text,
            photoFileNames: photoFileNames,
            videoFileNames: videoFileNames
        )))

        // 2. Add pipeline visualization (will be updated in real-time)
        let pipelineIndex = feedItems.count
        feedItems.append(.agentPipeline(pipeline.snapshot))

        // 3. Add placeholder assistant message (for streaming)
        let assistantIndex = feedItems.count
        feedItems.append(.assistantMessage(AssistantMessageData()))

        // 4. Run Multi-Agent Pipeline
        Task {
            let result = await pipeline.process(
                userMessage: text,
                photoFileNames: photoFileNames,
                videoFileNames: videoFileNames,
                location: location,
                recentEntries: Array(recentEntries.prefix(7)),
                allEntries: Array(recentEntries),
                schedules: Array(allSchedules),
                habits: Array(allHabits),
                modelContext: modelContext,
                chatService: chatService,
                ragService: ragService,
                onSynthesisDelta: { delta in
                    // Update pipeline snapshot in real-time
                    if pipelineIndex < feedItems.count {
                        feedItems[pipelineIndex] = .agentPipeline(pipeline.snapshot)
                    }

                    // Append streaming text to assistant message
                    if assistantIndex < feedItems.count,
                       case .assistantMessage(var data) = feedItems[assistantIndex] {
                        data.textContent += delta
                        feedItems[assistantIndex] = .assistantMessage(data)
                    }
                }
            )

            // Update pipeline to final state
            if pipelineIndex < feedItems.count {
                feedItems[pipelineIndex] = .agentPipeline(pipeline.snapshot)
            }

            // Parse rich cards and update assistant message
            let parsed = ToolCallParser.parse(result.response)
            if assistantIndex < feedItems.count {
                let assistantData = AssistantMessageData(
                    textContent: parsed.cleanText,
                    richCards: parsed.cards
                )
                feedItems[assistantIndex] = .assistantMessage(assistantData)
            }

            // Also store assistant response in chatService for save compatibility
            chatService.messages.append(ChatService.Message(role: .assistant, content: result.response))

            // Pet reacts to completion
            petState.reactToPipeline(.completed)

            // Add action confirm cards
            for schedule in result.action.schedules {
                feedItems.append(.actionConfirm(ActionConfirmData(
                    actionType: .scheduleCreated,
                    title: "已添加日程",
                    detail: "\(schedule.title) \(schedule.date.formatted(date: .abbreviated, time: .omitted))",
                    isExecuted: true
                )))
            }
            for habit in result.action.habits {
                feedItems.append(.actionConfirm(ActionConfirmData(
                    actionType: .habitLogged,
                    title: "习惯已记录",
                    detail: "今日已记录 \(habit.capitalized)",
                    isExecuted: true
                )))
            }

            pipeline.reset()
        }
    }

    // MARK: - Save

    private func saveIfNeeded() {
        guard hasUserMessages else { return }
        inactivityTimer?.invalidate()
        Task {
            await autoSaveService.saveFeedSession(
                feedItems: feedItems,
                chatService: chatService,
                modelContext: modelContext,
                insightService: insightService,
                scheduleHabitService: scheduleHabitService,
                ragService: ragService
            )
        }
    }

    private func manualSave() {
        guard hasUserMessages else { return }
        inactivityTimer?.invalidate()
        Task {
            await autoSaveService.saveFeedSession(
                feedItems: feedItems,
                chatService: chatService,
                modelContext: modelContext,
                insightService: insightService,
                scheduleHabitService: scheduleHabitService,
                ragService: ragService,
                minimumUserMessages: 1
            )
            withAnimation {
                showSaveConfirmation = true
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showSaveConfirmation = false
            }
        }
    }

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { _ in
            Task { @MainActor in
                saveIfNeeded()
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastID = feedItems.last?.id {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
