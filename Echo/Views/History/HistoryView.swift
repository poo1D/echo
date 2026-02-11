import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .list
    @State private var selectedEntry: JournalEntry?
    @State private var showAISearch = false
    @State private var aiSearchResults: [JournalEntry] = []
    @State private var isSearching = false
    @State private var showScrapbook = false
    
    enum ViewMode: String, CaseIterable {
        case list = "列表"
        case calendar = "日历"
    }
    
    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
    
    private var entriesCount: Int {
        entries.count
    }
    
    private var totalWords: Int {
        entries.reduce(0) { $0 + $1.textContent.split(separator: " ").count }
    }
    
    private var groupedEntries: [String: [JournalEntry]] {
        Dictionary(grouping: entries) { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: entry.createdAt)
        }
    }
    
    // 搜索过滤
    private var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText) ||
            entry.textContent.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 页面标题
                    Text("history.")
                        .font(JournalFonts.largeTitle)
                        .foregroundStyle(JournalColors.inkBlack)
                    
                    // 视图模式切换
                    viewModePicker
                    
                    // 月度洞察卡片
                    MonthlyInsightCard(
                        month: currentMonth,
                        entriesCount: entriesCount,
                        wordsCount: totalWords
                    )
                    
                    // 翻阅手帐入口
                    scrapbookEntry
                    
                    // 根据模式显示内容
                    if viewMode == .calendar {
                        calendarGrid
                    } else {
                        listView
                    }
                }
                .padding()
            }
            .background(PaperTexture())
            .searchable(text: $searchText, prompt: "搜索日记内容...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // AI智能搜索
                        Button {
                            showAISearch = true
                        } label: {
                            Image(systemName: "sparkle.magnifyingglass")
                                .foregroundStyle(JournalColors.lavender)
                        }
                        
                        // 筛选
                        Button {
                            // 筛选
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .foregroundStyle(JournalColors.inkBlack)
                        }
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                JournalDetailSheet(entry: entry)
            }
            .sheet(isPresented: $showAISearch) {
                AISearchSheet(entries: entries, onSearch: { results in
                    aiSearchResults = results
                })
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showScrapbook) {
                ScrapbookView()
            }
        }
    }
    
    // MARK: - Scrapbook Entry
    private var scrapbookEntry: some View {
        Button {
            showScrapbook = true
        } label: {
            HStack {
                // 左侧图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [JournalColors.peach.opacity(0.3), JournalColors.lavender.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(JournalColors.lavender)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("翻阅手帐")
                        .font(JournalFonts.headline)
                        .foregroundStyle(JournalColors.inkBlack)
                    
                    Text("和Echo的共同回忆")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(JournalColors.warmGray)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(JournalColors.warmWhite)
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - View Mode Picker
    private var viewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(JournalFonts.caption)
                        .foregroundStyle(viewMode == mode ? .white : JournalColors.warmGray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(viewMode == mode ? JournalColors.inkBlack : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(JournalColors.warmWhite, in: Capsule())
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let calendar = Calendar.current
        let today = Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        
        return VStack(spacing: 12) {
            // 星期标题
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
            
            // 日期网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // 前置空白
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 50)
                }
                
                // 日期
                ForEach(1...daysInMonth, id: \.self) { day in
                    calendarDayCell(day: day, hasEntry: hasEntryOnDay(day))
                }
            }
        }
        .padding()
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func calendarDayCell(day: Int, hasEntry: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(JournalFonts.body)
                .foregroundStyle(JournalColors.inkBlack)
            
            if hasEntry {
                Circle()
                    .fill(JournalColors.lavender)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(hasEntry ? JournalColors.lavender.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func hasEntryOnDay(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        if let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: calendar.component(.month, from: today), day: day)) {
            return entries.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
        }
        return false
    }
    
    // MARK: - List View
    private var listView: some View {
        ForEach(groupedEntries.keys.sorted().reversed(), id: \.self) { dateKey in
            if let dayEntries = groupedEntries[dateKey] {
                Section {
                    ForEach(dayEntries) { entry in
                        JournalEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                            .contextMenu {
                                Button {
                                    selectedEntry = entry
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(entry)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(dateKey)
                            .font(JournalFonts.caption)
                            .foregroundStyle(JournalColors.warmGray)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(JournalColors.warmGray)
                    }
                }
            }
        }
    }
}

// MARK: - Monthly Insight Card
struct MonthlyInsightCard: View {
    let month: String
    let entriesCount: Int
    let wordsCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(month)\nInsights")
                    .font(JournalFonts.title)
                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entries")
                        .font(JournalFonts.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(entriesCount)")
                        .font(JournalFonts.title)
                        .foregroundStyle(.white)
                }
                
                Divider()
                    .frame(height: 40)
                    .background(.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Words")
                        .font(JournalFonts.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(wordsCount)")
                        .font(JournalFonts.title)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(24)
        .frame(height: 200)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.black, Color(hex: "1a1a1a")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Journal Entry Row (手帐卡片风格)
struct JournalEntryRow: View {
    let entry: JournalEntry
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: entry.createdAt)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.title.isEmpty ? "Daily Check-In" : entry.title)
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                Spacer()
                Text(timeString)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            
            // 内容预览
            if !entry.textContent.isEmpty {
                Text(entry.textContent)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.warmGray)
                    .lineLimit(2)
            }
            
            // 标签和宠物反馈
            HStack(spacing: 8) {
                ForEach(entry.tags) { tag in
                    MoodTagChip(icon: "tag", text: tag.name)
                }
                
                if let mood = entry.moodEmoji {
                    HStack(spacing: 4) {
                        Text(mood)
                        Text("Mood")
                            .font(JournalFonts.caption)
                    }
                    .foregroundStyle(JournalColors.inkBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(JournalColors.mintGreen.opacity(0.3), in: Capsule())
                }
                
                Spacer()
                
                // 宠物能量标记
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                    Text("+5")
                        .font(JournalFonts.caption)
                }
                .foregroundStyle(JournalColors.peach)
            }
            
            // 宠物回应小卡片
            PetResponseCard()
        }
        .padding()
        .scrapbookStyle()
    }
}

// MARK: - Pet Response Card
struct PetResponseCard: View {
    private let responses = [
        "谢谢你今天的分享！",
        "我感受到了你的心情~",
        "和你在一起真好！",
        "今天辛苦了！"
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            // 小宠物头像
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay {
                    Circle()
                        .fill(JournalColors.warmWhite)
                        .frame(width: 16)
                }
            
            Text(responses.randomElement() ?? "")
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
            
            Spacer()
        }
        .padding(8)
        .background(JournalColors.lavender.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HistoryView()
}
