import SwiftUI
import SwiftData

/// 复盘分析页面 — 替代 ExploreView
struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]
    
    @State private var weeklyReview: WeeklyReview?
    @State private var isLoadingReview = false
    
    // 本周日记
    private var thisWeekEntries: [JournalEntry] {
        let cal = Calendar.current
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return allEntries.filter { $0.createdAt >= startOfWeek }
    }
    
    // 最近7天日记
    private var last7DaysEntries: [JournalEntry] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date()))!
        return allEntries.filter { $0.createdAt >= sevenDaysAgo }
    }
    
    // 心情数据点
    private var moodDataPoints: [MoodDataPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        return (0..<7).reversed().compactMap { daysAgo -> MoodDataPoint? in
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            
            // 找这天的日记
            let dayEntries = allEntries.filter { cal.isDate($0.createdAt, inSameDayAs: date) }
            
            if let entry = dayEntries.first, let emoji = entry.moodEmoji {
                return MoodDataPoint(
                    date: date,
                    emoji: emoji,
                    score: MoodDataPoint.scoreFromEmoji(emoji)
                )
            } else if !dayEntries.isEmpty {
                // 有日记但无心情标记
                return MoodDataPoint(date: date, emoji: "😐", score: 3)
            }
            return nil
        }
    }
    
    // 连续记录天数
    private var currentStreak: Int {
        guard !allEntries.isEmpty else { return 0 }
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        
        while true {
            let hasEntry = allEntries.contains { cal.isDate($0.createdAt, inSameDayAs: checkDate) }
            if hasEntry {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }
    
    // 平均心情
    private var avgMoodEmoji: String {
        let scores = last7DaysEntries.compactMap { entry -> Int? in
            guard let emoji = entry.moodEmoji else { return nil }
            return MoodDataPoint.scoreFromEmoji(emoji)
        }
        guard !scores.isEmpty else { return "😐" }
        let avg = Double(scores.reduce(0, +)) / Double(scores.count)
        switch avg {
        case 4.5...: return "🤩"
        case 3.5..<4.5: return "😊"
        case 2.5..<3.5: return "😌"
        case 1.5..<2.5: return "😴"
        default: return "😢"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    HStack {
                        Text("review.")
                            .font(JournalFonts.largeTitle)
                            .foregroundStyle(JournalColors.inkBlack)
                        Spacer()
                    }
                    
                    // 统计概览
                    statsOverview
                    
                    // 心情趋势图
                    MoodTrendChart(dataPoints: moodDataPoints)
                    
                    // 周度复盘
                    weeklyReviewSection
                    
                    // 今日日程
                    todayScheduleSection
                    
                    // 习惯追踪
                    habitTrackerSection
                }
                .padding()
            }
            .background(PaperTexture())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Stats Overview
    private var statsOverview: some View {
        HStack(spacing: 12) {
            StatMiniCard(
                icon: "book.closed",
                value: "\(allEntries.count)",
                label: "日记",
                color: JournalColors.lavender
            )
            StatMiniCard(
                icon: "flame",
                value: "\(currentStreak)",
                label: "连续",
                color: JournalColors.peach
            )
            StatMiniCard(
                icon: "face.smiling",
                value: avgMoodEmoji,
                label: "本周",
                color: JournalColors.mintGreen,
                isEmoji: true
            )
        }
    }
    
    // MARK: - Weekly Review Section
    private var weeklyReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.document")
                    .foregroundStyle(JournalColors.lavender)
                Text("本周复盘")
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                Spacer()
            }
            
            if let review = weeklyReview {
                // 显示复盘内容
                VStack(alignment: .leading, spacing: 12) {
                    if !review.highlights.isEmpty {
                        ReviewRow(icon: "✨", title: "亮点", content: review.highlights)
                    }
                    if !review.moodSummary.isEmpty {
                        ReviewRow(icon: "🎭", title: "心情", content: review.moodSummary)
                    }
                    if !review.growthNote.isEmpty {
                        ReviewRow(icon: "🌱", title: "成长", content: review.growthNote)
                    }
                    if !review.suggestion.isEmpty {
                        ReviewRow(icon: "💡", title: "建议", content: review.suggestion)
                    }
                }
            } else {
                // 生成按钮
                Button {
                    generateReview()
                } label: {
                    HStack {
                        if isLoadingReview {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isLoadingReview ? "Echo 正在复盘..." : "生成本周复盘")
                            .font(JournalFonts.body)
                    }
                    .foregroundStyle(JournalColors.lavender)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(JournalColors.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                JournalColors.lavender.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                    )
                }
                .disabled(isLoadingReview || thisWeekEntries.isEmpty)
                
                if thisWeekEntries.isEmpty {
                    Text("本周还没有日记，写一篇再来复盘吧")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
        }
        .padding()
        .scrapbookStyle()
    }
    
    // MARK: - Today Schedule
    private var todayScheduleSection: some View {
        let schedules = AIScheduleHabitService.shared.extractedSchedules.filter { item in
            Calendar.current.isDateInToday(item.dateTime) && !item.isCompleted
        }
        
        return Group {
            if !schedules.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(JournalColors.peach)
                        Text("今日日程")
                            .font(JournalFonts.headline)
                            .foregroundStyle(JournalColors.inkBlack)
                        Spacer()
                        Text("\(schedules.count) 项")
                            .font(JournalFonts.caption)
                            .foregroundStyle(JournalColors.warmGray)
                    }
                    
                    ForEach(schedules) { item in
                        HStack(spacing: 12) {
                            Circle()
                                .strokeBorder(JournalColors.peach, lineWidth: 2)
                                .frame(width: 20, height: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(JournalFonts.body)
                                    .foregroundStyle(JournalColors.inkBlack)
                                Text(item.reminder)
                                    .font(JournalFonts.caption)
                                    .foregroundStyle(JournalColors.warmGray)
                            }
                            
                            Spacer()
                            
                            Text(formatTime(item.dateTime))
                                .font(JournalFonts.caption)
                                .foregroundStyle(JournalColors.warmGray)
                        }
                    }
                }
                .padding()
                .scrapbookStyle()
            }
        }
    }
    
    // MARK: - Habit Tracker
    private var habitTrackerSection: some View {
        let habits = AIScheduleHabitService.shared.extractedHabits
        
        return Group {
            if !habits.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "leaf")
                            .foregroundStyle(JournalColors.mintGreen)
                        Text("习惯追踪")
                            .font(JournalFonts.headline)
                            .foregroundStyle(JournalColors.inkBlack)
                        Spacer()
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(habits) { habit in
                                HabitCard(habit: habit)
                            }
                        }
                    }
                }
                .padding()
                .scrapbookStyle()
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateReview() {
        isLoadingReview = true
        Task {
            let review = await WeeklyReviewService.shared.generateWeeklyReview(from: thisWeekEntries)
            weeklyReview = review
            isLoadingReview = false
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 子组件

struct StatMiniCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var isEmoji: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            if isEmoji {
                Text(value)
                    .font(.title)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                    Text(value)
                        .font(JournalFonts.headline)
                        .foregroundStyle(JournalColors.inkBlack)
                }
            }
            Text(label)
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .scrapbookStyle()
    }
}

struct ReviewRow: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(icon)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                Text(content)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
            }
        }
    }
}

struct HabitCard: View {
    let habit: HabitItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.name)
                .font(JournalFonts.body)
                .fontWeight(.medium)
                .foregroundStyle(JournalColors.inkBlack)
            
            Text("连续 \(habit.streak) 天")
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.mintGreen)
            
            // 小点阵（最近7天）
            HStack(spacing: 4) {
                ForEach(0..<7) { day in
                    Circle()
                        .fill(day < habit.streak ? JournalColors.mintGreen : JournalColors.warmGray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding()
        .frame(width: 140)
        .background(JournalColors.mintGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(JournalColors.mintGreen.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: [JournalEntry.self, AIInsight.self, Tag.self, MediaAttachment.self])
}
