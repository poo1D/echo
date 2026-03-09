import Foundation

struct MoodUtils {
    static let moodCheckinTopic = "__mood_checkin__"

    static let emojis = ["😊", "😢", "😡", "😴", "🤩", "😰", "🥰", "😌", "🤔", "😤", "💪", "🎉"]

    static func score(for emoji: String) -> Int {
        switch emoji {
        case "🤩", "🥰", "🎉": return 5
        case "😊", "😌", "💪": return 4
        case "🤔", "😴": return 3
        case "😢", "😰": return 2
        case "😡", "😤": return 1
        default: return 3
        }
    }

    static func emoji(forScore score: Int) -> String {
        switch score {
        case 5: return "🤩"
        case 4: return "😊"
        case 3: return "😐"
        case 2: return "😕"
        default: return "😢"
        }
    }

    static func trendLabel(from scores: [Int]) -> (text: String, arrow: String) {
        guard scores.count >= 2 else { return ("--", "") }
        let midpoint = scores.count / 2
        let firstHalf = Array(scores.prefix(midpoint))
        let secondHalf = Array(scores.suffix(from: midpoint))
        let avgFirst = Double(firstHalf.reduce(0, +)) / Double(firstHalf.count)
        let avgSecond = Double(secondHalf.reduce(0, +)) / Double(secondHalf.count)
        let diff = avgSecond - avgFirst
        if diff > 0.3 {
            return ("上升中", "↑")
        } else if diff < -0.3 {
            return ("低落", "↓")
        } else {
            return ("平稳", "→")
        }
    }
}
