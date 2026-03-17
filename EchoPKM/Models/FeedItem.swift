import Foundation

// MARK: - Feed Item (heterogeneous content stream)

enum FeedItem: Identifiable {
    case proactiveCard(ProactiveCardData)
    case userMessage(UserMessageData)
    case agentPipeline(PipelineSnapshot)
    case assistantMessage(AssistantMessageData)
    case actionConfirm(ActionConfirmData)

    var id: String {
        switch self {
        case .proactiveCard(let d): return "proactive-\(d.id)"
        case .userMessage(let d): return "user-\(d.id)"
        case .agentPipeline(let d): return "pipeline-\(d.id)"
        case .assistantMessage(let d): return "assistant-\(d.id)"
        case .actionConfirm(let d): return "action-\(d.id)"
        }
    }
}

// MARK: - Proactive Card (AI-driven push on app launch)

struct ProactiveCardData: Identifiable {
    let id = UUID()
    let icon: String            // SF Symbol name
    let iconColor: String       // hex color
    let title: String
    let subtitle: String
    let type: ProactiveType

    enum ProactiveType {
        case schedule
        case habit
        case mood
        case memory
        case greeting
    }
}

// MARK: - User Message

struct UserMessageData: Identifiable {
    let id: UUID
    let content: String
    let photoFileNames: [String]
    let videoFileNames: [String]
    let timestamp: Date

    init(content: String, photoFileNames: [String] = [], videoFileNames: [String] = [], timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.photoFileNames = photoFileNames
        self.videoFileNames = videoFileNames
        self.timestamp = timestamp
    }

    init(id: UUID, content: String, photoFileNames: [String] = [], videoFileNames: [String] = [], timestamp: Date) {
        self.id = id
        self.content = content
        self.photoFileNames = photoFileNames
        self.videoFileNames = videoFileNames
        self.timestamp = timestamp
    }

    init(from message: ChatService.Message) {
        self.id = message.id
        self.content = message.content
        self.photoFileNames = message.photoFileNames
        self.videoFileNames = message.videoFileNames
        self.timestamp = message.timestamp
    }
}

// MARK: - Pipeline Snapshot (3 Agent status visualization)

struct PipelineSnapshot: Identifiable {
    let id = UUID()
    var ragStatus: AgentStatus = .idle
    var emotionStatus: AgentStatus = .idle
    var memoryStatus: AgentStatus = .idle
    var actionStatus: AgentStatus = .idle
    var synthesisStatus: AgentStatus = .idle
    var healthStatus: AgentStatus = .idle
    var intentType: String?

    enum AgentStatus: Equatable {
        case idle
        case running
        case completed(String)  // summary text
        case skipped            // agent not needed for this intent
        case failed
    }
}

// MARK: - Assistant Message (with rich content cards)

struct AssistantMessageData: Identifiable {
    let id: UUID
    var textContent: String
    var richCards: [RichContent]
    let timestamp: Date

    init(textContent: String = "", richCards: [RichContent] = [], timestamp: Date = Date()) {
        self.id = UUID()
        self.textContent = textContent
        self.richCards = richCards
        self.timestamp = timestamp
    }

    init(id: UUID, textContent: String = "", richCards: [RichContent] = [], timestamp: Date) {
        self.id = id
        self.textContent = textContent
        self.richCards = richCards
        self.timestamp = timestamp
    }
}

// MARK: - Action Confirm (executed actions)

struct ActionConfirmData: Identifiable {
    let id = UUID()
    let actionType: ActionType
    let title: String
    let detail: String
    var isExecuted: Bool

    enum ActionType {
        case scheduleCreated
        case habitLogged
        case moodRecorded
    }
}
