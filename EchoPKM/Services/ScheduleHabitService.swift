import Foundation
import SwiftData

@Observable @MainActor
final class ScheduleHabitService {
    var isExtracting = false

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

    func extractFromEntry(_ entry: DiaryEntry, modelContext: ModelContext) async {
        guard !apiKey.isEmpty else { return }
        guard !isExtracting else { return }

        isExtracting = true
        defer { isExtracting = false }

        let today = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let todayStr = dateFormatter.string(from: today)

        let prompt = """
        Analyze this diary entry and extract any scheduled events or habits mentioned. \
        Today's date is \(todayStr).

        Entry summary: \(entry.summary)
        Topics: \(entry.topics.joined(separator: ", "))

        Respond with ONLY a JSON object (no markdown, no extra text):
        {
          "schedules": [
            {"title": "event name", "date": "YYYY-MM-DD", "notes": "optional details"}
          ],
          "habits": [
            {"name": "activity name"}
          ]
        }

        Rules:
        - schedules: future plans, appointments, meetings, deadlines mentioned. \
          Infer the date from context (e.g. "next Thursday", "tomorrow"). If unsure, omit.
        - habits: recurring activities the user did today (exercise, cooking, reading, walking, meditation, etc.)
        - name should be a single lowercase word or short phrase
        - If nothing found, return empty arrays
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
                let cleaned = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let jsonData = cleaned.data(using: .utf8),
                   let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    parseAndStore(result, entryID: entry.id, entryDate: entry.createdAt, modelContext: modelContext)
                }
            }
        } catch {
            print("ScheduleHabitService extraction failed: \(error)")
        }
    }

    private func parseAndStore(_ json: [String: Any], entryID: UUID, entryDate: Date, modelContext: ModelContext) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        // Parse schedules
        if let schedules = json["schedules"] as? [[String: Any]] {
            for item in schedules {
                guard let title = item["title"] as? String,
                      let dateStr = item["date"] as? String,
                      let date = isoFormatter.date(from: dateStr) else { continue }
                let notes = item["notes"] as? String
                let schedule = ScheduleItem(
                    title: title,
                    date: date,
                    notes: notes,
                    sourceEntryID: entryID
                )
                modelContext.insert(schedule)
            }
        }

        // Parse habits
        if let habits = json["habits"] as? [[String: Any]] {
            for item in habits {
                guard let name = item["name"] as? String else { continue }
                let habit = HabitEntry(
                    name: name,
                    date: entryDate,
                    sourceEntryID: entryID
                )
                modelContext.insert(habit)
            }
        }

        try? modelContext.save()
    }
}
