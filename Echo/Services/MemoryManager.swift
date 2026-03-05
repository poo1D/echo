import Foundation
import SwiftData

/// 记忆管理核心服务 — 协调写入管线和检索管线
/// 负责日记保存后的记忆提取、存储，以及对话前的记忆检索与 prompt 增强
@Observable @MainActor
final class MemoryManager {
    
    static let shared = MemoryManager()
    
    private let vectorStore = VectorStore.shared
    private let factExtractor = FactExtractor.shared
    
    var isProcessing = false
    var lastProcessedEntryID: UUID?
    
    private init() {}
    
    // MARK: - 写入管线
    
    /// 处理新保存的日记 — 完整的写入管线
    /// 1. 生成 embedding 并存储
    /// 2. 提取结构化事实
    /// 3. 提取情绪评分（更新用户档案）
    func processJournalEntry(_ entry: JournalEntry, modelContext: ModelContext) async {
        guard !entry.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        print("🧠 [MemoryManager] 开始处理日记: \(entry.id)")
        
        // Step 1: 生成 embedding 并存储
        await storeEmbedding(for: entry, modelContext: modelContext)
        
        // Step 2: 提取结构化事实
        await extractAndStoreFacts(from: entry, modelContext: modelContext)
        
        // Step 3: 更新用户档案基础数据
        await updateUserProfile(with: entry, modelContext: modelContext)
        
        // Step 4: 聚合偏好/关切到用户档案
        await aggregateProfileInsights(modelContext: modelContext)
        
        // Step 5: 记忆维护（衰减 + 清理）
        performMemoryMaintenance(modelContext: modelContext)
        
        // 保存所有变更
        try? modelContext.save()
        
        lastProcessedEntryID = entry.id
        print("✅ [MemoryManager] 日记处理完成: \(entry.id)")
    }
    
    // MARK: - Step 1: Embedding 存储
    
    private func storeEmbedding(for entry: JournalEntry, modelContext: ModelContext) async {
        guard let vector = vectorStore.generateEmbedding(for: entry.textContent) else {
            print("⚠️ [MemoryManager] 无法生成 embedding")
            return
        }
        
        // 检查是否已存在该日记的 embedding，避免重复
        let entryID = entry.id
        let descriptor = FetchDescriptor<JournalEmbedding>(
            predicate: #Predicate { $0.entryID == entryID }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            // 更新已有的
            let newData = vector.withUnsafeBufferPointer { Data(buffer: $0) }
            existing.embeddingData = newData
            existing.textPreview = String(entry.textContent.prefix(100))
            print("🔄 [MemoryManager] 更新已有 embedding")
        } else {
            // 新建
            let embedding = JournalEmbedding(
                entryID: entry.id,
                embedding: vector,
                textPreview: String(entry.textContent.prefix(100))
            )
            modelContext.insert(embedding)
            print("📥 [MemoryManager] 存储新 embedding")
        }
    }
    
    // MARK: - Step 2: 事实提取
    
    private func extractAndStoreFacts(from entry: JournalEntry, modelContext: ModelContext) async {
        let facts = await factExtractor.extractFacts(
            from: entry.textContent,
            entryID: entry.id
        )
        
        for fact in facts {
            // 检查是否已存在相似内容的事实（简单去重）
            if !isDuplicateFact(fact, modelContext: modelContext) {
                modelContext.insert(fact)
            }
        }
        
        print("📝 [MemoryManager] 存储 \(facts.count) 条新事实")
    }
    
