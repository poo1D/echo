import SwiftUI
import SwiftData

@main
struct EchoPKMApp: App {
    let modelContainer: ModelContainer
    @State private var notificationService = NotificationService()

    init() {
        let schema = Schema([DiaryEntry.self, WeeklyReview.self, ScheduleItem.self, HabitEntry.self])
        let config = ModelConfiguration(schema: schema)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema mismatch from previous install — delete corrupt store and retry
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            // Also remove journal/wal files
            let dir = storeURL.deletingLastPathComponent()
            let storeName = storeURL.lastPathComponent
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(storeName + "-wal"))
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(storeName + "-shm"))

            container = try! ModelContainer(for: schema, configurations: [config])
        }

        // Seed sample data and index for RAG
        if let seededEntries = SampleDataService.seedIfNeeded(modelContext: container.mainContext) {
            // Build RAG index in background so first search has results
            Task { @MainActor in
                let ragService = RAGService()
                ragService.rebuildIndex(entries: seededEntries)
                print("[App] RAG index built for \(seededEntries.count) sample entries")
            }
        }

        // Migrate existing entries to standardized tag system
        TopicTagService.migrateIfNeeded(modelContext: container.mainContext)

        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            ContentView(notificationService: notificationService)
                .task {
                    await notificationService.requestAuthorization()
                }
        }
        .modelContainer(modelContainer)
    }
}
