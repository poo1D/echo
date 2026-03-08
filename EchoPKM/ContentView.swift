import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                TabView(selection: $selectedTab) {
                    Tab("Echo", systemImage: "house.fill", value: 0) {
                        HomeView()
                    }
                    Tab("Diary", systemImage: "book.closed", value: 1) {
                        DiaryView()
                    }
                    Tab("Review", systemImage: "chart.bar.fill", value: 2) {
                        ReviewView()
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Echo", systemImage: "house.fill") }
                        .tag(0)
                    DiaryView()
                        .tabItem { Label("Diary", systemImage: "book.closed") }
                        .tag(1)
                    ReviewView()
                        .tabItem { Label("Review", systemImage: "chart.bar.fill") }
                        .tag(2)
                }
            }
        }
        .task {
            SampleDataService.seedIfNeeded(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