    /// 简单去重：检查是否已存在内容高度相似的事实
    private func isDuplicateFact(_ newFact: FactMemory, modelContext: ModelContext) -> Bool {
        let category = newFact.category
        let content = newFact.content
        let descriptor = FetchDescriptor<FactMemory>(
            predicate: #Predicate {
                $0.category == category && $0.content == content
            }
        )
        
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        return !existing.isEmpty
    }
    
    // MARK: - Step 3: 用户档案更新
    
    private func updateUserProfile(with entry: JournalEntry, modelContext: ModelContext) async {
        let profile = getOrCreateProfile(modelContext: modelContext)
        
        // 更新日记计数
        profile.totalJournalCount += 1
        profile.lastJournalDate = entry.createdAt
        
        // 提取情绪评分
        if let moodScore = await factExtractor.extractMoodScore(from: entry.textContent) {
            updateMoodBaseline(profile: profile, newScore: moodScore, modelContext: modelContext)
        }
        
        profile.updatedAt = Date()
    }
    
    /// 更新情绪基线（滑动平均）
    private func updateMoodBaseline(profile: UserProfile, newScore: Double, modelContext: ModelContext) {
        if let currentAvg = profile.averageMoodScore {
            // 指数移动平均 (EMA)，alpha = 0.2，让近期情绪权重更高
            let alpha = 0.2
            profile.averageMoodScore = alpha * newScore + (1 - alpha) * currentAvg
        } else {
            profile.averageMoodScore = newScore
        }
        
        // 更新趋势（需要至少 5 篇日记才有意义）
        if profile.totalJournalCount >= 5 {
            if let avg = profile.averageMoodScore {
                if newScore > avg + 1 {
                    profile.moodTrend = "improving"
                } else if newScore < avg - 1 {
                    profile.moodTrend = "declining"
                } else {
                    profile.moodTrend = "stable"
                }
            }
        }
    }
    
    // MARK: - Step 4: 偏好/关切自动聚合
    
    /// 从 FactMemory 自动聚合用户偏好和关切到 UserProfile
    private func aggregateProfileInsights(modelContext: ModelContext) async {
        let profile = getOrCreateProfile(modelContext: modelContext)
        
        // 每 5 篇日记才聚合一次，避免频繁计算
        guard profile.totalJournalCount % 5 == 0 else { return }
        
        let descriptor = FetchDescriptor<FactMemory>()
        guard let allFacts = try? modelContext.fetch(descriptor), !allFacts.isEmpty else { return }
        
        // 聚合偏好：habit + preference 类事实
        let preferenceFacts = allFacts.filter {
            $0.category == FactMemory.Category.habit ||
            $0.category == FactMemory.Category.preference
        }
        
        // 按内容分组计数，频次≥2 或 importance≥4 纳入
        var prefCounts: [String: (count: Int, maxImportance: Int)] = [:]
        for fact in preferenceFacts {
            let key = fact.content
            let existing = prefCounts[key] ?? (count: 0, maxImportance: 0)
            prefCounts[key] = (count: existing.count + 1, maxImportance: max(existing.maxImportance, fact.importance))
        }
        
        profile.preferences = prefCounts
            .filter { $0.value.count >= 2 || $0.value.maxImportance >= 4 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(10)
            .map { $0.key }
        
        // 聚合关切：低情绪相关的 event 类事实
        let concernFacts = allFacts.filter {
            $0.category == FactMemory.Category.event && $0.importance >= 3
        }
        // 找出负面关键词的事实作为关切
        let negativeKeywords = ["压力", "焦虑", "累", "难过", "生气", "失眠", "烦", "担心", "紧张", "孤独"]
        profile.concerns = concernFacts
            .filter { fact in
                negativeKeywords.contains { fact.content.contains($0) || fact.keywords.contains($0) }
            }
            .sorted { $0.importance > $1.importance }
            .prefix(5)
            .map { $0.content }
        
        // 每 5 篇日记用 LLM 生成用户总结
        if profile.totalJournalCount % 5 == 0 {
            await generatePersonalSummary(profile: profile, facts: allFacts)
        }
        
        print("📊 [MemoryManager] 档案聚合完成: \(profile.preferences.count) 偏好, \(profile.concerns.count) 关切")
    }
    
    /// LLM 生成用户个人总结
    private func generatePersonalSummary(profile: UserProfile, facts: [FactMemory]) async {
        let topFacts = facts
            .sorted { $0.accessScore > $1.accessScore }
            .prefix(15)
            .map { "[\($0.category)] \($0.content)" }
            .joined(separator: "\n")
        
        let prompt = """
        基于以下用户的记忆信息，用一段话（50-80字）总结这个用户的特点：
        
        \(topFacts)
        
        偏好：\(profile.preferences.joined(separator: "、"))
        关切：\(profile.concerns.joined(separator: "、"))
        
        只返回总结文本，不要其他内容。
        """
        
        do {
            guard let url = URL(string: APIConfig.apiEndpoint) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(APIConfig.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "model": "moonshotai/Kimi-K2.5",
                "messages": [["role": "user", "content": prompt]],
                "max_tokens": 200,
                "temperature": 0.5
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                profile.personalSummary = content.trimmingCharacters(in: .whitespacesAndNewlines)
                print("✨ [MemoryManager] 生成用户总结: \(content.prefix(50))...")
            }
        } catch {
            print("⚠️ [MemoryManager] 生成用户总结失败: \(error)")
        }
    }
    
    // MARK: - Step 5: 记忆衰减与维护
    
    /// 清理低价值、长期未访问的记忆
    private func performMemoryMaintenance(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<FactMemory>()
        guard let allFacts = try? modelContext.fetch(descriptor) else { return }
        
        let now = Date()
        var deletedCount = 0
        
        for fact in allFacts {
            let refDate = fact.lastReferencedAt ?? fact.createdAt
            let daysSinceRef = now.timeIntervalSince(refDate) / 86400
            
            // importance=1 且 30天未引用 → 删除
            if fact.importance <= 1 && daysSinceRef > 30 {
                modelContext.delete(fact)
                deletedCount += 1
                continue
            }
            
            // importance=2 且 90天未引用 → 删除
            if fact.importance == 2 && daysSinceRef > 90 {
                modelContext.delete(fact)
                deletedCount += 1
                continue
            }
            
            // importance>=3 → 永不自动删除
        }
        
        if deletedCount > 0 {
            print("🧹 [MemoryManager] 清理 \(deletedCount) 条低价值记忆")
        }
    }
    
    // MARK: - 检索管线
    
    /// 检索与查询相关的记忆上下文 — 用于增强 prompt
    func retrieveContext(
        for query: String,
        modelContext: ModelContext,
        topK: Int = 5
    ) async -> MemoryContext {
        let profile = getOrCreateProfile(modelContext: modelContext)
        
        // L2: 关键词匹配事实记忆
        let relevantFacts = searchFacts(query: query, modelContext: modelContext)
        
        // L3: 语义检索相关日记
        let relevantEntries = await searchSimilarEntries(
            query: query,
            modelContext: modelContext,
            topK: topK
        )
        
        // L4: 最近日记（近 7 天）
        let recentEntries = fetchRecentEntries(days: 7, modelContext: modelContext)
        
        // 更新被引用事实的引用计数
        for fact in relevantFacts {
            fact.referenceCount += 1
            fact.lastReferencedAt = Date()
        }
        try? modelContext.save()
        
        return MemoryContext(
            userProfile: profile,
            relevantFacts: relevantFacts,
            relevantEntries: relevantEntries,
            recentEntries: recentEntries
        )
    }
    
    /// 将记忆上下文组装为增强 prompt 文本
    func buildAugmentedSystemPrompt(context: MemoryContext, basePrompt: String) -> String {
        var augmented = basePrompt + "\n\n"
        
        // L1: 用户档案
        augmented += "## 用户档案\n"
        augmented += context.userProfile.toPromptText()
        augmented += "\n\n"
        
        // L2: 相关事实
        if !context.relevantFacts.isEmpty {
            augmented += "## 你记得的关于用户的事实\n"
            for fact in context.relevantFacts.prefix(8) {
                augmented += "- [\(fact.category)] \(fact.content)\n"
            }
            augmented += "\n"
        }
        
        // L3: 相关历史日记
        if !context.relevantEntries.isEmpty {
            augmented += "## 相关的历史日记片段\n"
            for (entry, similarity) in context.relevantEntries.prefix(3) {
                let dateStr = formatDate(entry.createdAt)
                let preview = String(entry.textContent.prefix(150))
                augmented += "- [\(dateStr), 相关度\(String(format: "%.0f%%", similarity * 100))] \(preview)\n"
            }
            augmented += "\n"
        }
        
        // L4: 最近日记概要
        if !context.recentEntries.isEmpty {
            augmented += "## 最近7天的日记概要\n"
            for entry in context.recentEntries.prefix(5) {
                let dateStr = formatDate(entry.createdAt)
                let preview = String(entry.textContent.prefix(80))
                augmented += "- [\(dateStr)] \(preview)\n"
            }
            augmented += "\n"
        }
        
        augmented += """
        ## 记忆使用规则
        - 自然地引用上述记忆，不要生硬地列举
        - 如果记忆与当前话题相关，适当提及（如"上次你也提到过..."）
        - 不要编造用户没说过的事情
        - 优先关注用户当前的情绪和需求
        """
        
        return augmented
    }
    
    // MARK: - 搜索辅助
    
    /// L2: BM25-lite 加权搜索事实记忆
    /// score = matchCount × importance × recencyBoost × (1 + log(refCount + 1))
    private func searchFacts(query: String, modelContext: ModelContext) -> [FactMemory] {
        let queryKeywords = extractKeywords(from: query)
        guard !queryKeywords.isEmpty else { return [] }
        
        let descriptor = FetchDescriptor<FactMemory>()
        guard let allFacts = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        let now = Date()
        let scored = allFacts.compactMap { fact -> (FactMemory, Double)? in
            let matchCount = queryKeywords.filter { keyword in
                fact.content.localizedCaseInsensitiveContains(keyword) ||
                fact.keywords.contains { $0.localizedCaseInsensitiveContains(keyword) }
            }.count
            
            guard matchCount > 0 else { return nil }
            
            // BM25-lite 评分
            let importanceWeight = Double(fact.importance)
            
            let refDate = fact.lastReferencedAt ?? fact.createdAt
            let daysSinceRef = now.timeIntervalSince(refDate) / 86400
            let recencyBoost: Double = daysSinceRef <= 7 ? 2.0 : (daysSinceRef <= 30 ? 1.5 : 1.0)
            
            let refBoost = 1.0 + log(Double(fact.referenceCount + 1))
            
            let score = Double(matchCount) * importanceWeight * recencyBoost * refBoost
            return (fact, score)
        }
        
        return scored
            .filter { $0.1 > 1.0 }  // 最低阈值过滤噪声
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { $0.0 }
    }
    
    /// L3: 基于语义相似度搜索历史日记
    private func searchSimilarEntries(
        query: String,
        modelContext: ModelContext,
        topK: Int
    ) async -> [(entry: JournalEntry, similarity: Float)] {
        guard let queryVector = vectorStore.generateEmbedding(for: query) else {
            return []
        }
        
        // 加载所有日记 embeddings
        let embDescriptor = FetchDescriptor<JournalEmbedding>()
        guard let allEmbeddings = try? modelContext.fetch(embDescriptor) else {
            return []
        }
        
        let candidates = allEmbeddings.map { emb in
            (id: emb.entryID, vector: emb.getEmbedding())
        }
        
        // 向量搜索
        let searchResults = vectorStore.search(
            queryVector: queryVector,
            candidates: candidates,
            topK: topK
        )
        
        // 关联回 JournalEntry 对象
        var results: [(entry: JournalEntry, similarity: Float)] = []
        for result in searchResults {
            let entryID = result.id
            let entryDescriptor = FetchDescriptor<JournalEntry>(
                predicate: #Predicate { $0.id == entryID }
            )
            if let entry = try? modelContext.fetch(entryDescriptor).first {
                results.append((entry: entry, similarity: result.similarity))
            }
        }
        
        return results
    }
    
    /// L4: 获取最近 N 天的日记
    private func fetchRecentEntries(days: Int, modelContext: ModelContext) -> [JournalEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - 用户档案管理
    
    /// 获取或创建用户档案（确保始终有一个唯一的 UserProfile）
    func getOrCreateProfile(modelContext: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        let profile = UserProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }
    
    // MARK: - 工具方法
    
    /// 简易分词（提取有意义的关键词）
    private func extractKeywords(from text: String) -> [String] {
        // 按常见分隔符拆分，过滤短词
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
        
        return text
            .components(separatedBy: separators)
            .filter { $0.count >= 2 }  // 至少2个字符
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 记忆上下文数据结构

struct MemoryContext {
    let userProfile: UserProfile
    let relevantFacts: [FactMemory]
    let relevantEntries: [(entry: JournalEntry, similarity: Float)]
    let recentEntries: [JournalEntry]
    
    var isEmpty: Bool {
        relevantFacts.isEmpty && relevantEntries.isEmpty && recentEntries.isEmpty
    }
}
