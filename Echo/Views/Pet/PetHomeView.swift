import SwiftUI

/// 宠物主页 - 替换原Ideas页
struct PetHomeView: View {
    @State private var selectedBubble: BubbleType?
    @State private var showVoiceChat = false
    @State private var showProfile = false
    
    // 使用共享状态管理器
    private var petState: PetStateManager { PetStateManager.shared }
    
    var body: some View {
        ZStack {
            // 背景
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 20)
                    
                    // 宠物 + 漂浮气泡卡片
                    petCard
                    
                    // 底部状态卡片
                    statusCard
                    
                    // 日程和习惯堆叠卡片
                    StackedCardsView()
                    
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal)
            }
            
            // 喂养成功动画
            if petState.showFeedingSuccess {
                feedingSuccessOverlay
            }
        }
        .sheet(item: $selectedBubble) { bubble in
            BubbleDetailSheet(bubbleType: bubble)
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showVoiceChat) {
            AdventureView()
        }
    }
    
    // MARK: - Pet Card
    private var petCard: some View {
        VStack(spacing: 0) {
            // 宠物 + 漂浮气泡区域
            ZStack {
                floatingBubbles
                
                PetView()
                    .onTapGesture {
                        showVoiceChat = true
                    }
            }
            .frame(height: 300)
            
            // 点击提示
            Text("点击Echo开始对话 💬")
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                JournalColors.skyBlue.opacity(0.3),
                JournalColors.cream
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Floating Bubbles
    private var floatingBubbles: some View {
        ZStack {
            // 情绪气泡 - 左上
            FloatingBubble(
                type: .mood,
                text: petState.moodBubbleText,
                icon: "heart.fill",
                color: JournalColors.softPink
            )
            .offset(x: -80, y: -80)
            .onTapGesture { selectedBubble = .mood }
            
            // 抱抱气泡 - 右上
            FloatingBubble(
                type: .hug,
                text: petState.hugBubbleText,
                icon: "hands.sparkles.fill",
                color: JournalColors.peach
            )
            .offset(x: 80, y: -80)
            .onTapGesture { selectedBubble = .hug }
            
            // 日程气泡 - 左下
            FloatingBubble(
                type: .schedule,
                text: petState.scheduleBubbleText,
                icon: "calendar",
                color: JournalColors.mintGreen
            )
            .offset(x: -80, y: 60)
            .onTapGesture { selectedBubble = .schedule }
            
            // 成长气泡 - 右下
            FloatingBubble(
                type: .growth,
                text: petState.growthBubbleText,
                icon: "sparkles",
                color: JournalColors.lavender
            )
            .offset(x: 80, y: 60)
            .onTapGesture { selectedBubble = .growth }
        }
    }
    
    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("Echo 状态")
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                Spacer()
                Text("Lv.\(petState.level)")
                    .font(JournalFonts.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(JournalColors.lavender, in: Capsule())
            }
            
            Divider()
            
            // 能量条
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(JournalColors.peach)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("能量")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(JournalColors.warmGray.opacity(0.2))
                            Capsule()
                                .fill(JournalColors.peach)
                                .frame(width: geo.size.width * (petState.energy / petState.maxEnergy))
                                .animation(.spring, value: petState.energy)
                        }
                    }
                    .frame(height: 8)
                }
                
                Text("\(Int(petState.energy))/\(Int(petState.maxEnergy))")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.inkBlack)
                    .frame(width: 50, alignment: .trailing)
            }
            
            // 好感度
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(JournalColors.softPink)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("好感度")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    
                    HStack(spacing: 6) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < petState.affection ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundStyle(i < petState.affection ? JournalColors.softPink : JournalColors.warmGray.opacity(0.3))
                        }
                        Spacer()
                    }
                }
                
                Text("\(petState.affection)/5")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.inkBlack)
                    .frame(width: 50, alignment: .trailing)
            }
            
            Divider()
            
            // 查看档案入口
            Button {
                showProfile = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(JournalColors.lavender)
                    Text("查看 Echo 档案")
                        .font(JournalFonts.body)
                        .foregroundStyle(JournalColors.inkBlack)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
        }
        .padding(20)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .sheet(isPresented: $showProfile) {
            PetProfileView()
        }
    }
    
    // MARK: - Status Bar (removed, replaced by statusCard)
    private var statusBar: some View {
        EmptyView()
    }
    
    // MARK: - Feeding Success Overlay
    private var feedingSuccessOverlay: some View {
        VStack {
            Spacer()
            
            Text(petState.feedingMessage)
                .font(JournalFonts.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(JournalColors.mintGreen, in: Capsule())
                .shadow(radius: 10)
                .transition(.scale.combined(with: .opacity))
            
            Spacer()
                .frame(height: 200)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: petState.showFeedingSuccess)
    }
}

// MARK: - Bubble Type
enum BubbleType: String, Identifiable {
    case mood = "情绪"
    case hug = "抱抱"
    case schedule = "日程"
    case growth = "成长"
    
    var id: String { rawValue }
}

#Preview {
    PetHomeView()
}
