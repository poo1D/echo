import Foundation
import UIKit
import AVFoundation

/// Minimal LLM chat client with SSE streaming — talks to ModelScope Kimi-K2.5
@Observable @MainActor
final class ChatService {
    // MARK: - Types

    struct Message: Codable, Identifiable {
        let id: UUID
        let role: Role
        var content: String
        let timestamp: Date
        var photoFileNames: [String]
        var videoFileNames: [String]

        enum Role: String, Codable {
            case user, assistant, system
        }

        init(role: Role, content: String, photoFileNames: [String] = [], videoFileNames: [String] = []) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
            self.photoFileNames = photoFileNames
            self.videoFileNames = videoFileNames
        }
    }

    // MARK: - State

    var messages: [Message] = []
    var isStreaming = false
    var errorMessage: String?

    // MARK: - API Config

    private let apiEndpoint = "https://api-inference.modelscope.cn/v1/chat/completions"

    private var apiKey: String {
        let key = APIConfig.modelScopeAPIKey
        if !key.isEmpty { return key }
        if let key = ProcessInfo.processInfo.environment["MODELSCOPE_API_KEY"], !key.isEmpty {
            return key
        }
        return ""
    }

    // MARK: - Model Rotation

    /// Index into APIConfig.models, persisted across launches.
    private var currentModelIndex: Int {
        get { UserDefaults.standard.integer(forKey: APIConfig.modelIndexKey) }
        set { UserDefaults.standard.set(newValue, forKey: APIConfig.modelIndexKey) }
    }

    /// Returns the model to use for the current request.
    /// If vision is required and the current model doesn't support it,
    /// falls back to the first vision-capable model in the pool.
    private func selectModel(requiresVision: Bool) -> APIConfig.ModelConfig {
        let pool = requiresVision ? APIConfig.models.filter(\.supportsVision) : APIConfig.models
        guard !pool.isEmpty else { return APIConfig.models[0] }
        let current = APIConfig.models[currentModelIndex % APIConfig.models.count]
        // If current model satisfies the requirement, use it.
        if pool.contains(where: { $0.id == current.id }) { return current }
        // Otherwise use the first eligible model.
        return pool[0]
    }

    /// Advances currentModelIndex to the next eligible model.
    /// Skips vision-only models when requiresVision is false if possible,
    /// but never leaves fewer than 1 option.
    private func rotateModel(requiresVision: Bool) {
        let pool = requiresVision ? APIConfig.models.filter(\.supportsVision) : APIConfig.models
        guard pool.count > 1 else { return }
        let current = APIConfig.models[currentModelIndex % APIConfig.models.count]
        // Find current position in eligible pool, advance by 1
        let currentPoolIdx = pool.firstIndex(where: { $0.id == current.id }) ?? 0
        let nextPoolIdx = (currentPoolIdx + 1) % pool.count
        // Map back to index in the full models array
        if let nextGlobalIdx = APIConfig.models.firstIndex(where: { $0.id == pool[nextPoolIdx].id }) {
            currentModelIndex = nextGlobalIdx
            print("[ModelRotation] Switched to: \(pool[nextPoolIdx].displayName)")
        }
    }

    // MARK: - System Prompt

    private let baseSystemPrompt = """
    You are Echo, a warm and insightful penguin diary companion. The user is chatting with you, \
    and every conversation automatically becomes a diary entry.

    Your role:
    1. Be emotionally attuned — acknowledge feelings genuinely before anything else
    2. ACTIVELY give personalized advice, encouragement, and practical suggestions based on what the user shares
    3. Reference past diary entries naturally ("last Tuesday you mentioned feeling overwhelmed — how's that going?")
    4. Notice mood patterns and gently point them out ("I've noticed you feel more energized on exercise days")
    5. Offer specific, actionable micro-suggestions ("Maybe try a 5-minute walk after lunch? You mentioned it helped before")
    6. Celebrate wins and progress, even small ones ("That's the third time this week you cooked at home — real habit building!")
    7. Keep responses short (2-4 sentences), like chatting with a wise friend who genuinely cares
    8. Naturally confirm plans and appointments the user mentions ("Got it, I've noted your dentist appointment on Thursday")
    9. Point out recurring activity patterns ("You've hit the gym 3 times this week — great consistency!")

    Style: warm, specific, proactive. You are NOT a passive listener — you are a caring companion who \
    actively helps the user live better. Ask follow-up questions that guide reflection. \
    Use occasional emoji naturally. Speak in a way that feels personal, not generic.
    """

    func buildSystemPrompt(recentEntries: [DiaryEntry]) -> String {
        guard !recentEntries.isEmpty else { return baseSystemPrompt }

        let entrySummaries = recentEntries.prefix(7).enumerated().map { index, entry in
            let dateStr = entry.createdAt.formatted(date: .abbreviated, time: .shortened)
            let mood = entry.moodEmoji ?? ""
            let topics = entry.topics.joined(separator: ", ")
            return "[\(dateStr)] \(mood) \(entry.summary) (topics: \(topics))"
        }.joined(separator: "\n")

        return """
        \(baseSystemPrompt)

        --- DIARY CONTEXT (recent entries — reference naturally and proactively) ---
        \(entrySummaries)
        ---
        Use the above context to: spot patterns, reference past events, celebrate progress, \
        and offer advice connected to real things the user has experienced.
        """
    }

    // MARK: - Enhanced System Prompt (3-layer context)

    func buildEnhancedSystemPrompt(recentEntries: [DiaryEntry], allEntries: [DiaryEntry]) -> String {
        // Layer 1: Recent details (up to 7)
        let recentSummaries = recentEntries.prefix(7).map { entry in
            let dateStr = entry.createdAt.formatted(date: .abbreviated, time: .shortened)
            let mood = entry.moodEmoji ?? ""
            let topics = entry.topics.joined(separator: ", ")
            return "[\(dateStr)] \(mood) \(entry.summary) (topics: \(topics))"
        }.joined(separator: "\n")

        // Layer 2: Long-term patterns (entries 8-30)
        let olderEntries = Array(allEntries.dropFirst(7).prefix(23))
        let patternSummary = buildPatternSummary(from: olderEntries)

        // Layer 3: Topic matches from current conversation
        let currentQuery = messages.filter { $0.role == .user }.last?.content ?? ""
        let recentIDs = Set(recentEntries.prefix(7).map(\.id))
        let topicMatches = findTopicMatches(query: currentQuery, in: allEntries, excludingIDs: recentIDs)

        var prompt = """
        \(baseSystemPrompt)

        --- RECENT DIARY ENTRIES (reference naturally and proactively) ---
        \(recentSummaries)
        ---
        """

        if !patternSummary.isEmpty {
            prompt += """

            --- LONG-TERM PATTERNS (from older entries) ---
            \(patternSummary)
            ---
            """
        }

        if !topicMatches.isEmpty {
            prompt += """

            --- RELATED PAST ENTRIES (matched by current topic) ---
            \(topicMatches)
            ---
            """
        }

        prompt += """

        Use ALL context layers to: spot patterns, reference past events, celebrate progress, \
        and offer advice connected to real things the user has experienced.
        """

        return prompt
    }

    private func buildPatternSummary(from entries: [DiaryEntry]) -> String {
        guard !entries.isEmpty else { return "" }

        // Topic frequency
        var topicCounts: [String: Int] = [:]
        var topicMoods: [String: [Int]] = [:]
        for entry in entries {
            for topic in entry.topics {
                let t = topic.lowercased()
                topicCounts[t, default: 0] += 1
                if let score = entry.moodScore {
                    topicMoods[t, default: []].append(score)
                }
            }
        }

        let sorted = topicCounts.sorted { $0.value > $1.value }.prefix(8)
        var lines: [String] = []
        for (topic, count) in sorted {
            let moods = topicMoods[topic] ?? []
            let avgMood = moods.isEmpty ? 3.0 : Double(moods.reduce(0, +)) / Double(moods.count)
            let moodLabel = avgMood >= 4 ? "mostly positive" : avgMood <= 2 ? "mostly stressed" : "mixed"
            lines.append("- \(topic): appeared \(count)x, \(moodLabel)")
        }

        // Overall mood trend
        let scores = entries.compactMap(\.moodScore)
        if !scores.isEmpty {
            let avg = Double(scores.reduce(0, +)) / Double(scores.count)
            lines.append("- Overall mood trend: \(String(format: "%.1f", avg))/5")
        }

        return lines.joined(separator: "\n")
    }

    private func findTopicMatches(query: String, in allEntries: [DiaryEntry], excludingIDs: Set<UUID>) -> String {
        guard !query.isEmpty else { return "" }

        let queryWords = Set(query.lowercased().split(separator: " ")
            .map(String.init)
            .filter { $0.count > 3 })

        guard !queryWords.isEmpty else { return "" }

        var matches: [(entry: DiaryEntry, score: Int)] = []
        for entry in allEntries where !excludingIDs.contains(entry.id) {
            let text = entry.summary.lowercased() + " " + entry.topics.joined(separator: " ").lowercased()
            let entryWords = Set(text.split(separator: " ").map(String.init))
            let overlap = queryWords.intersection(entryWords).count
            if overlap > 0 {
                matches.append((entry, overlap))
            }
        }

        matches.sort { $0.score > $1.score }
        let top = matches.prefix(3)
        guard !top.isEmpty else { return "" }

        return top.map { match in
            let dateStr = match.entry.createdAt.formatted(date: .abbreviated, time: .omitted)
            let mood = match.entry.moodEmoji ?? ""
            return "[\(dateStr)] \(mood) \(match.entry.summary)"
        }.joined(separator: "\n")
    }

    // MARK: - Send Message (SSE Streaming)

    func send(_ text: String, context recentEntries: [DiaryEntry], allEntries: [DiaryEntry]? = nil, photoFileNames: [String] = [], videoFileNames: [String] = [], location: PendingLocation? = nil) async {
        let userMessage = Message(role: .user, content: text, photoFileNames: photoFileNames, videoFileNames: videoFileNames)
        messages.append(userMessage)

        isStreaming = true
        errorMessage = nil

        var aiMessage = Message(role: .assistant, content: "")
        messages.append(aiMessage)
        let messageIndex = messages.count - 1

        let hasMedia = !photoFileNames.isEmpty || !videoFileNames.isEmpty

        do {
            let systemPrompt: String
            if let allEntries {
                systemPrompt = buildEnhancedSystemPrompt(recentEntries: recentEntries, allEntries: allEntries)
            } else {
                systemPrompt = buildSystemPrompt(recentEntries: recentEntries)
            }

            var apiMessages: [[String: Any]] = [
                ["role": "system", "content": systemPrompt]
            ]
            for msg in messages.dropLast() where msg.role != .system {
                var textContent = msg.content
                if msg.id == userMessage.id, let loc = location {
                    textContent += "\n[User's current location: \(loc.name)]"
                }
                if !msg.photoFileNames.isEmpty || !msg.videoFileNames.isEmpty {
                    var contentParts: [[String: Any]] = []
                    for fileName in msg.photoFileNames {
                        if let base64 = loadPhotoAsBase64(fileName) {
                            contentParts.append([
                                "type": "image_url",
                                "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                            ])
                        }
                    }
                    for fileName in msg.videoFileNames {
                        let frames = loadVideoFramesAsBase64(fileName)
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
                    contentParts.append(["type": "text", "text": textContent])
                    apiMessages.append(["role": msg.role.rawValue, "content": contentParts])
                } else {
                    apiMessages.append(["role": msg.role.rawValue, "content": textContent])
                }
            }

            let maxAttempts = hasMedia
                ? APIConfig.models.filter(\.supportsVision).count
                : APIConfig.models.count

            var lastError: Error = URLError(.badServerResponse)
            for attempt in 0..<maxAttempts {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    rotateModel(requiresVision: hasMedia)
                }

                let model = selectModel(requiresVision: hasMedia)
                print("[ChatService.send] Using model: \(model.displayName) (attempt \(attempt + 1))")

                var request = URLRequest(url: URL(string: apiEndpoint)!, timeoutInterval: 60)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["model": model.id, "messages": apiMessages, "stream": true]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1

                if code == 429 {
                    print("[ChatService.send] 429 on \(model.displayName), will rotate after 3s")
                    lastError = URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP 429"])
                    continue
                }

                guard code == 200 else {
                    throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
                }

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let json = String(line.dropFirst(6))
                    if json == "[DONE]" { break }
                    if let data = json.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = obj["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        messages[messageIndex].content += content
                    }
                }
                // Success — break out of retry loop
                lastError = URLError(.cancelled) // sentinel: no real error
                break
            }

            // If we exhausted all models, fall through to catch with lastError
            if case URLError.cancelled = lastError { /* success */ }
            else { throw lastError }

        } catch {
            errorMessage = error.localizedDescription
            messages[messageIndex].content = mockResponse(for: text)
        }

        isStreaming = false
    }

    // MARK: - Summarize Session

    struct SessionSummary {
        let summary: String
        let moodEmoji: String
        let moodScore: Int
        let topics: [String]
    }

    func summarizeSession() async -> SessionSummary {
        let userMessages = messages.filter { $0.role == .user }.map(\.content)
        let conversation = messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")

        let prompt = """
        Analyze this conversation and respond with ONLY a JSON object (no markdown, no extra text):
        {
          "summary": "2-3 sentence diary summary of what the user talked about",
          "mood_emoji": "single emoji representing overall mood",
          "mood_score": <1-5 integer, 1=very sad, 5=very happy>,
          "topics": ["tag1", "tag2"]
        }

        topics 规则（严格遵守）：
        - 只能从以下标签池中选择，禁止自创标签：
        \(TopicTagService.tagListForPrompt)
        - 最多选 3 个最相关的标签
        - 按相关度从高到低排列

        Conversation:
        \(conversation)
        """

        do {
            var request = URLRequest(url: URL(string: apiEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let model = selectModel(requiresVision: false)
            let body: [String: Any] = [
                "model": model.id,
                "messages": [
                    ["role": "system", "content": "You are a JSON-only response bot. Output valid JSON only."],
                    ["role": "user", "content": prompt]
                ],
                "stream": false
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)

            // Primary: standard JSON parse
            var contentString: String?
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let c = message["content"] as? String {
                contentString = c
            } else if let c = extractMessageContent(from: data) {
                // Fallback: Qwen3.5 embeds raw newlines in reasoning_content, breaking JSON
                print("[summarizeSession] JSON parse failed, used string fallback")
                contentString = c
            }

            if let content = contentString {
                // Parse the JSON from the response content
                let cleaned = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let jsonData = cleaned.data(using: .utf8),
                   let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    let rawTopics = result["topics"] as? [String] ?? []
                    return SessionSummary(
                        summary: result["summary"] as? String ?? "Conversation with Echo",
                        moodEmoji: result["mood_emoji"] as? String ?? "😊",
                        moodScore: result["mood_score"] as? Int ?? 3,
                        topics: TopicTagService.normalize(rawTopics)
                    )
                }
            }
        } catch {
            print("Summarization failed: \(error)")
        }

        // Fallback: generate from user messages
        let fallbackSummary = userMessages.prefix(2).joined(separator: ". ")
        return SessionSummary(
            summary: fallbackSummary.isEmpty ? "Quick chat with Echo" : fallbackSummary,
            moodEmoji: "😊",
            moodScore: 3,
            topics: []
        )
    }

    // MARK: - Clear

    func clear() {
        messages.removeAll()
        isStreaming = false
        errorMessage = nil
    }

    // MARK: - Photo Base64 Encoding

    func loadPhotoAsBase64(_ fileName: String) -> String? {
        let url = PhotoPickerService.photoURL(for: fileName)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }

        // Scale down to max 1024px on longest side
        let maxDimension: CGFloat = 1024
        let size = image.size
        let scale: CGFloat
        if size.width > maxDimension || size.height > maxDimension {
            scale = maxDimension / max(size.width, size.height)
        } else {
            scale = 1.0
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else { return nil }
        return jpegData.base64EncodedString()
    }

    // MARK: - Video Frame Extraction

    func loadVideoFramesAsBase64(_ fileName: String, frameCount: Int = 4) -> [String] {
        let url = VideoPickerService.videoURL(for: fileName)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)

        let duration = asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0 else { return [] }

        let interval = durationSeconds / Double(frameCount + 1)
        var frames: [String] = []

        for i in 1...frameCount {
            let time = CMTimeMakeWithSeconds(interval * Double(i), preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
            let uiImage = UIImage(cgImage: cgImage)
            guard let jpegData = uiImage.jpegData(compressionQuality: 0.6) else { continue }
            frames.append(jpegData.base64EncodedString())
        }

        return frames
    }

    // MARK: - Agent API (for MultiAgentPipeline)

    /// Non-streaming LLM call — used by parallel Agents (Emotion, Memory, Action).
    /// Uses the lightweight model pool (isLightweight == true) to reduce TTFT.
    /// Falls back to the full pool if no lightweight model is configured.
    /// Each call iterates its own local pool — does NOT touch shared currentModelIndex.
    func callAgent(systemPrompt: String, userContent: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AgentError.noAPIKey }

        let pool: [APIConfig.ModelConfig] = {
            let light = APIConfig.models.filter(\.isLightweight)
            return light.isEmpty ? APIConfig.models : light
        }()

        var lastError: Error = AgentError.httpError(429)

        for (attempt, model) in pool.enumerated() {
            if attempt > 0 {
                print("[callAgent] 429 — waiting 3s then trying next lightweight model (attempt \(attempt + 1)/\(pool.count))")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }

            print("[callAgent] Using model: \(model.displayName)")

            let body: [String: Any] = [
                "model": model.id,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userContent]
                ],
                "stream": false
            ]

            var request = URLRequest(url: URL(string: apiEndpoint)!, timeoutInterval: 25)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1

            if code == 429 {
                lastError = AgentError.httpError(429)
                continue
            }

            guard code == 200 else { throw AgentError.httpError(code) }

            // Primary: standard JSON parse
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }

            // Fallback: character-level extraction for models that embed raw newlines
            // in "reasoning_content", making the full JSON unparseable (e.g. Qwen3.5).
            if let content = extractMessageContent(from: data) {
                print("[callAgent] JSON parse failed, used string fallback. Model: \(model.displayName)")
                return content
            }

            throw AgentError.parseError
        }

        throw lastError
    }

    /// Streaming LLM call — used by Synthesis Agent.
    /// On HTTP 429: waits 3 s then rotates to the next model.
    /// Synthesis responses are text-only (vision already handled upstream).
    func streamAgent(
        systemPrompt: String,
        messages: [[String: Any]],
        onDelta: @escaping (String) -> Void
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AgentError.noAPIKey }

        var apiMessages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        apiMessages.append(contentsOf: messages)

        let maxAttempts = APIConfig.models.count
        var lastError: Error = AgentError.httpError(429)

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                print("[streamAgent] 429 — waiting 3s then rotating model (attempt \(attempt + 1)/\(maxAttempts))")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                rotateModel(requiresVision: false)
            }

            let model = selectModel(requiresVision: false)
            print("[streamAgent] Using model: \(model.displayName)")

            var request = URLRequest(url: URL(string: apiEndpoint)!, timeoutInterval: 60)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["model": model.id, "messages": apiMessages, "stream": true]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1

            if code == 429 {
                lastError = AgentError.httpError(429)
                continue
            }

            guard code == 200 else { throw AgentError.httpError(code) }

            var fullContent = ""
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let json = String(line.dropFirst(6))
                if json == "[DONE]" { break }
                if let data = json.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = obj["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    fullContent += content
                    onDelta(content)
                }
            }
            return fullContent
        }

        throw lastError
    }

    // MARK: - Raw Response Content Extraction (fallback for models with invalid JSON)

    /// Some models (e.g. Qwen3.5) embed raw newlines inside `reasoning_content`,
    /// which breaks JSONSerialization. This method locates the `"message"` object
    /// and extracts the `"content"` value via character-level parsing,
    /// bypassing the offending field entirely.
    private func extractMessageContent(from data: Data) -> String? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }

        // Locate the start of the "message":{ block
        guard let messageRange = raw.range(of: "\"message\":{") else { return nil }
        let afterMessage = String(raw[messageRange.upperBound...])

        // Locate "content":"  within that block
        guard let contentRange = afterMessage.range(of: "\"content\":\"") else { return nil }
        let afterContent = String(afterMessage[contentRange.upperBound...])

        // Walk character by character, honouring JSON escape sequences
        var result = ""
        var escaped = false
        for char in afterContent {
            if escaped {
                switch char {
                case "n":  result.append("\n")
                case "t":  result.append("\t")
                case "r":  result.append("\r")
                case "\\": result.append("\\")
                case "\"": result.append("\"")
                default:   result.append(char)
                }
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                break
            } else {
                result.append(char)
            }
        }
        return result.isEmpty ? nil : result
    }

    enum AgentError: Error, LocalizedError {
        case noAPIKey
        case httpError(Int)
        case parseError

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "API key not configured"
            case .httpError(let code): return "HTTP error \(code)"
            case .parseError: return "Failed to parse response"
            }
        }
    }

    // MARK: - Mock Fallback

    private func mockResponse(for input: String) -> String {
        let lower = input.lowercased()
        if lower.contains("领导") || lower.contains("批评") || lower.contains("被说") || lower.contains("开会") || lower.contains("职场") {
            return "被否定的感觉真的不好受，尤其是当众的时候 💙 但你愿意说出来，已经是在消化它了。你有没有想到，这次能学到什么？"
        }
        if lower.contains("加班") || lower.contains("累") || lower.contains("压力") || lower.contains("焦虑") || lower.contains("睡不着") {
            return "最近这根弦绷得有点紧了 🌙 有时候身体比我们先发现——你今天有没有做过什么让自己放松的事，哪怕五分钟？"
        }
        if lower.contains("开心") || lower.contains("好消息") || lower.contains("成功") || lower.contains("通过") || lower.contains("棒") {
            return "听到这个我也替你开心！🌟 能说说是什么事吗？我想把这个好时刻好好记下来。"
        }
        if lower.contains("跑步") || lower.contains("运动") || lower.contains("健身") || lower.contains("锻炼") {
            return "动起来就是对自己最好的投资 💪 运动完和运动前比，心情有没有不一样？"
        }
        if lower.contains("阅读") || lower.contains("看书") || lower.contains("读书") {
            return "读到什么好东西了吗？📖 有时候一句话就能让整个人平静下来，你最近有没有这样的句子？"
        }
        if lower.contains("难过") || lower.contains("低落") || lower.contains("不想") || lower.contains("很烦") {
            return "心情不好的时候，说出来就已经好一点了 🫂 你现在是什么感觉——是烦、累，还是有点空空的？"
        }
        return "嗯，我在听 🐧 继续说——你今天脑子里一直转的是什么事？"
    }
}
