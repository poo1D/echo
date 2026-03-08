import Foundation
import SwiftData

@Model
final class HabitEntry {
    var id: UUID
    var name: String
    var date: Date
    var completed: Bool
    var sourceEntryID: UUID?
    var createdAt: Date

    init(
        name: String,
        date: Date,
        completed: Bool = true,
        sourceEntryID: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name.lowercased()
        self.date = date
        self.completed = completed
        self.sourceEntryID = sourceEntryID
        self.createdAt = Date()
    }
}
