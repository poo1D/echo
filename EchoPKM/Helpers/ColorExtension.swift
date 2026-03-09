import SwiftUI

extension Color {
    // Claude-style palette
    static let claudeUserBubble = Color(hex: "F5F0E8")       // warm beige
    static let claudeAssistantBubble = Color(hex: "FAFAFA")   // near-white
    static let claudeAccent = Color(hex: "D97757")            // terracotta
    static let claudeBackground = Color(hex: "FAF9F5")      // warm off-white page bg
    static let claudeDeepAccent = Color(hex: "C15F3C")       // deeper terracotta for emphasis
    static let claudeWarmGray = Color(hex: "8B8680")          // warm gray for secondary text
    static let claudeCardBg = Color(hex: "FFFFFF")            // pure white cards
    static let claudeSurfaceTint = Color(hex: "F5F0E8")       // tinted surface
    static let claudeDivider = Color(hex: "E8E4DE")           // warm divider

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
