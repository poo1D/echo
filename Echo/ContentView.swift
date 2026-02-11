import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
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
                    JournalEditorView {
                        // 保存后跳转到宠物页
                        selectedTab = 1
                    }
                }
                Tab("Explore", systemImage: "safari", value: 3) {
                    ExploreView()
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
                JournalEditorView {
                    selectedTab = 1
                }
                    .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                    .tag(2)
                ExploreView()
                    .tabItem { Label("Explore", systemImage: "safari") }
                    .tag(3)
                HistoryView()
                    .tabItem { Label("History", systemImage: "book") }
                    .tag(4)
            }
        }
    }
}

#Preview {
    ContentView()
}
