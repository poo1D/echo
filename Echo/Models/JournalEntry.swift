import SwiftData
import Foundation

@Model
final class JournalEntry {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // 基础内容
    var title: String
    var textContent: String
    
    // 多模态内容
    @Relationship(deleteRule: .cascade)
    var photos: [MediaAttachment] = []
    
    @Relationship(deleteRule: .cascade)
    var voiceRecordings: [MediaAttachment] = []
    
    var handwritingStrokes: Data?  // PencilKit数据
    
    // 心情与标签
    var moodScore: Int?  // 1-5
    var moodEmoji: String?
    
    @Relationship
    var tags: [Tag] = []
    
    // AI分析结果
    @Relationship(deleteRule: .cascade)
    var aiInsight: AIInsight?
    
    // 元数据
    var locationName: String?
    var weatherEmoji: String?
    
    // 画布元素位置（用于手帐布局）
    var canvasLayout: Data?  // JSON encoded layout
    
    init(title: String = "", textContent: String = "") {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.title = title
        self.textContent = textContent
    }
}

@Model
final class AIInsight {
    var id: UUID
    var generatedAt: Date
    
    // 核心洞察
    var summary: String
    var moodAnalysis: String
    var moodTags: [String]
    
    // 长期模式
    var patternDetected: String?
    var growthSuggestion: String?
    
    // 关联
    var relatedEntryIDs: [UUID]
    
    init(summary: String, moodAnalysis: String) {
        self.id = UUID()
        self.generatedAt = Date()
        self.summary = summary
        self.moodAnalysis = moodAnalysis
        self.moodTags = []
        self.relatedEntryIDs = []
    }
}

@Model
final class MediaAttachment {
    var id: UUID
    var createdAt: Date
    var type: MediaType
    var localPath: String
    var thumbnailPath: String?
    var duration: Double?  // 语音时长
    var transcription: String?  // 语音转文字
    
    enum MediaType: String, Codable {
        case photo
        case voice
        case handwriting
    }
    
    init(type: MediaType, localPath: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.type = type
        self.localPath = localPath
    }
}

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var usageCount: Int
    
    init(name: String, colorHex: String = "FFE4E8") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.usageCount = 0
    }
}
