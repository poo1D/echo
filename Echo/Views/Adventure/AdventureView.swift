import SwiftUI

/// 探索冒险主视图 - Finch风格
struct AdventureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentEvent: AdventureEvent = .walking
    @State private var showReward = false
    @State private var selectedChoice: Int?
    @State private var discoveredItem: DiscoverableItem = .cherry
    
    // 动画状态
    @State private var echoOffset: CGFloat = 0
    @State private var itemGlow = false
    @State private var questionBounce = false
    
    var body: some View {
        ZStack {
            // 沉浸式森林背景
            ForestSceneBackground()
            
            VStack(spacing: 0) {
                // 顶部导航
                topNavigation
                
                Spacer()
                
                // Echo对话框
                echoDialogBox
                
                Spacer()
                
                // 发现物品 + Echo
                discoveryArea
                
                Spacer()
                
                // 选项按钮
                if currentEvent == .choosing {
                    choiceButtons
                }
                
                Spacer().frame(height: 50)
            }
            
            // 奖励展示
            if showReward {
                rewardOverlay
            }
        }
        .onAppear {
            startAdventure()
        }
    }
    
    // MARK: - Top Navigation
    private var topNavigation: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.2), in: Circle())
            }
            
            Spacer()
            
            // 天气/时间
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.yellow)
                Text("晴朗")
                    .font(JournalFonts.caption)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.2), in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // MARK: - Echo Dialog Box
    private var echoDialogBox: some View {
        VStack(spacing: 0) {
            Text(currentEvent.dialogText(for: discoveredItem))
                .font(JournalFonts.body)
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.15))
                .multilineTextAlignment(.center)
                .padding(20)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            
            // 小三角
            Triangle()
                .fill(.white)
                .frame(width: 20, height: 12)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Discovery Area
    private var discoveryArea: some View {
        ZStack {
            // 发现的物品（带光芒）
            if currentEvent != .walking {
                ZStack {
                    // 光芒特效
                    if itemGlow {
                        RadialGlowEffect(color: .yellow)
                            .opacity(0.8)
                    }
                    
                    // 物品
                    Text(discoveredItem.emoji)
                        .font(.system(size: 60))
                }
                .offset(y: -80)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Echo + 疑问气泡
            VStack(spacing: 0) {
                // 疑问气泡
                if currentEvent == .discovering {
                    Text("?")
                        .font(JournalFonts.headline)
                        .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.15))
                        .offset(y: questionBounce ? -5 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: questionBounce)
                }
                
                // Echo企鹅（使用主页统一形象）
                PetView()
                    .scaleEffect(0.8)
                    .offset(y: echoOffset)
            }
        }
    }
    
    // MARK: - Choice Buttons
    private var choiceButtons: some View {
        VStack(spacing: 12) {
            ForEach(discoveredItem.choices.indices, id: \.self) { index in
                Button {
                    selectChoice(index)
                } label: {
                    Text(discoveredItem.choices[index])
                        .font(JournalFonts.body)
                        .foregroundStyle(Color(red: 0.7, green: 0.2, blue: 0.2))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
            }
            
            // 自由输入
            Button {
                // 自由输入逻辑
            } label: {
                Text("写下你自己的回应...")
                    .font(JournalFonts.caption)
                    .foregroundStyle(Color(red: 0.3, green: 0.25, blue: 0.2))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Reward Overlay
    private var rewardOverlay: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 光芒
                RadialGlowEffect(color: .yellow)
                
                // 物品
                Text(discoveredItem.emoji)
                    .font(.system(size: 80))
                
                // 发现文字
                VStack(spacing: 8) {
                    Text("Echo 发现了")
                        .font(JournalFonts.headline)
                        .foregroundStyle(.white)
                    Text(discoveredItem.name)
                        .font(JournalFonts.title)
                        .foregroundStyle(.white)
                }
                
                // 奖励
                HStack(spacing: 16) {
                    rewardBadge(icon: "bolt.fill", value: "+\(discoveredItem.energyReward)", color: JournalColors.peach)
                    rewardBadge(icon: "heart.fill", value: "+\(discoveredItem.affectionReward)", color: JournalColors.softPink)
                }
                .padding(.top, 20)
                
                // 继续按钮
                Button {
                    applyRewardAndDismiss()
                } label: {
                    Text("太棒了！")
                        .font(JournalFonts.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(JournalColors.mintGreen, in: Capsule())
                }
                .padding(.top, 20)
            }
        }
        .transition(.opacity)
    }
    
    private func rewardBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(value)
                .font(JournalFonts.headline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color, in: Capsule())
    }
    
    // MARK: - Logic
    private func startAdventure() {
        // 开始探索动画
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            echoOffset = -5
        }
        
        // 2秒后发现物品
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5)) {
                currentEvent = .discovering
                itemGlow = true
                questionBounce = true
            }
            
            // 再过1秒显示选项
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.spring(response: 0.5)) {
                    currentEvent = .choosing
                }
            }
        }
    }
    
    private func selectChoice(_ index: Int) {
        selectedChoice = index
        
        withAnimation(.spring(response: 0.5)) {
            currentEvent = .reward
            showReward = true
        }
    }
    
    private func applyRewardAndDismiss() {
        // 应用奖励
        PetStateManager.shared.energy += Double(discoveredItem.energyReward)
        PetStateManager.shared.affection += discoveredItem.affectionReward
        
        dismiss()
    }
}

