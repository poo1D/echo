import SwiftUI
import SwiftData

/// 单页手帐内容
struct ScrapbookPageView: View {
    let entry: JournalEntry
    let pageNumber: Int
    let totalPages: Int
    
    @State private var showFullContent = false
    
    // 格式化日期
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: entry.createdAt)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: entry.createdAt)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部日期标签 - 复古撕页风格
                dateHeader
                    .padding(.top, 20)
                
                // 手帐内容区
                VStack(spacing: 16) {
                    // 用户日记卡片
                    userDiaryCard
                    
                    // Echo回应卡片
                    EchoResponseCard(entry: entry)
                    
                    // 成长里程碑卡片（如果有）
                    if shouldShowMilestone {
                        GrowthMilestoneCard(entry: entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // 为底部页码留空间
            }
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - 日期标签
    private var dateHeader: some View {
        VStack(spacing: 4) {
            // 撕页效果边缘
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { _ in
                    Circle()
                        .fill(Color(red: 0.95, green: 0.92, blue: 0.88))
                        .frame(width: 8, height: 8)
                }
            }
            
            VStack(spacing: 8) {
                Text(formattedDate)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(JournalColors.inkBlack)
                
                Text(weekdayString)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(JournalColors.warmWhite)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .overlay(alignment: .topTrailing) {
                // 胶带装饰
                RoundedRectangle(cornerRadius: 2)
                    .fill(JournalColors.peach.opacity(0.6))
                    .frame(width: 40, height: 12)
                    .rotationEffect(.degrees(15))
                    .offset(x: 10, y: -6)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - 用户日记卡片
    private var userDiaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundStyle(JournalColors.lavender)
                
                Text(entry.title.isEmpty ? "今日记录" : entry.title)
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                
                Spacer()
                
                // 心情标识
                if let mood = entry.moodEmoji {
                    Text(mood)
                        .font(.title2)
                }
            }
            
            // 内容
            Text(entry.textContent)
                .font(JournalFonts.body)
                .foregroundStyle(JournalColors.inkBlack.opacity(0.8))
                .lineLimit(showFullContent ? nil : 6)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showFullContent.toggle()
                    }
                }
            
            // 照片网格
            if !entry.photos.isEmpty {
                photoGrid
            }
            
            // 标签
            if !entry.tags.isEmpty {
                tagFlow
            }
            
            // 位置和天气
            if entry.locationName != nil || entry.weatherEmoji != nil {
                metadataRow
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(JournalColors.warmWhite)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        }
        .overlay(alignment: .topLeading) {
            // 左上角胶带
            RoundedRectangle(cornerRadius: 2)
                .fill(JournalColors.mintGreen.opacity(0.5))
                .frame(width: 30, height: 10)
                .rotationEffect(.degrees(-25))
                .offset(x: -8, y: -5)
        }
    }
    
    // MARK: - 照片网格
    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(entry.photos.prefix(4)) { photo in
                if let image = loadImage(from: photo.localPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 标签流
    private var tagFlow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entry.tags) { tag in
                    Text("#\(tag.name)")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.lavender)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(JournalColors.lavender.opacity(0.15), in: Capsule())
                }
            }
        }
    }
    
    // MARK: - 元数据行
    private var metadataRow: some View {
        HStack(spacing: 12) {
            if let location = entry.locationName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption)
                    Text(location)
                        .font(JournalFonts.caption)
                }
                .foregroundStyle(JournalColors.warmGray)
            }
            
            if let weather = entry.weatherEmoji {
                Text(weather)
                    .font(.caption)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 是否显示里程碑
    private var shouldShowMilestone: Bool {
        // 简单判断：每10篇日记显示一个里程碑
        pageNumber % 10 == 0 || pageNumber == 1
    }
    
    // MARK: - 加载图片
    private func loadImage(from path: String) -> UIImage? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Echo回应卡片
struct EchoResponseCard: View {
    let entry: JournalEntry
    
    private var echoResponse: String {
        // 优先使用AI洞察，否则使用预设回应
        if let insight = entry.aiInsight {
            return insight.summary
        }
        return generateDefaultResponse()
    }
    
    private func generateDefaultResponse() -> String {
        let responses: [String] = [
            "今天的分享让我更懂你了~",
            "谢谢你愿意和我分享这些心情！",
            "我会一直陪着你，无论开心还是难过。",
            "记录下这一刻的你，真的很棒！",
            "每一天的你都在成长，我看在眼里~"
        ]
        
        // 根据心情调整回应
        if let mood = entry.moodEmoji {
            switch mood {
            case "😊", "🥰", "😄":
                return "看到你开心我也好开心！保持这份好心情噢~"
            case "😢", "😔", "😭":
                return "抱抱你~有我在，一切都会好起来的。"
            case "😤", "😡":
                return "深呼吸，我陪你一起慢慢梳理~"
            case "😴", "🥱":
                return "辛苦了，好好休息，明天会更好！"
            default:
                return responses.randomElement() ?? responses[0]
            }
        }
        
        return responses.randomElement() ?? responses[0]
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Echo头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [JournalColors.lavender.opacity(0.3), JournalColors.mintGreen.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Text("🐧")
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Echo的回应")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    
                    Spacer()
                    
                    // 亲密度心心
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < 2 ? "heart.fill" : "heart")
                                .font(.caption2)
                                .foregroundStyle(JournalColors.peach)
                        }
                    }
                }
                
                Text(echoResponse)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                
                // AI分析标签
                if let insight = entry.aiInsight, !insight.moodTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(insight.moodTags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11))
                                    .foregroundStyle(JournalColors.lavender)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(JournalColors.lavender.opacity(0.1), in: Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            JournalColors.lavender.opacity(0.08),
                            JournalColors.mintGreen.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(JournalColors.lavender.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - 成长里程碑卡片
struct GrowthMilestoneCard: View {
    let entry: JournalEntry
    @State private var petState = PetStateManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部装饰
            HStack {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(JournalColors.peach.opacity(0.6))
                }
            }
            
            HStack(spacing: 16) {
                // 成长图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [JournalColors.peach, JournalColors.lavender],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("🌱 成长记录")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    
                    Text("Echo Lv.\(petState.level)")
                        .font(JournalFonts.headline)
                        .foregroundStyle(JournalColors.inkBlack)
                    
                    // 能量进度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(JournalColors.warmGray.opacity(0.2))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [JournalColors.mintGreen, JournalColors.lavender],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * (petState.energy / petState.maxEnergy), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                
                Spacer()
                
                // 亲密度
                VStack(spacing: 2) {
                    Text("💕")
                        .font(.title2)
                    Text("亲密Lv.\(petState.affection)")
                        .font(.system(size: 10))
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
            
            // 里程碑信息
            Text("继续记录，Echo会陪你一起成长！")
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(JournalColors.warmWhite)
                .shadow(color: JournalColors.peach.opacity(0.1), radius: 8, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [JournalColors.peach.opacity(0.3), JournalColors.lavender.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

#Preview {
    let entry = JournalEntry(title: "美好的一天", textContent: "今天阳光明媚，心情特别好！和朋友一起去公园散步，感受到了春天的气息。晚上回家后写了这篇日记，记录下这美好的一天。")
    entry.moodEmoji = "😊"
    
    return ScrapbookPageView(entry: entry, pageNumber: 1, totalPages: 10)
        .modelContainer(for: JournalEntry.self)
}
