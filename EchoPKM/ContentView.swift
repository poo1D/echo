import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                TabView(selection: $selectedTab) {
                    Tab("Echo", systemImage: "bird.fill", value: 0) {
                        UnifiedView()
                    }
                    Tab("Review", systemImage: "chart.bar.fill", value: 1) {
                        ReviewView()
                    }
                    Tab("Profile", systemImage: "person.crop.circle", value: 2) {
                        ProfileView()
                    }
                }
                .tint(Color.claudeAccent)
            } else {
                TabView(selection: $selectedTab) {
                    UnifiedView()
                        .tabItem { Label("Echo", systemImage: "bird.fill") }
                        .tag(0)
                    ReviewView()
                        .tabItem { Label("Review", systemImage: "chart.bar.fill") }
                        .tag(1)
                    ProfileView()
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                        .tag(2)
                }
                .tint(Color.claudeAccent)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self], inMemory: true)
}
