import SwiftUI

// MARK: - 色彩系统（柔和色调）
enum JournalColors {
    // 主色调 - 温暖米色系
    static let cream = Color(hex: "FFF8F0")
    static let warmWhite = Color(hex: "FFFCF7")
    
    // 强调色 - 柔和粉彩（用于Liquid Glass tint）
    static let softPink = Color(hex: "FFE4E8")
    static let mintGreen = Color(hex: "E8F5F0")
    static let lavender = Color(hex: "F0E8FF")
    static let peach = Color(hex: "FFE8D8")
    static let skyBlue = Color(hex: "E8F4FF")
    
    // 文字色
    static let inkBlack = Color(hex: "2D2D2D")
    static let warmGray = Color(hex: "6B6B6B")
    
    // 纸胶带色数组
    static let tapeColors: [Color] = [softPink, mintGreen, lavender, peach, skyBlue]
}

// MARK: - 字体层级
enum JournalFonts {
    static let largeTitle = Font.system(size: 32, weight: .bold, design: .serif)
    static let title = Font.system(size: 28, weight: .semibold, design: .serif)
    static let headline = Font.system(size: 18, weight: .medium, design: .serif)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
}

// MARK: - Color hex 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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

// MARK: - Liquid Glass + 手帐风格修饰器
extension View {
    /// 带Liquid Glass效果的卡片样式（iOS 26+自动fallback）
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
    
    /// 交互式Liquid Glass按钮样式
    @ViewBuilder
    func glassButton(cornerRadius: CGFloat = 12) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
    
    /// 手帐风格背景（用于内容区域）
    func scrapbookStyle() -> some View {
        self
            .background(JournalColors.warmWhite)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
    
    /// 纸胶带装饰
    func withWashiTape(color: Color = JournalColors.softPink, rotation: Double = -5) -> some View {
        self.overlay(alignment: .top) {
            WashiTape(color: color, rotation: rotation)
                .offset(y: -8)
        }
    }
}

// MARK: - 纸胶带组件
struct WashiTape: View {
    let color: Color
    var rotation: Double = 0
    
    var body: some View {
        Rectangle()
            .fill(color.opacity(0.7))
            .frame(width: 60, height: 20)
            .rotationEffect(.degrees(rotation))
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
    }
}

// MARK: - 纸张纹理背景
struct PaperTexture: View {
    var style: PaperStyle = .cream
    
    enum PaperStyle {
        case cream, white, kraft
        
        var color: Color {
            switch self {
            case .cream: return JournalColors.cream
            case .white: return JournalColors.warmWhite
            case .kraft: return Color(hex: "D4C4A8")
            }
        }
    }
    
    var body: some View {
        style.color
            .overlay {
                // 纸张纹理噪点效果
                Rectangle()
                    .fill(.white.opacity(0.02))
            }
            .ignoresSafeArea()
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Echo Journal")
            .font(JournalFonts.title)
            .foregroundStyle(JournalColors.inkBlack)
        
        Text("日式手帐 × Liquid Glass")
            .font(JournalFonts.body)
            .padding()
            .scrapbookStyle()
            .withWashiTape()
        
        HStack(spacing: 16) {
            ForEach(JournalColors.tapeColors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
            }
        }
    }
    .padding()
    .background(PaperTexture())
}