// MARK: - Adventure Event
enum AdventureEvent {
    case walking
    case discovering
    case choosing
    case reward
    
    func dialogText(for item: DiscoverableItem) -> String {
        switch self {
        case .walking:
            return "让我四处看看..."
        case .discovering:
            return "嘿嘿，看我发现了什么！\n这里有\(item.description)！"
        case .choosing:
            return "嘿嘿，看我发现了什么！\n这里有\(item.description)！"
        case .reward:
            return ""
        }
    }
}

// MARK: - Discoverable Items
enum DiscoverableItem: CaseIterable {
    case cherry
    case pinecone
    case flower
    case mushroom
    case leaf
    
    var emoji: String {
        switch self {
        case .cherry: return "🍒"
        case .pinecone: return "🌰"
        case .flower: return "🌸"
        case .mushroom: return "🍄"
        case .leaf: return "🍃"
        }
    }
    
    var name: String {
        switch self {
        case .cherry: return "樱桃"
        case .pinecone: return "松果"
        case .flower: return "小花"
        case .mushroom: return "蘑菇"
        case .leaf: return "落叶"
        }
    }
    
    var description: String {
        switch self {
        case .cherry: return "一颗红彤彤的樱桃"
        case .pinecone: return "一个可爱的松果"
        case .flower: return "一朵漂亮的小花"
        case .mushroom: return "一个神秘的蘑菇"
        case .leaf: return "一片金黄的落叶"
        }
    }
    
    var choices: [String] {
        switch self {
        case .cherry:
            return ["吃掉它！好甜呀~", "存起来以后慢慢吃"]
        case .pinecone:
            return ["带回家当装饰", "送给松鼠朋友"]
        case .flower:
            return ["戴在头上美美的", "闻一闻花香"]
        case .mushroom:
            return ["小心收好研究一下", "拍张照片留念"]
        case .leaf:
            return ["做成书签", "让它随风飘走"]
        }
    }
    
    var energyReward: Int {
        switch self {
        case .cherry: return 3
        case .pinecone: return 2
        case .flower: return 2
        case .mushroom: return 4
        case .leaf: return 1
        }
    }
    
    var affectionReward: Int {
        switch self {
        case .cherry: return 1
        case .pinecone: return 1
        case .flower: return 2
        case .mushroom: return 1
        case .leaf: return 1
        }
    }
}

// MARK: - Adventure Echo View
struct AdventureEchoView: View {
    var body: some View {
        ZStack {
            // 身体
            Ellipse()
                .fill(Color(red: 0.85, green: 0.85, blue: 0.9))
                .frame(width: 80, height: 90)
            
            // 肚子
            Ellipse()
                .fill(.white)
                .frame(width: 55, height: 60)
                .offset(y: 5)
            
            // 眼睛
            HStack(spacing: 20) {
                eyeView
                eyeView
            }
            .offset(y: -15)
            
            // 嘴巴
            Ellipse()
                .fill(Color.orange)
                .frame(width: 16, height: 8)
                .offset(y: 5)
            
            // 翅膀
            wingView
                .offset(x: -45, y: 0)
            wingView
                .scaleEffect(x: -1)
                .offset(x: 45, y: 0)
        }
    }
    
    private var eyeView: some View {
        ZStack {
            Circle()
                .fill(.black)
                .frame(width: 12, height: 12)
            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .offset(x: -2, y: -2)
        }
    }
    
    private var wingView: some View {
        Ellipse()
            .fill(Color(red: 0.75, green: 0.75, blue: 0.82))
            .frame(width: 25, height: 40)
            .rotationEffect(.degrees(-15))
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

#Preview {
    AdventureView()
}
