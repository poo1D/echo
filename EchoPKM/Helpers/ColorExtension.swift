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

    // Mood atmosphere colors
    static let moodHappy = Color(hex: "FFF9E6")              // warm golden
    static let moodTired = Color(hex: "E8E4F0")              // soft lavender
    static let moodWorried = Color(hex: "E8F0F8")            // calm blue-gray
    static let moodEnergized = Color(hex: "E6F9F0")          // fresh green

    // Glass tint colors (for Liquid Glass effect — very subtle, near-white)
    static let glassDefaultTint = Color.white.opacity(0.6)                     // near-white base
    static let glassMoodTint = Color.claudeAccent.opacity(0.06)                // faint terracotta
    static let glassHabitTint = Color(hex: "FF6B35").opacity(0.05)             // faint orange
    static let glassHealthTint = Color(hex: "7B68EE").opacity(0.05)            // faint purple
    static let glassLetterTint = Color.claudeAccent.opacity(0.05)              // faint envelope
    static let glassMemoryTint = Color(hex: "7B68EE").opacity(0.04)            // faint purple
    static let glassSuccessTint = Color(hex: "4CAF50").opacity(0.04)           // faint green

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

// MARK: - PingFang SC (苹方-简) Font Helpers

extension Font {
    /// 超大标题 — 苹方 Semibold 34pt
    static let yuantiLargeTitle = Font.custom("PingFangSC-Semibold", size: 34)
    /// 大标题 — 苹方 Semibold 28pt
    static let yuantiTitle = Font.custom("PingFangSC-Semibold", size: 28)
    /// 标题2 — 苹方 Semibold 22pt
    static let yuantiTitle2 = Font.custom("PingFangSC-Semibold", size: 22)
    /// 标题3 — 苹方 Semibold 20pt
    static let yuantiTitle3 = Font.custom("PingFangSC-Semibold", size: 20)
    /// 小节标题 — 苹方 Semibold 17pt
    static let yuantiHeadline = Font.custom("PingFangSC-Semibold", size: 17)
    /// 副标题 — 苹方 Regular 15pt
    static let yuantiSubheadline = Font.custom("PingFangSC-Regular", size: 15)
    /// 正文 — 苹方 Regular 17pt
    static let yuantiBody = Font.custom("PingFangSC-Regular", size: 17)
    /// 标注 — 苹方 Regular 16pt
    static let yuantiCallout = Font.custom("PingFangSC-Regular", size: 16)
    /// 脚注 — 苹方 Regular 13pt
    static let yuantiFootnote = Font.custom("PingFangSC-Regular", size: 13)
    /// 小字 — 苹方 Regular 12pt
    static let yuantiCaption = Font.custom("PingFangSC-Regular", size: 12)
    /// 更小字 — 苹方 Regular 11pt
    static let yuantiCaption2 = Font.custom("PingFangSC-Regular", size: 11)

    /// 自定义大小的苹方
    static func yuanti(_ size: CGFloat, weight: YuantiWeight = .regular) -> Font {
        return .custom(weight.fontName, size: size)
    }

    enum YuantiWeight {
        case light, regular, medium, semibold, bold

        var fontName: String {
            switch self {
            case .light: return "PingFangSC-Light"
            case .regular: return "PingFangSC-Regular"
            case .medium: return "PingFangSC-Medium"
            case .semibold: return "PingFangSC-Semibold"
            case .bold: return "PingFangSC-Semibold"
            }
        }
    }
}
