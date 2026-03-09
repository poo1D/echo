import Foundation
import NaturalLanguage
import Accelerate

/// On-device semantic retrieval engine using Apple NaturalLanguage + Accelerate frameworks.
/// Implements Retrieve → Re-rank → Generate (RAG) pipeline with zero API calls.
@Observable @MainActor
final class RAGService {

    // MARK: - Types

    struct IndexedEntry: Codable {
        let entryID: UUID
        let vector: [Double]       // NLEmbedding dimension (typically 512)
        let summary: String
        let date: Date
        let moodEmoji: String?
        let topics: [String]
    }

    struct RAGResult {
        let entryID: UUID
        let summary: String
        let date: Date
        let moodEmoji: String?
        let topics: [String]
        let score: Double          // cosine similarity 0..1
    }

    // MARK: - State

    private(set) var vectorStore: [IndexedEntry] = []
    private(set) var isIndexing = false
    var indexCount: Int { vectorStore.count }

    // MARK: - Private

    private var embeddingDimension: Int = 512
    private var chineseEmbedding: NLEmbedding?
    private var englishEmbedding: NLEmbedding?

    private var indexFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rag_vector_index.json")
    }

    // MARK: - Embedding Initialization

    private func ensureEmbeddings() {
        if chineseEmbedding == nil {
            chineseEmbedding = NLEmbedding.wordEmbedding(for: .simplifiedChinese)
            if let dim = chineseEmbedding?.dimension {
                embeddingDimension = dim
            }
        }
        if englishEmbedding == nil {
            englishEmbedding = NLEmbedding.wordEmbedding(for: .english)
            if let dim = englishEmbedding?.dimension {
                embeddingDimension = dim
            }
        }
    }

    // MARK: - Text → Vector

    /// Compute document embedding via NLTokenizer word segmentation + NLEmbedding + mean pooling (vDSP accelerated).
    func computeEmbedding(for text: String) -> [Double]? {
        ensureEmbeddings()

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage ?? .simplifiedChinese

        let embedding: NLEmbedding?
        if language == .english {
            embedding = englishEmbedding
        } else {
            // Default to Chinese for Chinese, Japanese, and other CJK languages
            embedding = chineseEmbedding
        }

        guard let embedding else {
            // Fallback to character bigram TF-IDF
            return bigramFallbackVector(for: text)
        }

        // Tokenize
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var wordVectors: [[Double]] = []

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if let vec = embedding.vector(for: word) {
                wordVectors.append(vec.map { Double($0) })
            }
            return true
        }

        guard !wordVectors.isEmpty else {
            return bigramFallbackVector(for: text)
        }

        // Mean pooling using vDSP
        let dim = embeddingDimension
        var result = [Double](repeating: 0.0, count: dim)
        let count = Double(wordVectors.count)

        for vec in wordVectors {
            guard vec.count == dim else { continue }
            // vDSP_vaddD: result = result + vec
            vec.withUnsafeBufferPointer { vecBuf in
                result.withUnsafeMutableBufferPointer { resBuf in
                    vDSP_vaddD(resBuf.baseAddress!, 1,
                               vecBuf.baseAddress!, 1,
                               resBuf.baseAddress!, 1,
                               vDSP_Length(dim))
                }
            }
        }

        // vDSP_vsdivD: result = result / count
        var divisor = count
        result.withUnsafeMutableBufferPointer { buf in
            vDSP_vsdivD(buf.baseAddress!, 1, &divisor, buf.baseAddress!, 1, vDSP_Length(dim))
        }

        return result
    }

    /// Fallback: character bigram TF-IDF vector when NLEmbedding is unavailable.
    private func bigramFallbackVector(for text: String) -> [Double] {
        let chars = Array(text.lowercased())
        guard chars.count >= 2 else {
            return [Double](repeating: 0.0, count: embeddingDimension)
        }

        var vector = [Double](repeating: 0.0, count: embeddingDimension)
        for i in 0..<(chars.count - 1) {
            let bigram = "\(chars[i])\(chars[i + 1])"
            let hash = abs(bigram.hashValue) % embeddingDimension
            vector[hash] += 1.0
        }

        // L2 normalize
        var sumSq: Double = 0
        vDSP_dotprD(vector, 1, vector, 1, &sumSq, vDSP_Length(embeddingDimension))
        let norm = sqrt(sumSq)
        if norm > 0 {
            var n = norm
            vector.withUnsafeMutableBufferPointer { buf in
                vDSP_vsdivD(buf.baseAddress!, 1, &n, buf.baseAddress!, 1, vDSP_Length(embeddingDimension))
            }
        }

        return vector
    }

    // MARK: - Cosine Similarity (vDSP accelerated)

    func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = vDSP_Length(a.count)

        var dot: Double = 0
        var normA: Double = 0
        var normB: Double = 0

        vDSP_dotprD(a, 1, b, 1, &dot, n)
        vDSP_dotprD(a, 1, a, 1, &normA, n)
        vDSP_dotprD(b, 1, b, 1, &normB, n)

        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }

    // MARK: - Search

    /// Semantic search: compute query vector, compare against all indexed entries, return top-K results above threshold.
    func search(query: String, topK: Int = 5) -> [RAGResult] {
        guard let queryVector = computeEmbedding(for: query) else { return [] }

        let scored = vectorStore.compactMap { entry -> RAGResult? in
            let score = cosineSimilarity(queryVector, entry.vector)
            guard score >= 0.3 else { return nil }
            return RAGResult(
                entryID: entry.entryID,
                summary: entry.summary,
                date: entry.date,
                moodEmoji: entry.moodEmoji,
                topics: entry.topics,
                score: score
            )
        }

        return scored.sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    // MARK: - Indexing

    /// Index a single diary entry into the vector store.
    func indexEntry(_ entry: DiaryEntry) {
        // Skip if already indexed
        guard !vectorStore.contains(where: { $0.entryID == entry.id }) else { return }

        // Build text for embedding: summary + topics
        let text = entry.summary + " " + entry.topics.joined(separator: " ")
        guard let vector = computeEmbedding(for: text) else { return }

        let indexed = IndexedEntry(
            entryID: entry.id,
            vector: vector,
            summary: entry.summary,
            date: entry.createdAt,
            moodEmoji: entry.moodEmoji,
            topics: entry.topics
        )
        vectorStore.append(indexed)
        saveIndex()
        print("[RAG] Indexed entry: \(entry.summary.prefix(30))... (total: \(vectorStore.count))")
    }

    /// Rebuild the entire index from all diary entries.
    func rebuildIndex(entries: [DiaryEntry]) {
        isIndexing = true
        defer { isIndexing = false }

        vectorStore.removeAll()
        print("[RAG] Rebuilding index for \(entries.count) entries...")

        for entry in entries {
            let text = entry.summary + " " + entry.topics.joined(separator: " ")
            guard let vector = computeEmbedding(for: text) else { continue }

            vectorStore.append(IndexedEntry(
                entryID: entry.id,
                vector: vector,
                summary: entry.summary,
                date: entry.createdAt,
                moodEmoji: entry.moodEmoji,
                topics: entry.topics
            ))
        }

        saveIndex()
        print("[RAG] Index rebuilt: \(vectorStore.count) entries indexed")
    }

    // MARK: - Persistence

    func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else {
            print("[RAG] No existing index file found")
            return
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            vectorStore = try JSONDecoder().decode([IndexedEntry].self, from: data)
            print("[RAG] Loaded index: \(vectorStore.count) entries")
        } catch {
            print("[RAG] Failed to load index: \(error)")
            vectorStore = []
        }
    }

    func saveIndex() {
        do {
            let data = try JSONEncoder().encode(vectorStore)
            try data.write(to: indexFileURL, options: .atomic)
        } catch {
            print("[RAG] Failed to save index: \(error)")
        }
    }
}
