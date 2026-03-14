import SwiftUI

/// Maps mood scores to ambient background gradients for immersive atmosphere.
enum MoodAtmosphere: String, CaseIterable {
    case happy
    case neutral
    case tired
    case worried
    case energized

    var gradient: [Color] {
        switch self {
        case .happy:
            return [Color.moodHappy, Color.claudeBackground]
        case .neutral:
            return [Color.claudeSurfaceTint, Color.claudeBackground]
        case .tired:
            return [Color.moodTired, Color.claudeBackground]
        case .worried:
            return [Color.moodWorried, Color.claudeBackground]
        case .energized:
            return [Color.moodEnergized, Color.claudeBackground]
        }
    }

    /// Derive atmosphere from a mood score (1-5)
    static func from(moodScore: Int) -> MoodAtmosphere {
        switch moodScore {
        case 1...2: return .worried
        case 3: return .neutral
        case 4: return .happy
        case 5: return .energized
        default: return .neutral
        }
    }

    /// Derive atmosphere from mood emoji
    static func from(emoji: String?) -> MoodAtmosphere {
        guard let emoji else { return .neutral }
        switch emoji {
        case "😊", "🤩", "🥰", "😄": return .happy
        case "💪", "🏃", "⚡️": return .energized
        case "😴", "😐", "🥱": return .tired
        case "😰", "😢", "😟", "😤": return .worried
        default: return .neutral
        }
    }
}
