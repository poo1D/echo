import Foundation

// MARK: - Codable models for draft persistence

struct DraftMessage: Codable, Identifiable {
    enum Role: String, Codable { case user, assistant }
    var id: UUID
    var role: Role
    var content: String
    var photoFileNames: [String]
    var videoFileNames: [String]
    var timestamp: Date
}

struct ConversationDraft: Codable {
    var savedAt: Date
    var messages: [DraftMessage]
    var audioFileNames: [String]
    var photoFileNames: [String]
    var videoFileNames: [String]
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var moodEmoji: String?
}

// MARK: - Service

/// 负责将未保存的对话草稿持久化到磁盘，跨 ConversationView 生命周期保留。
/// - 当天打开 → 恢复草稿继续对话
/// - 隔天打开 → 自动将前一天草稿存为日记，再清空开始新会话
@Observable @MainActor
final class DraftSessionService {

    private(set) var draft: ConversationDraft?

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversation_draft.json")
    }

    // MARK: - Load

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(ConversationDraft.self, from: data)
        else { return }
        draft = decoded
    }

    // MARK: - Save

    /// 将当前 feedItems 序列化为草稿写入磁盘（只保留 user/assistant 消息）
    func save(
        feedItems: [FeedItem],
        audioFiles: [String],
        photoFiles: [String],
        videoFiles: [String],
        locationName: String?,
        latitude: Double?,
        longitude: Double?,
        moodEmoji: String?
    ) {
        let hasUser = feedItems.contains { if case .userMessage = $0 { return true } else { return false } }
        guard hasUser else { return }

        var messages: [DraftMessage] = []
        for item in feedItems {
            switch item {
            case .userMessage(let d):
                messages.append(DraftMessage(
                    id: d.id, role: .user, content: d.content,
                    photoFileNames: d.photoFileNames, videoFileNames: d.videoFileNames,
                    timestamp: d.timestamp
                ))
            case .assistantMessage(let d) where !d.textContent.isEmpty:
                messages.append(DraftMessage(
                    id: d.id, role: .assistant, content: d.textContent,
                    photoFileNames: [], videoFileNames: [], timestamp: d.timestamp
                ))
            default:
                break
            }
        }
        guard !messages.isEmpty else { return }

        let newDraft = ConversationDraft(
            savedAt: Date(),
            messages: messages,
            audioFileNames: audioFiles,
            photoFileNames: photoFiles,
            videoFileNames: videoFiles,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            moodEmoji: moodEmoji
        )
        draft = newDraft
        if let encoded = try? JSONEncoder().encode(newDraft) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Clear

    func clear() {
        draft = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Queries

    var hasDraftFromToday: Bool {
        guard let draft else { return false }
        return Calendar.current.isDateInToday(draft.savedAt)
    }

    var hasDraftFromPreviousDay: Bool {
        guard let draft else { return false }
        return !Calendar.current.isDateInToday(draft.savedAt)
    }

    // MARK: - Restore helpers

    /// 从草稿重建 FeedItem 列表（不含 richCards，仅文本）
    func restoreFeedItems() -> [FeedItem] {
        guard let draft else { return [] }
        return draft.messages.map { msg in
            switch msg.role {
            case .user:
                return .userMessage(UserMessageData(
                    id: msg.id, content: msg.content,
                    photoFileNames: msg.photoFileNames,
                    videoFileNames: msg.videoFileNames,
                    timestamp: msg.timestamp
                ))
            case .assistant:
                return .assistantMessage(AssistantMessageData(
                    id: msg.id, textContent: msg.content,
                    timestamp: msg.timestamp
                ))
            }
        }
    }

    /// 从草稿重建 ChatService.Message 列表（用于向 LLM 提供上下文）
    func restoreChatMessages() -> [ChatService.Message] {
        guard let draft else { return [] }
        return draft.messages.map { msg in
            ChatService.Message(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content,
                photoFileNames: msg.photoFileNames,
                videoFileNames: msg.videoFileNames
            )
        }
    }
}
