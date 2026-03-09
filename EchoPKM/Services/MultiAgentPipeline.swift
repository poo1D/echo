import Foundation
import SwiftData

/// Orchestrates 4 independent LLM Agents: 3 parallel analysis + 1 streaming synthesis
@Observable @MainActor
final class MultiAgentPipeline {

    // MARK: - Agent Result Types

    struct EmotionResult {
        let emotion: String
        let intensity: Int
        let moodScore: Int
        let needs: [String]
    }

    struct MemoryResult {
        let relevant: [(date: Date, summary: String, moodEmoji: String?, reason: String)]
        let patterns: [String]
    }

    struct ActionResult {
        let schedules: [ExtractedSchedule]
        let habits: [String]
        let goals: [String]
    }

    struct ExtractedSchedule {
        let title: String
        let date: Date
        let notes: String?
    }

    struct PipelineResult {
        let emotion: EmotionResult
        let memory: MemoryResult
        let action: ActionResult
        let response: String
        let richCards: [RichContent]
        let ragResults: [RAGService.RAGResult]
    }

    // MARK: - Pipeline State (drives UI updates)

    var ragStatus: PipelineSnapshot.AgentStatus = .idle
    var emotionStatus: PipelineSnapshot.AgentStatus = .idle
    var memoryStatus: PipelineSnapshot.AgentStatus = .idle
    var actionStatus: PipelineSnapshot.AgentStatus = .idle
    var synthesisStatus: PipelineSnapshot.AgentStatus = .idle
    var isRunning = false

    var snapshot: PipelineSnapshot {
        PipelineSnapshot(
            ragStatus: ragStatus,
            emotionStatus: emotionStatus,
            memoryStatus: memoryStatus,
            actionStatus: actionStatus,
            synthesisStatus: synthesisStatus
        )
    }

    // MARK: - Core Pipeline

    func process(
        userMessage: String,
        photoFileNames: [String] = [],
        videoFileNames: [String] = [],
        location: PendingLocation? = nil,
        recentEntries: [DiaryEntry],
        allEntries: [DiaryEntry],
        schedules: [ScheduleItem],
        habits: [HabitEntry],
        modelContext: ModelContext,
        chatService: ChatService,
        ragService: RAGService,
        onSynthesisDelta: @escaping (String) -> Void
    ) async -> PipelineResult {
        isRunning = true
        defer { isRunning = false }

        // Build enriched message text (append location like old flow)
        var enrichedMessage = userMessage
        if let loc = location {
            enrichedMessage += "\n[用户当前位置: \(loc.name)]"
        }
        if !photoFileNames.isEmpty {
            enrichedMessage += "\n[用户附带了 \(photoFileNames.count) 张图片]"
        }
        if !videoFileNames.isEmpty {
            enrichedMessage += "\n[用户附带了 \(videoFileNames.count) 个视频]"
        }

        // Phase 0: RAG Retrieval (on-device, no API call)
        ragStatus = .running
        let ragStartTime = CFAbsoluteTimeGetCurrent()
        let ragResults = ragService.search(query: enrichedMessage, topK: 5)
        let ragDuration = CFAbsoluteTimeGetCurrent() - ragStartTime
        ragStatus = .completed("\(ragResults.count)条语义匹配 (\(String(format: "%.2fs", ragDuration)))")

        // Build Memory Agent input from RAG results (not raw 20 entries)
        let ragEntrySummaries: [(String, String, String)] = ragResults.map { result in
            let dateStr = result.date.formatted(date: .abbreviated, time: .shortened)
            let mood = result.moodEmoji ?? ""
            let topics = result.topics.joined(separator: ", ")
            return (dateStr, mood, "\(result.summary) (topics: \(topics)) [相似度: \(String(format: "%.0f%%", result.score * 100))]")
        }

        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let habitNames = habits.filter { $0.date >= weekStart }.map(\.name)
        var habitCounts: [String: Int] = [:]
        for name in habitNames { habitCounts[name, default: 0] += 1 }
        let habitContextStr = habitCounts.map { "\($0.key): \($0.value) times this week" }.joined(separator: ", ")

        // Phase 1: Three Agents in parallel (async let) with slight stagger to avoid 429
        emotionStatus = .running
        memoryStatus = .running
        actionStatus = .running

        async let emotionTask = runEmotionAgent(enrichedMessage, chatService: chatService)
        async let memoryTask = runMemoryAgentStaggered(enrichedMessage, entrySummaries: ragEntrySummaries, chatService: chatService)
        async let actionTask = runActionAgentStaggered(enrichedMessage, habitContext: habitContextStr, chatService: chatService)

        let emotion = await emotionTask
        let memory = await memoryTask
        let action = await actionTask

        // Phase 2: Execute actions (write to SwiftData)
        executeActions(action, modelContext: modelContext)

        // Phase 3: Synthesis Agent (streaming)
        synthesisStatus = .running
        let synthesisRaw = await runSynthesisAgent(
            userMessage: enrichedMessage,
            photoFileNames: photoFileNames,
            videoFileNames: videoFileNames,
            emotion: emotion,
            memory: memory,
            action: action,
            ragResults: ragResults,
            context: recentEntries,
            habits: habits,
            chatService: chatService,
            onDelta: onSynthesisDelta
        )
        synthesisStatus = .completed("Done")

        // Parse rich cards from synthesis output
        let parsed = ToolCallParser.parse(synthesisRaw)
        let richCards = parsed.cards

        return PipelineResult(
            emotion: emotion,
            memory: memory,
            action: action,
            response: parsed.cleanText,
            richCards: richCards,
            ragResults: ragResults
        )
    }

