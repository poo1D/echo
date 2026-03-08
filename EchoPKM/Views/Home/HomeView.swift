import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var recentEntries: [DiaryEntry]

    @State private var chatService = ChatService()
    @State private var autoSaveService = AutoSaveService()
    @State private var speechService = SpeechService()
    @State private var petState = PetState()
    @State private var photoPickerService = PhotoPickerService()
    @State private var insightService = InsightService()
    @State private var locationService = LocationService()
    @State private var scheduleHabitService = ScheduleHabitService()

    @State private var inputText = ""
    @State private var inactivityTimer: Timer?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showSaveConfirmation = false

    private var hasUserMessages: Bool {
        chatService.messages.contains { $0.role == .user }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Pet area
                petSection
                    .frame(height: 140)

                Divider()

                // Chat messages
                chatSection

                Divider()

                // Voice input bar
                VoiceChatBar(
                    text: $inputText,
                    speechService: speechService,
                    isStreaming: chatService.isStreaming,
                    photoPickerService: photoPickerService,
                    locationService: locationService,
                    onSend: sendMessage
                )
            }

            // Save as Diary button
            if hasUserMessages && !chatService.isStreaming && !autoSaveService.isSaving {
                Button(action: manualSave) {
                    Label("Save as Diary", systemImage: "book.closed")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            // Saving indicator
            if autoSaveService.isSaving {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Saving...")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            // Toast confirmation
            if showSaveConfirmation {
                Text("Saved to Diary")
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
        }
        .onDisappear {
            // Auto-save when leaving tab
            saveIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                saveIfNeeded()
            }
        }
    }

    // MARK: - Pet Section

    private var petSection: some View {
        VStack(spacing: 4) {
            PetView(petState: petState)
                .scaleEffect(0.7)
                .frame(height: 130)

            // Pet greeting or last AI message
            if let lastAI = chatService.messages.last(where: { $0.role == .assistant }) {
                Text(lastAI.content.prefix(80) + (lastAI.content.count > 80 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(2)
            } else {
                Text(greeting)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatService.messages.filter { $0.role != .system }) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    if chatService.isStreaming {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("thinking...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { scrollProxy = proxy }
            .onChange(of: chatService.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Actions

    private func sendMessage(_ text: String, photoFileNames: [String] = [], location: PendingLocation? = nil) {
        // Track audio file from voice recording
        if let audioFile = speechService.currentAudioFileName {
            autoSaveService.sessionAudioFiles.append(audioFile)
            speechService.currentAudioFileName = nil
        }

        // Track photo files
        if !photoFileNames.isEmpty {
            autoSaveService.sessionPhotoFiles.append(contentsOf: photoFileNames)
        }

        // Track location
        if let loc = location {
            autoSaveService.sessionLocation = loc
        }

        // Pet reacts to user message
        petState.react(to: text)

        // Reset inactivity timer
        resetInactivityTimer()

        // Send to LLM with enhanced context
        let photoFiles = photoFileNames
        let loc = location
        Task {
            await chatService.send(
                text,
                context: Array(recentEntries.prefix(7)),
                allEntries: Array(recentEntries),
                photoFileNames: photoFiles,
                location: loc
            )
        }
    }

    private func saveIfNeeded() {
        guard !chatService.messages.isEmpty else { return }
        inactivityTimer?.invalidate()
        Task {
            await autoSaveService.saveSession(
                messages: chatService.messages,
                chatService: chatService,
                modelContext: modelContext,
                insightService: insightService,
                scheduleHabitService: scheduleHabitService
            )
        }
    }

    private func manualSave() {
        guard hasUserMessages else { return }
        inactivityTimer?.invalidate()
        Task {
            await autoSaveService.saveSession(
                messages: chatService.messages,
                chatService: chatService,
                modelContext: modelContext,
                insightService: insightService,
                scheduleHabitService: scheduleHabitService,
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
        if let lastID = chatService.messages.last?.id {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning! How's your day starting?"
        case 12..<17: return "Good afternoon! What's been on your mind?"
        case 17..<22: return "Good evening! How was your day?"
        default: return "Can't sleep? I'm here to listen."
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatService.Message

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 60) }

            // AI avatar
            if message.role == .assistant {
                Circle()
                    .fill(Color.claudeAccent)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Photo thumbnails
                if !message.photoFileNames.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.photoFileNames, id: \.self) { fileName in
                            let url = PhotoPickerService.photoURL(for: fileName)
                            if let data = try? Data(contentsOf: url),
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }

                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? Color.claudeUserBubble
                            : Color.claudeAssistantBubble
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                    .foregroundStyle(.primary)
                    .font(.body)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
