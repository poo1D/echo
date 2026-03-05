import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if #available(iOS 26, *) {
                // iOS 26+ Liquid Glass TabBar
                TabView(selection: $selectedTab) {
                    Tab("Home", systemImage: "house", value: 0) {
                        HomeView()
                    }
                    Tab("Echo", systemImage: "sparkles", value: 1) {
                        PetHomeView()
                    }
                    Tab("Add", systemImage: "plus.circle.fill", value: 2) {
                        ConversationalJournalView {
                            // 保存后跳转到宠物页
                            selectedTab = 1
                        }
                    }
                    Tab("Review", systemImage: "chart.bar", value: 3) {
                        ReviewView()
                    }
                    Tab("History", systemImage: "book", value: 4) {
                        HistoryView()
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else {
                // iOS 25及以下 Fallback
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Home", systemImage: "house") }
                        .tag(0)
                    PetHomeView()
                        .tabItem { Label("Echo", systemImage: "sparkles") }
                        .tag(1)
                    ConversationalJournalView {
                        selectedTab = 1
                    }
                        .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                        .tag(2)
                    ReviewView()
                        .tabItem { Label("Review", systemImage: "chart.bar") }
                        .tag(3)
                    HistoryView()
                        .tabItem { Label("History", systemImage: "book") }
                        .tag(4)
                }
            }
        }
        .onAppear {
            seedSampleDataIfNeeded()
        }
    }
    
    // MARK: - 示例数据注入（仅首次）
    
    private func seedSampleDataIfNeeded() {
        let key = "hasSeededSampleData_v4"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        
        // 检查是否已有数据
        let descriptor = FetchDescriptor<JournalEntry>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }
        
        // 心情 emoji 映射（匹配每篇日记的情绪）
        let moods: [String] = [
            "😌", "😊", "😢", "🤩", "😊",  // 1-5: 累→早起→压力→开心→学习
            "😴", "😊", "🤩", "😊", "😊",  // 6-10: 累→阅读→聚会→冥想→充实
            "😊", "😢", "🤩", "😢", "🥰",  // 11-15: 咖啡→失眠→跑步→社恐→妈妈
            "😊", "😢", "🤩", "😌", "🤩"   // 16-20: 编程→压力→篮球→阅读→offer
        ]
        
        for (index, sample) in SampleJournals.entries.enumerated() {
            let entry = JournalEntry(title: sample.title, textContent: sample.content)
            entry.createdAt = sample.date
            entry.updatedAt = sample.date
            let mood = moods[index % moods.count]
            entry.moodEmoji = mood
            entry.moodScore = MoodDataPoint.scoreFromEmoji(mood)
            modelContext.insert(entry)
        }
        
        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: key)
            print("🌱 [Seed] 成功注入 \(SampleJournals.entries.count) 篇示例日记")
        } catch {
            print("❌ [Seed] 注入失败: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
