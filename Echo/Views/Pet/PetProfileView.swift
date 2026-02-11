import SwiftUI
import SwiftData

/// 宠物档案页面
struct PetProfileView: View {
    @State private var petState = PetStateManager.shared
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    
    @State private var showSkinShop = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 大头像卡片
                    profileHeader
                    
                    // 标签切换
                    tabSelector
                    
                    // 内容区域
                    switch selectedTab {
                    case 0:
                        growthTimeline
                    case 1:
                        personalityPanel
                    case 2:
                        statsPanel
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            .background(PaperTexture())
            .navigationTitle("Echo 档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSkinShop = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(JournalColors.lavender)
                    }
                }
            }
            .sheet(isPresented: $showSkinShop) {
                SkinShopView()
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // 大头像
            // 大头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [JournalColors.lavender.opacity(0.3), JournalColors.skyBlue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                
                // 使用统一的PetView
                PetView()
                    .scaleEffect(0.7)
            }
            
            // 名字和等级
            VStack(spacing: 4) {
                Text("Echo")
                    .font(JournalFonts.title)
                    .foregroundStyle(JournalColors.inkBlack)
                
                HStack(spacing: 8) {
                    Text("Lv.\(petState.level)")
                        .font(JournalFonts.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(JournalColors.lavender, in: Capsule())
                    
                    Text(growthStage)
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
            
            // 状态条
            HStack(spacing: 24) {
                statBar(icon: "bolt.fill", label: "能量", value: petState.energy, maxValue: petState.maxEnergy, color: JournalColors.peach)
                statBar(icon: "heart.fill", label: "好感", value: Double(petState.affection), maxValue: 100.0, color: JournalColors.softPink)
            }
        }
        .padding(24)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 24))
    }
    
    private var eyeView: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 36, height: 36)
            Circle()
                .fill(.black)
                .frame(width: 20, height: 20)
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .offset(x: -4, y: -4)
        }
    }
    
    private var growthStage: String {
        switch petState.level {
        case 1...3: return "🐣 幼年期"
        case 4...6: return "🐧 成长期"
        case 7...9: return "👑 成熟期"
        default: return "✨ 传说期"
        }
    }
    
    private func statBar(icon: String, label: String, value: Double, maxValue: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(JournalFonts.caption)
            }
            .foregroundStyle(color)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: Swift.max(0, geo.size.width * (value / maxValue)))
                }
            }
            .frame(height: 8)
            .frame(width: 80)
            
            Text("\(Int(value))/\(Int(maxValue))")
                .font(.system(size: 10))
                .foregroundStyle(JournalColors.warmGray)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(["成长树", "个性", "统计"], id: \.self) { tab in
                let index = ["成长树", "个性", "统计"].firstIndex(of: tab) ?? 0
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = index
                    }
                } label: {
                    Text(tab)
                        .font(JournalFonts.caption)
                        .foregroundStyle(selectedTab == index ? .white : JournalColors.warmGray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(selectedTab == index ? JournalColors.inkBlack : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(JournalColors.warmWhite, in: Capsule())
    }
    
    // MARK: - Growth Timeline
    private var growthTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("成长历程")
                .font(JournalFonts.headline)
                .foregroundStyle(JournalColors.inkBlack)
                .padding(.bottom, 16)
            
            ForEach(milestones.indices, id: \.self) { index in
                milestoneRow(milestones[index], isLast: index == milestones.count - 1, isPast: index < petState.level)
            }
        }
        .padding()
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var milestones: [(level: Int, title: String, icon: String)] {
        [
            (1, "初次相遇", "egg"),
            (2, "第一次对话", "bubble.left"),
            (3, "记住了你的名字", "person"),
            (5, "学会了安慰", "heart"),
            (7, "理解你的心情", "brain"),
            (10, "成为最好的朋友", "star.fill")
        ]
    }
    
    private func milestoneRow(_ milestone: (level: Int, title: String, icon: String), isLast: Bool, isPast: Bool) -> some View {
        HStack(spacing: 16) {
            // 时间线
            VStack(spacing: 0) {
                Circle()
                    .fill(isPast ? JournalColors.lavender : JournalColors.warmGray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: milestone.icon)
                            .font(.caption2)
                            .foregroundStyle(isPast ? .white : JournalColors.warmGray)
                    }
                
                if !isLast {
                    Rectangle()
                        .fill(isPast ? JournalColors.lavender : JournalColors.warmGray.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text("Lv.\(milestone.level)")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                Text(milestone.title)
                    .font(JournalFonts.body)
                    .foregroundStyle(isPast ? JournalColors.inkBlack : JournalColors.warmGray)
            }
            
            Spacer()
            
            if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(JournalColors.mintGreen)
            }
        }
    }
    
    // MARK: - Personality Panel
    private var personalityPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Echo的个性")
                .font(JournalFonts.headline)
                .foregroundStyle(JournalColors.inkBlack)
            
            // AI总结的个性特征
            VStack(alignment: .leading, spacing: 12) {
                personalityTrait(icon: "heart.fill", title: "温暖陪伴", description: "总是在你需要的时候出现")
                personalityTrait(icon: "lightbulb.fill", title: "善于倾听", description: "认真记住你分享的每一件事")
                personalityTrait(icon: "star.fill", title: "积极鼓励", description: "相信你能做得更好")
            }
            
            Divider()
            
            // 从日记中总结的用户偏好
            if !entries.isEmpty {
                Text("Ta了解到...")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                
                FlowLayout(spacing: 8) {
                    insightChip("喜欢早起")
                    insightChip("注重健康")
                    insightChip("热爱学习")
                    insightChip("工作认真")
                }
            }
        }
        .padding()
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func personalityTrait(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(JournalColors.lavender)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
                Text(description)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
        }
    }
    
    private func insightChip(_ text: String) -> some View {
        Text(text)
            .font(JournalFonts.caption)
            .foregroundStyle(JournalColors.lavender)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(JournalColors.lavender.opacity(0.1), in: Capsule())
    }
    
    // MARK: - Stats Panel
    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("互动统计")
                .font(JournalFonts.headline)
                .foregroundStyle(JournalColors.inkBlack)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statCard(icon: "book.fill", value: "\(entries.count)", label: "日记总数", color: JournalColors.lavender)
                statCard(icon: "calendar", value: "\(daysSinceFirst)", label: "陪伴天数", color: JournalColors.mintGreen)
                statCard(icon: "bubble.left.fill", value: "\(petState.level * 10)", label: "对话次数", color: JournalColors.skyBlue)
                statCard(icon: "heart.fill", value: "\(Int(petState.affection))%", label: "好感度", color: JournalColors.softPink)
            }
        }
        .padding()
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var daysSinceFirst: Int {
        guard let firstEntry = entries.last else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: firstEntry.createdAt, to: Date()).day ?? 0
        return max(1, days)
    }
    
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(JournalFonts.title)
                .foregroundStyle(JournalColors.inkBlack)
            Text(label)
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }
            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Skin Shop
