import SwiftUI
import SwiftData

/// 对话式日记编辑器 — 通过和 Echo 聊天来写日记
struct ConversationalJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 保存完成回调
    var onSaveComplete: (() -> Void)?
    
    // 对话服务
    @State private var conversationService = AIConversationService()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    // 模式
    @State private var selectedMode: JournalMode = .aiGuided
    @State private var showFreeWrite = false
    
    // 完成流程
    @State private var showSummarySheet = false
    @State private var generatedSummary = ""
    @State private var isSummarizing = false
    @State private var selectedMood: MoodPicker.Mood = .calm
    
    // 语音
    @State private var showVoiceRecorder = false
    @State private var voiceTranscription = ""
    @State private var voiceAudioURL: URL?
    
    // 保存
    @State private var isSaving = false
    
    enum JournalMode: String, CaseIterable {
        case aiGuided = "AI引导"
        case freeWrite = "自由写"
        case voice = "语音"
        case photo = "拍照"
        
        var icon: String {
            switch self {
            case .aiGuided: return "✨"
            case .freeWrite: return "📝"
            case .voice: return "🎤"
            case .photo: return "📸"
            }
        }
        
        var tintColor: Color {
            switch self {
            case .aiGuided: return Color.blue.opacity(0.15)
            case .freeWrite: return Color.green.opacity(0.15)
            case .voice: return Color.orange.opacity(0.15)
            case .photo: return Color.pink.opacity(0.15)
            }
        }
        
        var borderColor: Color {
            switch self {
            case .aiGuided: return Color.blue.opacity(0.4)
            case .freeWrite: return Color.green.opacity(0.4)
            case .voice: return Color.orange.opacity(0.4)
            case .photo: return Color.pink.opacity(0.4)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 模式标签栏
                modeTabBar
                
                // 对话区域
                messageList
                
                // 底部输入栏
                inputBar
            }
            .background(PaperTexture())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 时间戳
                    Text(currentTimeString)
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        finishConversation()
                    }
                    .font(JournalFonts.headline)
                    .foregroundStyle(conversationService.messages.isEmpty ? JournalColors.warmGray : JournalColors.inkBlack)
                    .disabled(conversationService.messages.isEmpty)
                }
            }
            .task {
                // 启动 AI 引导对话
                await startGuidedConversation()
            }
            .sheet(isPresented: $showVoiceRecorder) {
                VoiceRecorderView(
                    transcribedText: $voiceTranscription,
                    audioURL: $voiceAudioURL
                )
            }
            .sheet(isPresented: $showSummarySheet) {
                JournalSummaryPreviewSheet(
                    summary: $generatedSummary,
                    selectedMood: $selectedMood,
                    isSaving: $isSaving,
                    onSave: { saveJournal() },
                    onDiscard: { showSummarySheet = false }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFreeWrite) {
                JournalEditorView(onSaveComplete: {
                    showFreeWrite = false
                    onSaveComplete?()
                })
            }
            .onChange(of: voiceTranscription) { _, newValue in
                if !newValue.isEmpty {
                    inputText = newValue
                    voiceTranscription = ""
                }
            }
        }
    }
    
    // MARK: - 时间
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
    
    // MARK: - Mode Tab Bar
    private var modeTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(JournalMode.allCases, id: \.self) { mode in
                    Button {
                        handleModeSelection(mode)
                    } label: {
                        HStack(spacing: 6) {
                            Text(mode.icon)
                                .font(.caption)
                            Text(mode.rawValue)
                                .font(JournalFonts.caption)
                                .fontWeight(selectedMode == mode ? .semibold : .regular)
                        }
                        .foregroundStyle(JournalColors.inkBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedMode == mode ? mode.tintColor : Color.clear,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    mode.borderColor,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(conversationService.messages) { message in
                        ConversationBubble(
                            message: message,
                            isStreaming: conversationService.isStreaming && message.id == conversationService.messages.last?.id
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: conversationService.messages.count) { _, _ in
                if let lastMessage = conversationService.messages.last {
                    withAnimation(.spring(response: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 12) {
            // 文字输入
            TextField("说说今天的事...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(JournalColors.warmWhite, in: Capsule())
                .focused($isInputFocused)
            
            // 语音按钮
            Button {
                showVoiceRecorder = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundStyle(JournalColors.warmGray)
                    .frame(width: 36, height: 36)
            }
            
            // 发送按钮
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? JournalColors.warmGray : JournalColors.lavender)
            }
            .disabled(inputText.isEmpty || conversationService.isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
    private func handleModeSelection(_ mode: JournalMode) {
        selectedMode = mode
        switch mode {
        case .freeWrite:
            showFreeWrite = true
        case .voice:
            showVoiceRecorder = true
        case .photo:
            // TODO: Phase 2 — 拍照功能
            break
        case .aiGuided:
            break
        }
    }
    
    private func startGuidedConversation() async {
        await conversationService.startConversation(
            with: "（用户刚打开日记，请用温暖的方式问候并引导用户分享今天的事情。只问一个问题，1-2句话。）",
            modelContext: modelContext
        )
    }
    
    private func sendMessage() {
        let message = inputText
        inputText = ""
        Task {
            await conversationService.sendMessage(message, modelContext: modelContext)
        }
    }
    
    private func finishConversation() {
        isSummarizing = true
        Task {
            let summary = await JournalSummaryService.shared.summarizeConversation(
                conversationService.messages
            )
            generatedSummary = summary
            isSummarizing = false
            showSummarySheet = true
        }
    }
    
    private func saveJournal() {
        isSaving = true
        
        let content = "[\(selectedMood.rawValue) \(selectedMood.label)] \(generatedSummary)"
        let entry = JournalEntry(title: "", textContent: content)
        entry.moodEmoji = selectedMood.rawValue
        modelContext.insert(entry)
        
        Task {
            // 记忆写入管线
            await MemoryManager.shared.processJournalEntry(entry, modelContext: modelContext)
            
            // 喂宠物
            await MainActor.run {
                PetStateManager.shared.feed(journalContent: content)
            }
            
            await MainActor.run {
                isSaving = false
                showSummarySheet = false
                conversationService.clearConversation()
                
                if let onSaveComplete {
                    onSaveComplete()
                } else {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - 对话气泡（手帐风格）
struct ConversationBubble: View {
    let message: AIConversationService.ConversationMessage
    let isStreaming: Bool
    
    private var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 50) }
            
            if !isUser {
                // Echo 头像
                Circle()
                    .fill(JournalColors.lavender.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text("🐾")
                            .font(.caption)
                    }
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isUser
                            ? JournalColors.peach.opacity(0.25)
                            : JournalColors.lavender.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                
                // 流式光标
                if isStreaming && !isUser {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(JournalColors.lavender)
                                .frame(width: 4, height: 4)
                                .opacity(isStreaming ? 1 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(i) * 0.2),
                                    value: isStreaming
                                )
                        }
                    }
                    .padding(.leading, 8)
                }
            }
            
            if !isUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - 日记整理预览弹窗
struct JournalSummaryPreviewSheet: View {
    @Binding var summary: String
    @Binding var selectedMood: MoodPicker.Mood
    @Binding var isSaving: Bool
    let onSave: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 标题
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(JournalColors.lavender)
                    Text("Echo 帮你整理的日记")
                        .font(JournalFonts.headline)
                        .foregroundStyle(JournalColors.inkBlack)
                    Spacer()
                }
                
                // 日记内容预览（可编辑）
                TextEditor(text: $summary)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .frame(minHeight: 120)
                    .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 16))
                
                // 心情选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("今天的心情")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(MoodPicker.Mood.allCases, id: \.self) { mood in
                                Button {
                                    selectedMood = mood
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.rawValue)
                                            .font(.title2)
                                        Text(mood.label)
                                            .font(.caption2)
                                            .foregroundStyle(JournalColors.warmGray)
                                    }
                                    .padding(8)
                                    .background(
                                        selectedMood == mood
                                            ? mood.color.opacity(0.3)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 16) {
                    Button {
                        onDiscard()
                    } label: {
                        Text("继续聊")
                            .font(JournalFonts.body)
                            .foregroundStyle(JournalColors.warmGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(JournalColors.warmWhite, in: Capsule())
                    }
                    
                    Button {
                        onSave()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                Text("保存日记")
                            }
                        }
                        .font(JournalFonts.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(JournalColors.lavender, in: Capsule())
                    }
                    .disabled(isSaving || summary.isEmpty)
                }
            }
            .padding()
            .background(PaperTexture())
        }
    }
}

#Preview {
    ConversationalJournalView()
        .modelContainer(for: [JournalEntry.self, AIInsight.self, Tag.self, MediaAttachment.self, UserProfile.self, FactMemory.self, JournalEmbedding.self])
}
