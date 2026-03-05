import SwiftUI
import SwiftData

struct JournalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 保存完成回调（用于Tab导航）
    var onSaveComplete: (() -> Void)?
    
    @State private var title = ""
    @State private var textContent = ""
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var showVoiceRecorder = false
    @State private var showHandwriting = false
    @State private var showAIAssist = false
    
    // 心情选择
    @State private var selectedMood: MoodPicker.Mood = .calm
    @State private var moodIntensity: Double = 0.5
    @State private var showMoodPicker = false
    
    // 照片选择
    @State private var selectedPhotos: [UIImage] = []
    
    // 语音录制结果
    @State private var voiceTranscription = ""
    @State private var voiceAudioURL: URL?
    
    // 保存状态
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 主编辑区域
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 心情选择按钮
                        moodSelectionButton
                        
                        // 心情选择器（展开时显示）
                        if showMoodPicker {
                            MoodPicker(selectedMood: $selectedMood, intensity: $moodIntensity)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // 标题
                        TextField("Title", text: $title)
                            .font(JournalFonts.title)
                            .foregroundStyle(JournalColors.inkBlack)
                        
                        // 正文
                        TextField("Start writing...", text: $textContent, axis: .vertical)
                            .font(JournalFonts.body)
                            .foregroundStyle(JournalColors.inkBlack)
                            .lineLimit(nil)
                        
                        // 照片预览
                        if !selectedPhotos.isEmpty || showPhotosPicker {
                            JournalPhotoGrid(selectedPhotos: $selectedPhotos)
                        }
                        
                        // 语音转写内容（如有）
                        if !voiceTranscription.isEmpty {
                            VoiceTranscriptionCard(text: voiceTranscription, audioURL: voiceAudioURL)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                .background(PaperTexture())
                
                // 底部多模态工具栏
                VStack {
                    Spacer()
                    MultiModalToolbar(
                        showVoiceRecorder: $showVoiceRecorder,
                        showPhotosPicker: $showPhotosPicker,
                        showCamera: $showCamera,
                        showHandwriting: $showHandwriting,
                        showAIAssist: $showAIAssist
                    )
                    .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(JournalColors.inkBlack)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if #available(iOS 26, *) {
                        GlassEffectContainer(spacing: 16) {
                            HStack(spacing: 16) {
                                Button {
                                    // 文字格式
                                } label: {
                                    Text("Aa")
                                        .font(.headline)
                                }
                                .glassEffect(.regular.interactive(), in: .circle)
                                
                                Button {
                                    // 更多选项
                                } label: {
                                    Image(systemName: "ellipsis")
                                }
                                .glassEffect(.regular.interactive(), in: .circle)
                            }
                        }
                    } else {
                        HStack(spacing: 16) {
                            Button("Aa") { }
                            Button {
                                // 更多选项
                            } label: {
                                Image(systemName: "ellipsis")
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveEntry()
                    } label: {
                        if #available(iOS 26, *) {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.purple, in: Circle())
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            // 语音录制Sheet
            .sheet(isPresented: $showVoiceRecorder) {
                VoiceRecorderView(
                    transcribedText: $voiceTranscription,
                    audioURL: $voiceAudioURL
                )
            }
            // AI对话Sheet
            .sheet(isPresented: $showAIAssist) {
                AIConversationView(initialContent: textContent.isEmpty ? "今天想聊聊..." : textContent)
            }
            // 保存Loading遮罩
            .overlay {
                if isSaving {
                    SavingOverlay()
                }
            }
        }
    }
    
    // MARK: - Mood Selection Button
    private var moodSelectionButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showMoodPicker.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedMood.rawValue)
                    .font(.title2)
                Text("今天心情")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                Image(systemName: showMoodPicker ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selectedMood.color.opacity(0.2), in: Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func saveEntry() {
        isSaving = true
        
        // 合并内容
        var fullContent = textContent
        
        // 添加心情标记
        fullContent = "[\(selectedMood.rawValue) \(selectedMood.label)] " + fullContent
        
        if !voiceTranscription.isEmpty {
            fullContent += "\n\n📝 语音记录:\n\(voiceTranscription)"
        }
        
        // 创建日记条目
        let entry = JournalEntry(title: title, textContent: fullContent)
        entry.moodEmoji = selectedMood.rawValue
        modelContext.insert(entry)
        
        // 异步处理 AI 提取和奖励
        Task {
            // 0. 记忆系统：生成 embedding + 提取事实 + 更新用户档案
            await MemoryManager.shared.processJournalEntry(entry, modelContext: modelContext)
            
            // 1. AI 提取日程和习惯
            await AIScheduleHabitService.shared.processJournalEntry(fullContent, entryId: entry.id)
            
            // 2. 喂养宠物 + 更新气泡
            await MainActor.run {
                PetStateManager.shared.feed(journalContent: fullContent)
            }
            
            // 3. 完成保存
            await MainActor.run {
                // 清空输入
                title = ""
                textContent = ""
                voiceTranscription = ""
                selectedPhotos = []
                selectedMood = .calm
                moodIntensity = 0.5
                showMoodPicker = false
                isSaving = false
                
                // 回调或dismiss
                if let onSaveComplete {
                    onSaveComplete()
                } else {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Voice Transcription Card
struct VoiceTranscriptionCard: View {
    let text: String
    let audioURL: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(JournalColors.lavender)
                Text("语音记录")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                Spacer()
                if audioURL != nil {
                    Image(systemName: "play.circle")
                        .foregroundStyle(JournalColors.inkBlack)
                }
            }
            
            Text(text)
                .font(JournalFonts.body)
                .foregroundStyle(JournalColors.inkBlack)
        }
        .padding()
        .scrapbookStyle()
        .withWashiTape(color: JournalColors.lavender)
    }
}

#Preview {
    JournalEditorView()
}