struct SkinShopView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var petState = PetStateManager.shared
    
    private let skins: [(name: String, cost: Int, icon: String, color: Color)] = [
        ("默认皮肤", 0, "circle.fill", .gray),
        ("粉色围巾", 50, "scarf", JournalColors.softPink),
        ("小皇冠", 100, "crown.fill", Color.yellow),
        ("彩虹翅膀", 200, "sparkles", .purple),
        ("圣诞帽", 150, "gift.fill", .red),
        ("墨镜酷仔", 80, "sunglasses.fill", .black)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 好感余额
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(JournalColors.softPink)
                        Text("好感余额: \(Int(petState.affection))")
                            .font(JournalFonts.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 12))
                    
                    // 皮肤列表
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(skins.indices, id: \.self) { index in
                            skinCard(skins[index])
                        }
                    }
                }
                .padding()
            }
            .background(PaperTexture())
            .navigationTitle("外观商店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func skinCard(_ skin: (name: String, cost: Int, icon: String, color: Color)) -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(skin.color.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: skin.icon)
                        .font(.title2)
                        .foregroundStyle(skin.color)
                }
            
            Text(skin.name)
                .font(JournalFonts.body)
                .foregroundStyle(JournalColors.inkBlack)
            
            if skin.cost == 0 {
                Text("已拥有")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.mintGreen)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                    Text("\(skin.cost)")
                }
                .font(JournalFonts.caption)
                .foregroundStyle(Int(petState.affection) >= skin.cost ? JournalColors.lavender : JournalColors.warmGray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    PetProfileView()
}
