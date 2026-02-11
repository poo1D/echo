import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var selectedDate = Date()
    @State private var showEditor = false
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "good morning."
        case 12..<17: return "good afternoon."
        case 17..<21: return "good evening."
        default: return "good night."
        }
    }
    
    private var todayEntry: JournalEntry? {
        entries.first { Calendar.current.isDateInToday($0.createdAt) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部问候语
                    headerSection
                    
                    // 周日历选择器
                    WeekCalendarView(selectedDate: $selectedDate)
                    
                    // 心情签到卡片
                    MoodCheckInCard(
                        isCompleted: todayEntry != nil,
                        currentMood: todayEntry?.moodEmoji
                    )
                    
                    // AI每日洞察
                    if let insight = todayEntry?.aiInsight {
                        AIInsightCard(insight: insight)
                            .withWashiTape(color: JournalColors.softPink)
                    }
                    
                    // 快捷练习
                    practicesSection
                    
                    // 本周主题
                    weeklyThemeSection
                }
                .padding()
            }
            .background(PaperTexture())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // 个人中心
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundStyle(JournalColors.inkBlack)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(JournalFonts.largeTitle)
                    .foregroundStyle(JournalColors.inkBlack)
            }
            Spacer()
        }
    }
    
    // MARK: - Practices Section
    private var practicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Practices")
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                Spacer()
                Button {
                    // 设置
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
            
            HStack(spacing: 16) {
                PracticeCard(
                    icon: "brain.head.profile",
                    title: "Clear Focus",
                    subtitle: "with Plato",
                    color: JournalColors.lavender
                )
                PracticeCard(
                    icon: "face.smiling",
                    title: "Mood",
                    subtitle: "Check-In",
                    color: JournalColors.warmWhite
                )
                PracticeCard(
                    icon: "leaf",
                    title: "End of Day",
                    subtitle: "Reflection",
                    color: JournalColors.mintGreen
                )
            }
        }
    }
    
    // MARK: - Weekly Theme Section
    private var weeklyThemeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Theme")
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                Spacer()
                Button {
                    // 查看全部
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(JournalFonts.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(JournalColors.warmGray)
                }
            }
            
            WeeklyThemeCard(
                title: "on structures.",
                dayProgress: "Day 6 of 7",
                isLocked: true
            )
        }
    }
}

// MARK: - Practice Card
struct PracticeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(JournalColors.inkBlack)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(JournalFonts.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .scrapbookStyle()
    }
}

// MARK: - Weekly Theme Card
struct WeeklyThemeCard: View {
    let title: String
    let dayProgress: String
    let isLocked: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(JournalFonts.headline)
                        .foregroundStyle(JournalColors.inkBlack)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(JournalColors.warmGray)
                    }
                }
                Text(dayProgress)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            Spacer()
        }
        .padding()
        .scrapbookStyle()
    }
}

#Preview {
    HomeView()
}
