import Foundation
import SwiftData

/// Converts a chat session into a persisted DiaryEntry
@Observable @MainActor
final class AutoSaveService {
    var isSaving = false
    var sessionAudioFiles: [String] = []
    var sessionPhotoFiles: [String] = []
    var sessionLocation: PendingLocation?

    /// Save the current conversation as a diary entry.
    /// Only saves if the user sent at least `minimumUserMessages` messages.
    func saveSession(
        messages: [ChatService.Message],
        chatService: ChatService,
        modelContext: ModelContext,
        insightService: InsightService? = nil,
        scheduleHabitService: ScheduleHabitService? = nil,
        minimumUserMessages: Int = 2
    ) async {
        let userMessageCount = messages.filter { $0.role == .user }.count
        guard userMessageCount >= minimumUserMessages else { return }
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        // Ask LLM to summarize the conversation
        let result = await chatService.summarizeSession()

        // Encode transcript
        let transcriptData = DiaryEntry.encodeTranscript(messages)

        // Create entry
        let entry = DiaryEntry(
            summary: result.summary,
            moodEmoji: result.moodEmoji,
            moodScore: result.moodScore,
            transcript: transcriptData,
            audioFileNames: sessionAudioFiles,
            photoFileNames: sessionPhotoFiles,
            topics: result.topics,
            locationName: sessionLocation?.name,
            latitude: sessionLocation?.latitude,
            longitude: sessionLocation?.longitude
        )
        modelContext.insert(entry)

        // Try to persist
        try? modelContext.save()

        // Generate AI insight asynchronously (don't block save)
        if let insightService {
            Task {
                await insightService.generateInsight(for: entry, modelContext: modelContext)
            }
        }

        // Extract schedules and habits asynchronously
        if let scheduleHabitService {
            Task {
                await scheduleHabitService.extractFromEntry(entry, modelContext: modelContext)
            }
        }

        // Reset session
        chatService.clear()
        sessionAudioFiles.removeAll()
        sessionPhotoFiles.removeAll()
        sessionLocation = nil
    }
}