    func reset() {
        ragStatus = .idle
        emotionStatus = .idle
        memoryStatus = .idle
        actionStatus = .idle
        synthesisStatus = .idle
        isRunning = false
    }

    // MARK: - Staggered wrappers (avoid API 429 rate limiting)

    private func runMemoryAgentStaggered(_ message: String, entrySummaries: [(String, String, String)], chatService: ChatService) async -> MemoryResult {
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay
        return await runMemoryAgent(message, entrySummaries: entrySummaries, chatService: chatService)
    }

    private func runActionAgentStaggered(_ message: String, habitContext: String, chatService: ChatService) async -> ActionResult {
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s delay
        return await runActionAgent(message, habitContext: habitContext, chatService: chatService)
    }

    // MARK: - Emotion Agent

    private func runEmotionAgent(_ message: String, chatService: ChatService) async -> EmotionResult {
        let systemPrompt = """
        你是情绪分析专家。分析用户消息中的情绪内容。
        仅返回一个 JSON 对象（不要 markdown，不要多余文字）：
        {
          "emotion": "主要情绪（如：开心、压力大、焦虑、平静、兴奋、难过、沮丧）",
          "intensity": 1到5的整数,
          "moodScore": 1到5的整数（1=非常消极, 5=非常积极）,
          "needs": ["情绪需求，如：安慰、认可、庆祝、建议"]
        }
        """

        do {
            let response = try await chatService.callAgent(systemPrompt: systemPrompt, userContent: message)
            let cleaned = response
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Try direct parse
            var jsonStr = cleaned
            if let data = jsonStr.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let result = EmotionResult(
                    emotion: obj["emotion"] as? String ?? "neutral",
                    intensity: obj["intensity"] as? Int ?? 3,
                    moodScore: obj["moodScore"] as? Int ?? 3,
                    needs: obj["needs"] as? [String] ?? []
                )
                emotionStatus = .completed("\(result.emotion) \(result.intensity)/5")
                return result
            }

            // Fallback: extract JSON from within response text
            if let start = cleaned.firstIndex(of: "{"),
               let end = cleaned.lastIndex(of: "}") {
                jsonStr = String(cleaned[start...end])
                if let data = jsonStr.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let result = EmotionResult(
                        emotion: obj["emotion"] as? String ?? "neutral",
                        intensity: obj["intensity"] as? Int ?? 3,
                        moodScore: obj["moodScore"] as? Int ?? 3,
                        needs: obj["needs"] as? [String] ?? []
                    )
                    emotionStatus = .completed("\(result.emotion) \(result.intensity)/5")
                    return result
                }
            }

