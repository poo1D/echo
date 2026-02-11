import SwiftUI
import SwiftData

@main
struct EchoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [JournalEntry.self, AIInsight.self, Tag.self, MediaAttachment.self])
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [JournalEntry.self, AIInsight.self, Tag.self, MediaAttachment.self])
}
