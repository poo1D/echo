import SwiftUI

/// 语音录制视图 - Liquid Glass 风格
struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var speechService = SpeechRecognitionService()
    @Binding var transcribedText: String
    @Binding var audioURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // 转写文本显示区
                transcriptionArea
                
                Spacer()
                
                // 录音按钮
                recordButton
                
                // 提示文字
                Text(speechService.isRecording ? "点击停止录音" : "点击开始录音")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                
                Spacer()
            }
            .padding()
            .background(PaperTexture())
            .navigationTitle("语音录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        speechService.stopRecording()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        completeRecording()
                    }
                    .disabled(speechService.transcribedText.isEmpty)
                }
            }
            .task {
                await speechService.requestAuthorization()
            }
            .alert("错误", isPresented: .constant(speechService.errorMessage != nil)) {
                Button("确定") {
                    speechService.errorMessage = nil
                }
            } message: {
                Text(speechService.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Transcription Area
    private var transcriptionArea: some View {
        ScrollView {
            Text(speechService.transcribedText.isEmpty ? "开始说话..." : speechService.transcribedText)
                .font(JournalFonts.body)
                .foregroundStyle(speechService.transcribedText.isEmpty ? JournalColors.warmGray : JournalColors.inkBlack)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(maxHeight: 300)
        .scrapbookStyle()
    }
    
    // MARK: - Record Button
    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            ZStack {
                // 外圈动画
                if speechService.isRecording {
                    Circle()
                        .stroke(JournalColors.softPink, lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(speechService.isRecording ? 1.2 : 1.0)
                        .opacity(speechService.isRecording ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: speechService.isRecording)
                }
                
                // 主按钮
                if #available(iOS 26, *) {
                    recordButtonContent
                        .glassEffect(
                            speechService.isRecording ? .regular.tint(Color.red) : .regular,
                            in: .circle
                        )
                } else {
                    recordButtonContent
                        .background(
                            speechService.isRecording ? Color.red.opacity(0.8) : Color(.systemBackground).opacity(0.8),
                            in: Circle()
                        )
                        .overlay {
                            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        }
                }
            }
        }
        .sensoryFeedback(.impact, trigger: speechService.isRecording)
    }
    
    private var recordButtonContent: some View {
        ZStack {
            if speechService.isRecording {
                // 停止图标
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white)
                    .frame(width: 24, height: 24)
            } else {
                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(JournalColors.inkBlack)
            }
        }
        .frame(width: 80, height: 80)
    }
    
    // MARK: - Actions
    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                try? await speechService.startRecording()
            }
        }
    }
    
    private func completeRecording() {
        speechService.stopRecording()
        transcribedText = speechService.transcribedText
        audioURL = speechService.currentRecordingURL
        dismiss()
    }
}

#Preview {
    VoiceRecorderView(
        transcribedText: .constant(""),
        audioURL: .constant(nil)
    )
}