            print("Emotion Agent: JSON parse failed. Raw: \(cleaned.prefix(200))")
            emotionStatus = .completed("neutral 3/5")
            return EmotionResult(emotion: "neutral", intensity: 3, moodScore: 3, needs: [])
        } catch {
            print("Emotion Agent error: \(error)")
            emotionStatus = .completed("neutral 3/5")
            return EmotionResult(emotion: "neutral", intensity: 3, moodScore: 3, needs: [])
        }
    }

    // MARK: - Memory Agent

    private func runMemoryAgent(_ message: String, entrySummaries: [(String, String, String)], chatService: ChatService) async -> MemoryResult {
        // Build diary history context from RAG-filtered results
        let historyText = entrySummaries.map { (dateStr, mood, summary) in
            "[\(dateStr)] \(mood) \(summary)"
        }.joined(separator: "\n")

        let systemPrompt = """
        你是深度记忆分析专家。以下是通过语义检索（RAG）从用户日记中找到的最相关条目。
        这些条目已经过向量相似度筛选，请进行深层分析。

        语义检索结果：
        \(historyText.isEmpty ? "无相关条目" : historyText)

        仅返回一个 JSON 对象（不要 markdown，不要多余文字）：
        {
          "relevant": [
            {"date": "YYYY-MM-DD", "summary": "条目摘要", "moodEmoji": "表情或null", "reason": "深层关联原因"}
          ],
          "patterns": ["深层规律描述"]
        }

        深层分析要求：
        - 分析条目之间的因果链（A导致B导致C）
        - 识别时间规律（每周几、什么时间段的情绪变化）
        - 发现情绪触发器和恢复模式
        - reason 字段要解释深层关联，而非简单的主题匹配
        - 最多返回3条最相关的条目
        - 如果没有深层关联，返回空数组
        """

        do {
            let response = try await chatService.callAgent(systemPrompt: systemPrompt, userContent: message)
            let cleaned = response
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Try parsing JSON (direct or extracted from text)
            var jsonStr = cleaned
            var obj: [String: Any]?

            if let data = jsonStr.data(using: .utf8) {
                obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }

            if obj == nil, let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
                jsonStr = String(cleaned[start...end])
                if let data = jsonStr.data(using: .utf8) {
                    obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
            }

            if let obj {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withFullDate]

                var relevant: [(date: Date, summary: String, moodEmoji: String?, reason: String)] = []
                if let entries = obj["relevant"] as? [[String: Any]] {
                    for entry in entries {
                        let dateStr = entry["date"] as? String ?? ""
                        let date = isoFormatter.date(from: dateStr) ?? Date()
                        let summary = entry["summary"] as? String ?? ""
                        let mood = entry["moodEmoji"] as? String
                        let reason = entry["reason"] as? String ?? ""
                        relevant.append((date: date, summary: summary, moodEmoji: mood, reason: reason))
                    }
                }

                let patterns = obj["patterns"] as? [String] ?? []
                let result = MemoryResult(relevant: relevant, patterns: patterns)
                memoryStatus = .completed("\(relevant.count) related")
                return result
            }

            print("Memory Agent: JSON parse failed. Raw: \(cleaned.prefix(200))")
            memoryStatus = .completed("0 related")
            return MemoryResult(relevant: [], patterns: [])
        } catch {
            print("Memory Agent error: \(error)")
            memoryStatus = .completed("0 related")
            return MemoryResult(relevant: [], patterns: [])
        }
    }

    // MARK: - Action Agent

    private func runActionAgent(_ message: String, habitContext: String, chatService: ChatService) async -> ActionResult {
        let today = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let todayStr = isoFormatter.string(from: today)

        let systemPrompt = """
        你是行动提取专家。分析用户消息，提取可执行的行动项。
        今天的日期是 \(todayStr)。
        本周已记录的习惯：\(habitContext.isEmpty ? "无" : habitContext)

        仅返回一个 JSON 对象（不要 markdown，不要多余文字）：
        {
          "schedules": [
            {"title": "事件名称", "date": "YYYY-MM-DD", "notes": "可选的备注"}
          ],
          "habits": ["提到的活动名称（如：跑步、阅读、做饭、散步、健身）"],
          "goals": ["提到的目标或意向"]
        }

        规则：
        - schedules：未来的计划、约会、会议、截止日期。从上下文推断具体日期。
          例如"下周三"就计算出具体的 YYYY-MM-DD 日期。
        - habits：用户已经做了或正在做的活动（跑步、做饭、阅读、散步、冥想等）
        - goals：愿望或意图（不是具体的日程事件）
        - 如果没有找到任何内容，返回空数组
        - 用中文填写 title 和 notes
        """

        do {
            let response = try await chatService.callAgent(systemPrompt: systemPrompt, userContent: message)
            return parseActionResponse(response, isoFormatter: isoFormatter)
        } catch {
            print("Action Agent error: \(error)")
            actionStatus = .completed("None")
            return ActionResult(schedules: [], habits: [], goals: [])
        }
    }

    /// Resilient JSON parsing for Action Agent — never returns .failed if API succeeded
    private func parseActionResponse(_ response: String, isoFormatter: ISO8601DateFormatter) -> ActionResult {
        print("Action Agent raw response: \(response.prefix(500))")

        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            print("Action Agent: cannot convert response to data")
            actionStatus = .completed("None")
            return ActionResult(schedules: [], habits: [], goals: [])
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Try to extract JSON from within the response (LLM might add text around it)
            if let jsonStart = cleaned.firstIndex(of: "{"),
               let jsonEnd = cleaned.lastIndex(of: "}") {
                let jsonSubstr = String(cleaned[jsonStart...jsonEnd])
                if let subData = jsonSubstr.data(using: .utf8),
                   let subObj = try? JSONSerialization.jsonObject(with: subData) as? [String: Any] {
                    return extractActionFromJSON(subObj, isoFormatter: isoFormatter)
                }
            }
            print("Action Agent: JSON parse failed. Raw response: \(cleaned.prefix(200))")
            actionStatus = .completed("None")
            return ActionResult(schedules: [], habits: [], goals: [])
        }

        return extractActionFromJSON(obj, isoFormatter: isoFormatter)
    }

    private func extractActionFromJSON(_ obj: [String: Any], isoFormatter: ISO8601DateFormatter) -> ActionResult {
        var extractedSchedules: [ExtractedSchedule] = []
        if let schedules = obj["schedules"] as? [[String: Any]] {
            for s in schedules {
                guard let title = s["title"] as? String,
                      let dateStr = s["date"] as? String else { continue }
                // Try multiple date formats
                let date = isoFormatter.date(from: dateStr)
                    ?? parseFlexibleDate(dateStr)
                guard let parsedDate = date else {
                    print("Action Agent: cannot parse date '\(dateStr)' for '\(title)'")
                    continue
                }
                let notes = s["notes"] as? String
                extractedSchedules.append(ExtractedSchedule(title: title, date: parsedDate, notes: notes))
            }
        }

        let extractedHabits = obj["habits"] as? [String] ?? []
        let goals = obj["goals"] as? [String] ?? []

        var summaryParts: [String] = []
        if !extractedSchedules.isEmpty { summaryParts.append("\(extractedSchedules.count) schedule(s)") }
        if !extractedHabits.isEmpty { summaryParts.append("\(extractedHabits.count) habit(s)") }
        let summary = summaryParts.isEmpty ? "None" : summaryParts.joined(separator: " + ")

        actionStatus = .completed(summary)
        return ActionResult(schedules: extractedSchedules, habits: extractedHabits, goals: goals)
    }

    /// Try common date formats beyond ISO8601
    private func parseFlexibleDate(_ str: String) -> Date? {
        let formatters: [String] = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy.MM.dd",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
        ]
        for fmt in formatters {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: str) { return date }
        }
        return nil
    }

    // MARK: - Execute Actions (SwiftData)

    private func executeActions(_ action: ActionResult, modelContext: ModelContext) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        for schedule in action.schedules {
            let item = ScheduleItem(
                title: schedule.title,
                date: schedule.date,
                notes: schedule.notes
            )
            modelContext.insert(item)
        }

        for habitName in action.habits {
            let habit = HabitEntry(
                name: habitName,
                date: Date()
            )
            modelContext.insert(habit)
        }

        if !action.schedules.isEmpty || !action.habits.isEmpty {
            try? modelContext.save()
        }
    }

    // MARK: - Synthesis Agent (streaming)

    private func runSynthesisAgent(
        userMessage: String,
        photoFileNames: [String] = [],
        videoFileNames: [String] = [],
        emotion: EmotionResult,
        memory: MemoryResult,
        action: ActionResult,
        ragResults: [RAGService.RAGResult],
        context: [DiaryEntry],
        habits: [HabitEntry],
        chatService: ChatService,
        onDelta: @escaping (String) -> Void
    ) async -> String {
        // Build habit streak info
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let thisWeekHabits = habits.filter { $0.date >= weekStart }
        var habitCounts: [String: Int] = [:]
        for h in thisWeekHabits { habitCounts[h.name, default: 0] += 1 }

        // Build context string
        let recentContext = context.prefix(5).map { entry in
            let dateStr = entry.createdAt.formatted(date: .abbreviated, time: .shortened)
            return "[\(dateStr)] \(entry.moodEmoji ?? "") \(entry.summary)"
        }.joined(separator: "\n")

        let memoryContext = memory.relevant.map { m in
            "\(m.summary) (reason: \(m.reason))"
        }.joined(separator: "\n")

        let habitStreakInfo = habitCounts.map { name, count in
            let emoji = HabitStreakData.emojiFor(name)
            return "\(emoji) \(name): \(count) times this week"
        }.joined(separator: "\n")

        // Build RAG context string
        let ragContext = ragResults.map { r in
            let dateStr = r.date.formatted(date: .abbreviated, time: .omitted)
            return "[\(dateStr)] \(r.moodEmoji ?? "") \(r.summary) (similarity: \(String(format: "%.0f%%", r.score * 100)))"
        }.joined(separator: "\n")

        let systemPrompt = """
        You are Echo, a warm and insightful penguin diary companion.

        You have access to analysis from three specialized agents and on-device semantic retrieval:

        === SEMANTIC RETRIEVAL (RAG) ===
        Top semantically similar past entries (on-device vector search):
        \(ragContext.isEmpty ? "No similar entries found" : ragContext)

        === EMOTION ANALYSIS ===
        Emotion: \(emotion.emotion) (intensity: \(emotion.intensity)/5, mood score: \(emotion.moodScore)/5)
        Needs: \(emotion.needs.joined(separator: ", "))

        === MEMORY RETRIEVAL ===
        Related memories:
        \(memoryContext.isEmpty ? "None found" : memoryContext)
        Patterns: \(memory.patterns.joined(separator: "; "))

        === ACTION EXTRACTION ===
        Schedules: \(action.schedules.map { "\($0.title) on \($0.date.formatted(date: .abbreviated, time: .omitted))" }.joined(separator: ", "))
        Habits logged: \(action.habits.joined(separator: ", "))
        Goals: \(action.goals.joined(separator: ", "))

        === HABIT STREAKS ===
        \(habitStreakInfo.isEmpty ? "No habits this week" : habitStreakInfo)

        === RECENT DIARY CONTEXT ===
        \(recentContext.isEmpty ? "No recent entries" : recentContext)

        === RESPONSE INSTRUCTIONS ===
        1. Be warm, specific, and proactive
        2. Reference the emotion analysis to be emotionally attuned
        3. If relevant memories were found, reference them naturally
        4. If actions were extracted, confirm them
        5. If habit streaks exist, celebrate progress
        6. Keep response 2-4 sentences
        7. You may include rich content cards using this format:
           <card type="habitStreak">{"name":"exercise","streak":3,"change":1}</card>
           <card type="scheduleConfirm">{"title":"Product Meeting","date":"2026-03-11"}</card>
           <card type="memoryRecall">{"summary":"past entry summary","date":"2026-03-01","reason":"why relevant"}</card>
           <card type="patternInsight">{"pattern":"description","evidence":"data","occurrences":4}</card>
        8. Place cards BEFORE the text response
        9. Only include cards when they add value (don't force them)
        """

        // Build user message — with photos/videos as multimodal content if present
        let messages: [[String: Any]]
        if !photoFileNames.isEmpty || !videoFileNames.isEmpty {
            var contentParts: [[String: Any]] = []
            for fileName in photoFileNames {
                if let base64 = chatService.loadPhotoAsBase64(fileName) {
                    contentParts.append([
                        "type": "image_url",
                        "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                    ])
                }
            }
            for fileName in videoFileNames {
                let frames = chatService.loadVideoFramesAsBase64(fileName)
                for frameBase64 in frames {
                    contentParts.append([
                        "type": "image_url",
                        "image_url": ["url": "data:image/jpeg;base64,\(frameBase64)"]
                    ])
                }
                if !frames.isEmpty {
                    contentParts.append(["type": "text", "text": "[User shared a video]"])
                }
            }
            contentParts.append(["type": "text", "text": userMessage])
            messages = [["role": "user", "content": contentParts]]
        } else {
            messages = [["role": "user", "content": userMessage]]
        }

        do {
            let result = try await chatService.streamAgent(
                systemPrompt: systemPrompt,
                messages: messages,
                onDelta: onDelta
            )
            return result
        } catch {
            print("Synthesis Agent failed: \(error)")
            return "I hear you! \(emotion.emotion == "happy" ? "That's great to hear!" : "I'm here for you.") Tell me more about what's going on."
        }
    }
}
