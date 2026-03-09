import Foundation

/// Parses `<card type="...">JSON</card>` markup from Synthesis Agent output
/// and extracts RichContent cards + clean text.
struct ToolCallParser {

    struct ParseResult {
        let cleanText: String
        let cards: [RichContent]
    }

    /// Parse the full Synthesis output, extracting card tags and returning clean text + cards
    static func parse(_ rawText: String) -> ParseResult {
        var cleanText = rawText
        var cards: [RichContent] = []

        // Regex: <card type="...">JSON</card>
        let pattern = #"<card\s+type="(\w+)">([\s\S]*?)</card>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return ParseResult(cleanText: rawText, cards: [])
        }

        let nsRange = NSRange(rawText.startIndex..., in: rawText)
        let matches = regex.matches(in: rawText, range: nsRange)

        for match in matches.reversed() {
            guard let typeRange = Range(match.range(at: 1), in: rawText),
                  let jsonRange = Range(match.range(at: 2), in: rawText),
                  let fullRange = Range(match.range, in: rawText) else { continue }

            let cardType = String(rawText[typeRange])
            let jsonStr = String(rawText[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean markdown code fences if present
            let cleaned = jsonStr
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let card = parseCard(type: cardType, json: cleaned) {
                cards.insert(card, at: 0)
            }

            // Remove the card tag from the text
            cleanText = cleanText.replacingCharacters(
                in: fullRange,
                with: ""
            )
        }

        // Clean up whitespace
        cleanText = cleanText
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParseResult(cleanText: cleanText, cards: cards)
    }

    // MARK: - Card Parsers

    private static func parseCard(type: String, json: String) -> RichContent? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        switch type {
        case "memoryRecall":
            return parseMemoryRecall(obj)
        case "moodTrend":
            return parseMoodTrend(obj)
        case "scheduleConfirm":
            return parseScheduleConfirm(obj)
        case "habitStreak":
            return parseHabitStreak(obj)
        case "patternInsight":
            return parsePatternInsight(obj)
        default:
            return nil
        }
    }

    private static func parseMemoryRecall(_ obj: [String: Any]) -> RichContent? {
        guard let summary = obj["summary"] as? String else { return nil }
        let dateStr = obj["date"] as? String ?? ""
        let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        let mood = obj["moodEmoji"] as? String
        let reason = obj["reason"] as? String ?? ""
        return .memoryRecall(MemoryRecallData(
            date: date,
            summary: summary,
            moodEmoji: mood,
            relevanceReason: reason
        ))
    }

    private static func parseMoodTrend(_ obj: [String: Any]) -> RichContent? {
        let trend = obj["trend"] as? String ?? "stable"
        let insight = obj["insight"] as? String ?? ""
        // Scores array is optional for the card
        return .moodTrend(MoodTrendData(scores: [], trend: trend, insight: insight))
    }

    private static func parseScheduleConfirm(_ obj: [String: Any]) -> RichContent? {
        guard let title = obj["title"] as? String else { return nil }
        let dateStr = obj["date"] as? String ?? ""
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let date = isoFormatter.date(from: dateStr) ?? Date()
        let notes = obj["notes"] as? String
        return .scheduleConfirm(ScheduleConfirmData(title: title, date: date, notes: notes))
    }

    private static func parseHabitStreak(_ obj: [String: Any]) -> RichContent? {
        guard let name = obj["name"] as? String else { return nil }
        let streak = obj["streak"] as? Int ?? 1
        let change = obj["change"] as? Int ?? 1
        return .habitStreak(HabitStreakData(habitName: name, streakCount: streak, change: change))
    }

    private static func parsePatternInsight(_ obj: [String: Any]) -> RichContent? {
        guard let pattern = obj["pattern"] as? String else { return nil }
        let evidence = obj["evidence"] as? String ?? ""
        let occurrences = obj["occurrences"] as? Int ?? 0
        return .patternInsight(PatternInsightData(pattern: pattern, evidence: evidence, occurrences: occurrences))
    }
}
