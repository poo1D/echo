import SwiftUI

/// AI对话视图 - 动态气泡 + 情绪色彩
struct AIConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var conversationService = AIConversationService()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    let initialContent: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 对话消息列表
                messageList
                
                // 输入区域
                inputArea
            }
            .background(PaperTexture())
            .navigationTitle("AI 情绪伴侣")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(JournalColors.warmGray)
                    }
                }
            }
            .task {
                // 开始对话
                await conversationService.startConversation(with: initialContent)
            }
        }
    }
    
    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(conversationService.messages) { message in
                        MessageBubble(message: message, isStreaming: conversationService.isStreaming && message.id == conversationService.messages.last?.id)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: conversationService.messages.count) { _, _ in
                if let lastMessage = conversationService.messages.last {
                    withAnimation(.spring) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Area
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("说点什么...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(JournalColors.warmWhite, in: Capsule())
                .focused($isInputFocused)
            
            // 发送按钮
            Button {
                sendMessage()
            } label: {
                if #available(iOS 26, *) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(inputText.isEmpty ? JournalColors.warmGray : .purple)
                        .glassEffect(.regular.interactive(), in: .circle)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(inputText.isEmpty ? JournalColors.warmGray : .purple)
                }
            }
            .disabled(inputText.isEmpty || conversationService.isStreaming)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func sendMessage() {
        let message = inputText
        inputText = ""
        Task {
            await conversationService.sendMessage(message)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: AIConversationService.ConversationMessage
    let isStreaming: Bool
    
    private var bubbleColor: Color {
        if message.role == .user {
            return JournalColors.lavender.opacity(0.6)
        }
        
        switch message.moodColor {
        case .positive:
            return JournalColors.mintGreen.opacity(0.6)
        case .needsCare:
            return JournalColors.peach.opacity(0.6)
        case .neutral, .none:
            return JournalColors.softPink.opacity(0.6)
        }
    }
    
    private var alignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            
            VStack(alignment: alignment, spacing: 4) {
                // 角色图标
                HStack(spacing: 6) {
                    if message.role == .assistant {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(JournalColors.lavender)
                    }
                    Text(message.role == .user ? "You" : "Echo")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
                
                // 消息内容
                HStack {
                    Text(message.content)
                        .font(JournalFonts.body)
                        .foregroundStyle(JournalColors.inkBlack)
                    
                    // 流式输出光标
                    if isStreaming && message.role == .assistant {
                        Rectangle()
                            .fill(JournalColors.inkBlack)
                            .frame(width: 2, height: 16)
                            .opacity(isStreaming ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: isStreaming)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleColor, in: BubbleShape(isFromUser: message.role == .user))
            }
            
            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Bubble Shape
struct BubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        var path = Path()
        
        if isFromUser {
            // 右下角有小尾巴
            path.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width - 8, height: rect.height), cornerSize: CGSize(width: radius, height: radius))
            path.move(to: CGPoint(x: rect.width - 8, y: rect.height - 20))
            path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height), control: CGPoint(x: rect.width - 8, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width - 16, y: rect.height))
        } else {
            // 左下角有小尾巴
            path.addRoundedRect(in: CGRect(x: 8, y: 0, width: rect.width - 8, height: rect.height), cornerSize: CGSize(width: radius, height: radius))
            path.move(to: CGPoint(x: 8, y: rect.height - 20))
            path.addQuadCurve(to: CGPoint(x: 0, y: rect.height), control: CGPoint(x: 8, y: rect.height))
            path.addLine(to: CGPoint(x: 16, y: rect.height))
        }
        
        return path
    }
}

#Preview {
    AIConversationView(initialContent: "今天工作有点累，但是完成了一个重要的项目。")
}
