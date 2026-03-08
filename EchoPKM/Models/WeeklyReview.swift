import Foundation
import SwiftData

@Model
class WeeklyReview {
    var id: UUID
    var weekStartDate: Date
    var observation: String
    var generatedAt: Date
    var entryCount: Int

    init(
        weekStartDate: Date,
        observation: String,
        entryCount: Int
    ) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.observation = observation
        self.generatedAt = Date()
        self.entryCount = entryCount
    }
}
