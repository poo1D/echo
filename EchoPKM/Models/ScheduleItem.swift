import Foundation
import SwiftData

@Model
final class ScheduleItem {
    var id: UUID
    var title: String
    var date: Date
    var endDate: Date?
    var notes: String?
    var isCompleted: Bool
    var sourceEntryID: UUID?
    var createdAt: Date

    init(
        title: String,
        date: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        isCompleted: Bool = false,
        sourceEntryID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.endDate = endDate
        self.notes = notes
        self.isCompleted = isCompleted
        self.sourceEntryID = sourceEntryID
        self.createdAt = Date()
    }
}
