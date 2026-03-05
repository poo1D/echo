import SwiftData
import Foundation

/// 结构化事实记忆 — L2 层，每篇日记后由 LLM 自动提取
@Model
final class FactMemory {
    var id: UUID
    var createdAt: Date
    var sourceEntryID: UUID?            // 来源日记 ID
    
    // 分类
    var category: String                // people / event / habit / preference / milestone
    var content: String                 // 事实内容文本
    var keywords: [String]              // 关键词索引，用于精确匹配
    var importance: Int                 // 重要性 1-5
    
    // 引用追踪
    var lastReferencedAt: Date?         // 最后被 AI 引用的时间
    var referenceCount: Int             // 被引用次数
    
    init(category: String, content: String, sourceEntryID: UUID? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.sourceEntryID = sourceEntryID
        self.category = category
        self.content = content
        self.keywords = []
        self.importance = 3
        self.referenceCount = 0
    }
    
    /// 综合访问评分：importance × 时间衰减 × 引用频次
    var accessScore: Double {
        let refDate = lastReferencedAt ?? createdAt
        let daysSinceReference = refDate.timeIntervalSinceNow / -86400
        let recencyFactor = max(0.05, 1.0 - daysSinceReference / 90.0)
        return Double(importance) * recencyFactor * (1.0 + log(Double(referenceCount + 1)))
    }
}

// MARK: - Category Constants
extension FactMemory {
    enum Category {
        static let people = "people"
        static let event = "event"
        static let habit = "habit"
        static let preference = "preference"
        static let milestone = "milestone"
    }
}

/// 日记向量索引记录 — L3 层，存储日记的 embedding 向量
@Model
final class JournalEmbedding {
    var id: UUID
    var entryID: UUID                   // 关联的 JournalEntry ID
    var createdAt: Date
    
    // 向量数据
    var embeddingData: Data             // [Float] 序列化存储
    
    // 用于快速过滤的摘要
    var textPreview: String             // 日记前100字预览
    
    init(entryID: UUID, embedding: [Float], textPreview: String) {
        self.id = UUID()
        self.entryID = entryID
        self.createdAt = Date()
        self.embeddingData = embedding.withUnsafeBufferPointer { Data(buffer: $0) }
        self.textPreview = textPreview
    }
    
    /// 获取向量数组
    func getEmbedding() -> [Float] {
        embeddingData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
}
