import Foundation
import SwiftData

/// Converts a chat session into a persisted DiaryEntry
@Observable @MainActor
final class AutoSaveService {
    var isSaving = false
    var sessionAudioFiles: [String] = []
    var sessionPhotoFiles: [String] = []
    var sessionVideoFiles: [String] = []
    var sessionLocation: PendingLocation?

    /// Save from FeedItem array — extracts user/assistant messages for diary entry.
    func saveFeedSession(
        feedItems: [FeedItem],
        chatService: ChatService,
        modelContext: ModelContext,
        insightService: InsightService? = nil,
        scheduleHabitService: ScheduleHabitService? = nil,
        ragService: RAGService? = nil,
        minimumUserMessages: Int = 2
    ) async {
        // Extract messages from feed items
        let messages = extractMessages(from: feedItems)
        guard !messages.isEmpty else { return }

        await saveSession(
            messages: messages,
            chatService: chatService,
            modelContext: modelContext,
            insightService: insightService,
            scheduleHabitService: scheduleHabitService,
            ragService: ragService,
            minimumUserMessages: minimumUserMessages
        )
    }

    /// Extract ChatService.Message equivalents from FeedItem array
    private func extractMessages(from feedItems: [FeedItem]) -> [ChatService.Message] {
        var messages: [ChatService.Message] = []
        for item in feedItems {
            switch item {
            case .userMessage(let data):
                messages.append(ChatService.Message(
                    role: .user,
                    content: data.content,
                    photoFileNames: data.photoFileNames,
                    videoFileNames: data.videoFileNames
                ))
            case .assistantMessage(let data):
                if !data.textContent.isEmpty {
                    messages.append(ChatService.Message(
                        role: .assistant,
                        content: data.textContent
                    ))
                }
            default:
                break
            }
        }
        return messages
    }

    /// Save the current conversation as a diary entry.
    /// Only saves if the user sent at least `minimumUserMessages` messages.
    func saveSession(
        messages: [ChatService.Message],
        chatService: ChatService,
        modelContext: ModelContext,
        insightService: InsightService? = nil,
        scheduleHabitService: ScheduleHabitService? = nil,
        ragService: RAGService? = nil,
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
            videoFileNames: sessionVideoFiles,
            topics: result.topics,
            locationName: sessionLocation?.name,
            latitude: sessionLocation?.latitude,
            longitude: sessionLocation?.longitude
        )
        modelContext.insert(entry)

        // Try to persist
        try? modelContext.save()

        // Index new entry for RAG semantic search
        ragService?.indexEntry(entry)

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
        sessionVideoFiles.removeAll()
        sessionLocation = nil
    }
}
