import Foundation
import NaturalLanguage
import Accelerate

/// 本地向量存储与检索服务 — 基于 Apple NLEmbedding + Accelerate
/// 负责 embedding 生成和语义相似度搜索
@Observable @MainActor
final class VectorStore {
    
    static let shared = VectorStore()
    
    /// NLEmbedding 实例（中文句子级 embedding）
    private var sentenceEmbedding: NLEmbedding?
    
    /// embedding 维度
    private(set) var embeddingDimension: Int = 0
    
    private init() {
        loadEmbedding()
    }
    
    // MARK: - 初始化
    
    private func loadEmbedding() {
        // 尝试加载中文句子级 embedding
        if let embedding = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) {
            self.sentenceEmbedding = embedding
            self.embeddingDimension = embedding.dimension
            print("✅ [VectorStore] 中文句子级 embedding 加载成功，维度: \(embedding.dimension)")
        } else if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
            // 降级到英文
            self.sentenceEmbedding = embedding
            self.embeddingDimension = embedding.dimension
            print("⚠️ [VectorStore] 降级到英文 embedding，维度: \(embedding.dimension)")
        } else {
            print("❌ [VectorStore] 无法加载 NLEmbedding")
        }
    }
    
    // MARK: - Embedding 生成
    
    /// 为文本生成 embedding 向量
    func generateEmbedding(for text: String) -> [Float]? {
        guard let embedding = sentenceEmbedding else {
            print("❌ [VectorStore] NLEmbedding 未初始化")
            return nil
        }
        
        // NLEmbedding.vector 返回 [Double]，我们转为 [Float] 节省存储
        guard let vector = embedding.vector(for: text) else {
            print("⚠️ [VectorStore] 无法为文本生成 embedding: \(text.prefix(50))...")
            return nil
        }
        
        return vector.map { Float($0) }
    }
    
    // MARK: - 相似度搜索
    
    /// 在候选向量中搜索与 query 最相似的 top-K 结果
    /// - Parameters:
    ///   - queryVector: 查询向量
    ///   - candidates: 候选列表 [(id, vector)]
    ///   - topK: 返回数量
    /// - Returns: [(id, similarity)] 按相似度降序排列
    func search(
        queryVector: [Float],
        candidates: [(id: UUID, vector: [Float])],
        topK: Int = 5
    ) -> [(id: UUID, similarity: Float)] {
        guard !candidates.isEmpty else { return [] }
        
        var results: [(id: UUID, similarity: Float)] = []
        
        for candidate in candidates {
            let similarity = cosineSimilarity(queryVector, candidate.vector)
            results.append((id: candidate.id, similarity: similarity))
        }
        
        // 按相似度降序排列，取 top-K
        results.sort { $0.similarity > $1.similarity }
        return Array(results.prefix(topK))
    }
    
    // MARK: - 余弦相似度计算（使用 Accelerate 优化）
    
    /// 使用 Accelerate 框架高效计算两个向量的余弦相似度
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        
        let count = vDSP_Length(a.count)
        
        // 计算点积: a · b
        var dotProduct: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, count)
        
        // 计算 ||a||
        var normA: Float = 0
        vDSP_svesq(a, 1, &normA, count)
        normA = sqrt(normA)
        
        // 计算 ||b||
        var normB: Float = 0
        vDSP_svesq(b, 1, &normB, count)
        normB = sqrt(normB)
        
        // 避免除零
        guard normA > 0, normB > 0 else { return 0 }
        
        return dotProduct / (normA * normB)
    }
}
