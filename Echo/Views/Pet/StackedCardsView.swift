import SwiftUI

/// 堆叠卡片视图 - 日程和习惯卡片可滑动展开
struct StackedCardsView: View {
    @State private var aiService = AIScheduleHabitService.shared
    @State private var expandedCard: CardType?
    
    enum CardType: String, CaseIterable, Identifiable {
        case schedule = "日程提醒"
        case habit = "习惯反馈"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .schedule: return "calendar.badge.clock"
            case .habit: return "leaf.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .schedule: return JournalColors.mintGreen
            case .habit: return JournalColors.peach
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Text("Echo 的发现")
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                
                Spacer()
                
                if aiService.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("分析中...")
                            .font(JournalFonts.caption)
                            .foregroundStyle(JournalColors.lavender)
                    }
                } else if !hasData {
                    Text("写日记后自动生成")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
            
            // 卡片堆叠
            if hasData {
                ZStack {
                    if expandedCard == nil {
                        collapsedCards
                    } else {
                        expandedCardView
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expandedCard)
            } else {
                emptyStateView
            }
        }
        .padding(16)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private var hasData: Bool {
        !aiService.extractedSchedules.isEmpty || !aiService.extractedHabits.isEmpty
    }
    
    // MARK: - 收起状态卡片
    private var collapsedCards: some View {
        VStack(spacing: 0) {
            ForEach(Array(CardType.allCases.enumerated()), id: \.element.id) { index, cardType in
                CardPreview(
                    type: cardType,
                    count: cardType == .schedule ? aiService.extractedSchedules.count : aiService.extractedHabits.count,
                    latestText: getLatestText(for: cardType)
                )
                .offset(y: CGFloat(index) * -8)
                .zIndex(Double(CardType.allCases.count - index))
                .onTapGesture {
                    withAnimation {
                        expandedCard = cardType
                    }
                }
            }
        }
    }
    
    // MARK: - 展开状态视图
    @ViewBuilder
    private var expandedCardView: some View {
        VStack(spacing: 12) {
            // 关闭按钮
            HStack {
                Label(expandedCard?.rawValue ?? "", systemImage: expandedCard?.icon ?? "")
                    .font(JournalFonts.body)
                    .foregroundStyle(expandedCard?.color ?? .gray)
                
                Spacer()
                
                Button {
                    withAnimation {
                        expandedCard = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
            
            Divider()
            
            // 内容列表
            ScrollView {
                VStack(spacing: 10) {
                    if expandedCard == .schedule {
                        schedulesList
                    } else {
                        habitsList
                    }
                }
            }
            .frame(maxHeight: 250)
        }
    }
    
    // MARK: - 日程列表
    private var schedulesList: some View {
        Group {
            if aiService.extractedSchedules.isEmpty {
                emptyStateView(message: "暂无日程提醒")
            } else {
                ForEach(aiService.extractedSchedules) { schedule in
                    ScheduleCardItem(schedule: schedule)
                }
            }
        }
    }
    
    // MARK: - 习惯列表
    private var habitsList: some View {
        Group {
            if aiService.extractedHabits.isEmpty {
                emptyStateView(message: "暂无习惯记录")
            } else {
                ForEach(aiService.extractedHabits) { habit in
                    HabitCardItem(habit: habit)
                }
            }
        }
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(JournalColors.lavender.opacity(0.6))
            
            Text("写一篇日记\nEcho 会自动发现日程和习惯")
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(JournalColors.warmGray.opacity(0.5))
            Text(message)
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    // MARK: - 获取最新文本
    private func getLatestText(for type: CardType) -> String {
        switch type {
        case .schedule:
            return aiService.extractedSchedules.first?.reminder ?? "暂无日程提醒"
        case .habit:
            return aiService.extractedHabits.first?.feedback ?? "开始记录习惯吧"
        }
    }
}

// MARK: - 卡片预览
struct CardPreview: View {
    let type: StackedCardsView.CardType
    let count: Int
    let latestText: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: type.icon)
                    .font(.body)
                    .foregroundStyle(type.color)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(type.rawValue)
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(type.color, in: Capsule())
                    }
                }
                
                Text(latestText)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(JournalColors.warmGray)
        }
        .padding(12)
        .background(JournalColors.cream, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
}

// MARK: - 日程卡片项
struct ScheduleCardItem: View {
    let schedule: ScheduleItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间标签
            VStack(spacing: 2) {
                Text(dayString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(JournalColors.mintGreen)
                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(JournalColors.warmGray)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(JournalColors.mintGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.title)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
                
                Text(schedule.reminder)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(10)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 10))
    }
    
    private var dayString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(schedule.dateTime) {
            return "今天"
        } else if calendar.isDateInTomorrow(schedule.dateTime) {
            return "明天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: schedule.dateTime)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: schedule.dateTime)
    }
}

// MARK: - 习惯卡片项
struct HabitCardItem: View {
    let habit: HabitItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 连续天数
            VStack(spacing: 2) {
                Text(habit.streakEmoji)
                    .font(.title2)
                Text("\(habit.streak)天")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(JournalColors.peach)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(JournalColors.peach.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
                
                Text(habit.feedback)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(10)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    StackedCardsView()
        .padding()
        .background(Color.gray.opacity(0.1))
}
