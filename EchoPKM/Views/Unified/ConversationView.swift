import SwiftUI
import SwiftData

struct ConversationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var recentEntries: [DiaryEntry]
    @Query(sort: \ScheduleItem.date) private var allSchedules: [ScheduleItem]
    @Query(sort: \HabitEntry.date, order: .reverse) private var allHabits: [HabitEntry]

    @State private var chatService = ChatService()
    @State private var autoSaveService = AutoSaveService()
    @State private var speechService = SpeechService()
    @State private var photoPickerService = PhotoPickerService()
    @State private var videoPickerService = VideoPickerService()
    @State private var insightService = InsightService()
    @State private var locationService = LocationService()
    @State private var scheduleHabitService = ScheduleHabitService()
    @State private var pipeline = MultiAgentPipeline()
    @State private var greetingService = ProactiveGreetingService()
    @State private var ragService = RAGService()
    @State private var healthService = HealthKitService()

    @State private var feedItems: [FeedItem] = []
    @State private var inputText = ""
    @State private var inactivityTimer: Timer?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showSaveConfirmation = false
    @State private var hasLoadedProactive = false
    @State private var moodAtmosphere: MoodAtmosphere = .neutral
    @State private var healthSnapshot: HealthSnapshot?

    var petState: PetState
    var initialMoodEmoji: String?
    var dismiss: () -> Void

    private var hasUserMessages: Bool {
        feedItems.contains { if case .userMessage = $0 { return true } else { return false } }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Feed
                    feedSection

                    // Multimodal input
                    MultimodalInputBar(
                        text: $inputText,
                        speechService: speechService,
                        isStreaming: pipeline.isRunning,
                        photoPickerService: photoPickerService,
                        videoPickerService: videoPickerService,
                        locationService: locationService,
                        onSend: sendMessage
                    )
                }
                .background(
                    LinearGradient(
                        colors: moodAtmosphere.gradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: moodAtmosphere)
                )

                // Saving indicator
                if autoSaveService.isSaving {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("保存中...")
                            .font(.yuantiCaption.weight(.medium))
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
                        .font(.yuantiCaption.weight(.medium))
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Echo")
                        .font(.yuanti(20, weight: .bold))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.claudeAccent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if hasUserMessages && !pipeline.isRunning && !autoSaveService.isSaving {
                        Button(action: manualSave) {
                            Label("保存", systemImage: "book.closed")
                                .font(.yuantiCaption.weight(.medium))
                        }
                        .foregroundStyle(Color.claudeAccent)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await speechService.requestPermissions()
                await healthService.requestAuthorization()
                healthSnapshot = await healthService.buildSnapshot()
            }
            loadProactiveCards()
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

    // MARK: - Feed Section

    private var feedSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(feedItems) { item in
                        FeedItemView(item: item)
                            .id(item.id)
                    }
                    // 引导提示：仅在没有用户消息时显示
                    if !hasUserMessages {
                        suggestedPromptsView
                            .padding(.top, 4)
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

    // MARK: - Suggested Prompts

    private let suggestedPrompts = [
        "今天开会被领导说了，好难受",
        "刚跑完步，累但很爽 💪",
        "最近睡眠很差，很焦虑",
        "今天有个好消息想分享！",
    ]

    private var suggestedPromptsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("试试说...")
                .font(.yuantiCaption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestedPrompts, id: \.self) { prompt in
                        Button {
                            inputText = prompt
                            sendMessage(prompt)
                        } label: {
                            Text(prompt)
                                .font(.yuantiCaption.weight(.medium))
                                .foregroundStyle(Color.claudeAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.claudeAccent.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .strokeBorder(Color.claudeAccent.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Load Proactive Cards

    private func loadProactiveCards() {
        guard !hasLoadedProactive else { return }
        hasLoadedProactive = true

        // Greeting bubble — mirrors the text shown on the home hub
        let greetingText = greetingService.generateGreeting(
            entries: Array(recentEntries),
            habits: Array(allHabits)
        )
        feedItems.append(.assistantMessage(AssistantMessageData(textContent: greetingText)))

        // Proactive cards (schedule reminders, habit streaks, mood care…) — 仅在主页展示，对话页不显示
        // let cards = greetingService.generateFeedCards(...)
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

        // Intent routing
        let router = IntentRouter()
        let agentSelection = router.route(
            message: text,
            hasMedia: !photoFileNames.isEmpty || !videoFileNames.isEmpty,
            healthAuthorized: healthService.isAuthorized
        )

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

        // 2. Add placeholder assistant message (for streaming) — 不再插入 pipeline 卡片
        let assistantIndex = feedItems.count
        feedItems.append(.assistantMessage(AssistantMessageData()))

        // 4. Run Multi-Agent Pipeline with intent routing
        Task {
            // 用于累积原始流式文本（含 <card> 标记），与显示内容分离
            var rawStreamText = ""

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
                agentSelection: agentSelection,
                healthSnapshot: healthSnapshot,
                onSynthesisDelta: { delta in
                    rawStreamText += delta
                    // 流式阶段过滤掉 <card> 标记，避免 JSON 内容暴露给用户
                    let displayText = Self.stripCardMarkup(rawStreamText)
                    if assistantIndex < feedItems.count {
                        feedItems[assistantIndex] = .assistantMessage(
                            AssistantMessageData(textContent: displayText)
                        )
                    }
                }
            )

            // 流式结束后替换为完整解析结果（result.response 已是 cleanText）
            if assistantIndex < feedItems.count {
                feedItems[assistantIndex] = .assistantMessage(
                    AssistantMessageData(textContent: result.response, richCards: result.richCards)
                )
            }

            // Also store assistant response in chatService for save compatibility
            chatService.messages.append(ChatService.Message(role: .assistant, content: result.response))

            // Update mood atmosphere based on emotion result
            withAnimation(.easeInOut(duration: 1.5)) {
                moodAtmosphere = MoodAtmosphere.from(moodScore: result.emotion.moodScore)
            }

            // Update pet accessories
            petState.updateAccessories(
                from: text,
                moodScore: result.emotion.moodScore,
                hour: Calendar.current.component(.hour, from: Date())
            )

            // Pet reacts to completion
            petState.reactToPipeline(.completed)

            // 不再在对话页追加 actionConfirm 卡片，由主页的 ProactiveActionStack 处理

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
                ragService: ragService,
                moodEmoji: initialMoodEmoji
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
                minimumUserMessages: 1,
                moodEmoji: initialMoodEmoji
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

    /// 流式渲染时，过滤掉 <card> 标记（完整的和尚未关闭的），只展示纯文本
    private static func stripCardMarkup(_ text: String) -> String {
        var result = text
        // 去除已闭合的 <card type="...">...</card> 块
        if let regex = try? NSRegularExpression(pattern: #"<card\s+type="\w+">[\s\S]*?</card>"#) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        // 去除末尾尚未关闭的 <card...> 片段（流式过程中未完成的 card 块）
        if let lastCardStart = result.range(of: "<card", options: .backwards) {
            let afterTag = result[lastCardStart.lowerBound...]
            if !afterTag.contains("</card>") {
                result = String(result[..<lastCardStart.lowerBound])
            }
        }
        return result
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
