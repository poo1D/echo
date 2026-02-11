import SwiftUI

/// 漂浮气泡组件
struct FloatingBubble: View {
    let type: BubbleType
    let text: String
    let icon: String
    let color: Color
    
    @State private var offsetY: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            
            Text(text)
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.inkBlack)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: 100) // 固定最大宽度
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            FloatingBubbleShape()
                .fill(JournalColors.warmWhite.opacity(0.9))
                .shadow(color: color.opacity(0.3), radius: 6, y: 3)
        )
        .offset(y: offsetY)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                offsetY = -8
            }
        }
    }
}

/// 漂浮气泡形状（带小尾巴）
struct FloatingBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 12
        
        // 主体圆角矩形
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height - 6),
            cornerSize: CGSize(width: radius, height: radius)
        )
        
        // 小尾巴
        let tailWidth: CGFloat = 10
        let tailCenter = rect.midX
        path.move(to: CGPoint(x: tailCenter - tailWidth/2, y: rect.height - 6))
        path.addLine(to: CGPoint(x: tailCenter, y: rect.height))
        path.addLine(to: CGPoint(x: tailCenter + tailWidth/2, y: rect.height - 6))
        
        return path
    }
}

/// 气泡详情Sheet
struct BubbleDetailSheet: View {
    let bubbleType: BubbleType
    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""
    
    // 使用共享的宠物状态
    private var petState: PetStateManager { PetStateManager.shared }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 标题图标
                bubbleIcon
                
                // 详细内容
                detailContent
                
                Spacer()
                
                // 回复输入
                replyInput
            }
            .padding()
            .background(PaperTexture())
            .navigationTitle(bubbleType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
    
    private var bubbleIcon: some View {
        ZStack {
            Circle()
                .fill(bubbleColor.opacity(0.2))
                .frame(width: 80, height: 80)
            
            Image(systemName: bubbleSystemImage)
                .font(.system(size: 32))
                .foregroundStyle(bubbleColor)
        }
    }
    
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch bubbleType {
            case .mood:
                Text("今日情绪分析")
                    .font(JournalFonts.headline)
                Text(petState.moodBubbleText)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.warmGray)
                    
            case .hug:
                Text("温暖时刻")
                    .font(JournalFonts.headline)
                Text(petState.hugBubbleText)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.warmGray)
                    
            case .schedule:
                Text("日程提醒")
                    .font(JournalFonts.headline)
                Text(petState.scheduleBubbleText)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.warmGray)
                    
            case .growth:
                Text("成长进度")
                    .font(JournalFonts.headline)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("当前等级:")
                        Text("Lv.\(petState.level)")
                            .bold()
                    }
                    HStack {
                        Text("能量进度:")
                        Text("\(Int(petState.energy))/\(Int(petState.maxEnergy))")
                            .bold()
                    }
                    Text(petState.growthBubbleText)
                        .foregroundStyle(JournalColors.lavender)
                }
                .font(JournalFonts.body)
                .foregroundStyle(JournalColors.warmGray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrapbookStyle()
    }
    
    private var replyInput: some View {
        HStack {
            TextField("回复Echo...", text: $replyText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(JournalColors.warmWhite, in: Capsule())
            
            Button {
                // 发送回复
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(replyText.isEmpty ? JournalColors.warmGray : JournalColors.lavender)
            }
            .disabled(replyText.isEmpty)
        }
    }
    
    private var bubbleColor: Color {
        switch bubbleType {
        case .mood: return JournalColors.softPink
        case .hug: return JournalColors.peach
        case .schedule: return JournalColors.mintGreen
        case .growth: return JournalColors.lavender
        }
    }
    
    private var bubbleSystemImage: String {
        switch bubbleType {
        case .mood: return "heart.fill"
        case .hug: return "hands.sparkles.fill"
        case .schedule: return "calendar"
        case .growth: return "sparkles"
        }
    }
}

#Preview {
    FloatingBubble(
        type: .mood,
        text: "有点疲惫呢",
        icon: "heart.fill",
        color: JournalColors.softPink
    )
}
