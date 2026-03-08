import Foundation
import SwiftData

@Observable @MainActor
final class InsightService {
    var isGenerating = false

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

    // MARK: - Generate Insight for a Single Entry

    func generateInsight(for entry: DiaryEntry, modelContext: ModelContext) async {
        guard entry.aiInsight == nil else { return }
        guard !apiKey.isEmpty else { return }

        let prompt = """
        Based on this diary entry, write ONE short encouraging insight or observation (15 words max). \
        Be warm, specific, and personal. No quotes.

        Entry: \(entry.summary)
        Mood: \(entry.moodEmoji ?? "") (score: \(entry.moodScore ?? 3)/5)
        Topics: \(entry.topics.joined(separator: ", "))
        """

        if let response = await callLLM(prompt: prompt) {
            entry.aiInsight = response
            try? modelContext.save()
        }
    }

    // MARK: - Weekly Observation with Cache

    func weeklyObservation(entries: [DiaryEntry], modelContext: ModelContext) async -> String? {
        guard !entries.isEmpty else { return nil }

        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!

        // Check cache
        var descriptor = FetchDescriptor<WeeklyReview>(
            predicate: #Predicate { $0.weekStartDate == weekStart }
        )
        descriptor.fetchLimit = 1

        if let cached = try? modelContext.fetch(descriptor).first,
           cached.entryCount == entries.count {
            return cached.observation
        }

        // Generate new observation
        let entrySummaries = entries.map { entry in
            let mood = entry.moodEmoji ?? ""
            return "\(mood) \(entry.summary) [topics: \(entry.topics.joined(separator: ", "))]"
        }.joined(separator: "\n")

        let prompt = """
        You are Echo, a cute penguin diary companion. Based on this week's diary entries, write a short \
        (2-3 sentence) personal observation. Be warm, specific, reference actual entries. Speak in first person \
        as the penguin. Don't use quotation marks.

        This week's entries:
        \(entrySummaries)
        """

        guard let observation = await callLLM(prompt: prompt) else {
            return "I noticed some interesting patterns this week!"
        }

        // Cache the result
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.observation = observation
            existing.entryCount = entries.count
            existing.generatedAt = Date()
        } else {
            let review = WeeklyReview(
                weekStartDate: weekStart,
                observation: observation,
                entryCount: entries.count
            )
            modelContext.insert(review)
        }
        try? modelContext.save()

        return observation
    }

    // MARK: - LLM Call Helper

    private func callLLM(prompt: String) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        do {
            var request = URLRequest(url: URL(string: apiEndpoint)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "model": modelId,
                "messages": [
                    ["role": "system", "content": "You are a concise, warm assistant. Respond with only the requested text, no extra formatting."],
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
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("InsightService LLM call failed: \(error)")
        }
        return nil
    }
}
