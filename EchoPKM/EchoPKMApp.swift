import SwiftUI
import SwiftData

@main
struct EchoPKMApp: App {
    let modelContainer: ModelContainer

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

        SampleDataService.seedIfNeeded(modelContext: container.mainContext)
        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
