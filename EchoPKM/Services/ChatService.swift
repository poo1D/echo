import Foundation
import UIKit

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

        enum Role: String, Codable {
            case user, assistant, system
        }

        init(role: Role, content: String, photoFileNames: [String] = []) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
            self.photoFileNames = photoFileNames
        }
    }

    // MARK: - State

    var messages: [Message] = []
    var isStreaming = false
    var errorMessage: String?

    // MARK: - API Config

    private let apiEndpoint = "https://api-inference.modelscope.cn/v1/chat/completions"
    private let modelId = "moonshotai/Kimi-K2.5"
    private var apiKey: String {
        let key = APIConfig.modelScopeAPIKey
        if !key.isEmpty { return key }
        if let key = ProcessInfo.processInfo.environment["MODELSCOPE_API_KEY"], !key.isEmpty {
            return key
        }
        return ""
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

    func send(_ text: String, context recentEntries: [DiaryEntry], allEntries: [DiaryEntry]? = nil, photoFileNames: [String] = [], location: PendingLocation? = nil) async {
        let userMessage = Message(role: .user, content: text, photoFileNames: photoFileNames)
        messages.append(userMessage)

        isStreaming = true
        errorMessage = nil

        var aiMessage = Message(role: .assistant, content: "")
        messages.append(aiMessage)
        let messageIndex = messages.count - 1

        do {
            var request = URLRequest(url: URL(string: apiEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
                // Append location context to the last user message
                if msg.id == userMessage.id, let loc = location {
                    textContent += "\n[User's current location: \(loc.name)]"
                }

                if !msg.photoFileNames.isEmpty {
                    // Build multimodal content array with image_url blocks + text
                    var contentParts: [[String: Any]] = []
                    for fileName in msg.photoFileNames {
                        if let base64 = loadPhotoAsBase64(fileName) {
                            contentParts.append([
                                "type": "image_url",
                                "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                            ])
                        }
                    }
                    contentParts.append(["type": "text", "text": textContent])
                    apiMessages.append(["role": msg.role.rawValue, "content": contentParts])
                } else {
                    apiMessages.append(["role": msg.role.rawValue, "content": textContent])
                }
            }

            let body: [String: Any] = [
                "model": modelId,
                "messages": apiMessages,
                "stream": true
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
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
        } catch {
            errorMessage = error.localizedDescription
            // Fallback mock response
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
          "topics": ["topic1", "topic2"]
        }

        Conversation:
        \(conversation)
        """

        do {
            var request = URLRequest(url: URL(string: apiEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "model": modelId,
                "messages": [
                    ["role": "system", "content": "You are a JSON-only response bot. Output valid JSON only."],
                    ["role": "user", "content": prompt]
                ],
                "stream": false
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                // Parse the JSON from the response content
                let cleaned = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let jsonData = cleaned.data(using: .utf8),
                   let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    return SessionSummary(
                        summary: result["summary"] as? String ?? "Conversation with Echo",
                        moodEmoji: result["mood_emoji"] as? String ?? "😊",
                        moodScore: result["mood_score"] as? Int ?? 3,
                        topics: result["topics"] as? [String] ?? []
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

    private func loadPhotoAsBase64(_ fileName: String) -> String? {
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

    // MARK: - Mock Fallback

    private func mockResponse(for input: String) -> String {
        let lower = input.lowercased()
        if lower.contains("stress") || lower.contains("tired") || lower.contains("exhausted") {
            return "That sounds really tough 💙 Have you tried stepping away for even 5 minutes? A short walk or some fresh air can help reset. What's weighing on you most right now?"
        }
        if lower.contains("happy") || lower.contains("great") || lower.contains("good") {
            return "That's wonderful to hear! 🌟 What made it so good? I want to remember this so we can spot what lights you up."
        }
        if lower.contains("work") || lower.contains("boss") || lower.contains("deadline") {
            return "Work pressure is real 💪 One thing that might help: try breaking it into the smallest next step. What's the one thing you could tackle first?"
        }
        if lower.contains("exercise") || lower.contains("gym") || lower.contains("run") {
            return "Nice! Moving your body is such a mood booster 🏃 How did you feel afterwards compared to before?"
        }
        return "I hear you! Tell me more about what's going on — and let's figure out together if there's something small you could try today ☀️"
    }
}
