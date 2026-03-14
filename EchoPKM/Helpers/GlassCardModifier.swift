import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var tint: Color?
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.clear)
                .glassEffect(
                    .regular.tint(tint ?? Color.glassDefaultTint),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(Color.claudeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        }
    }
}

struct GlassCardCompactModifier: ViewModifier {
    var tint: Color?
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.clear)
                .glassEffect(
                    .regular.tint(tint ?? Color.glassDefaultTint),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(tint?.opacity(0.3) ?? Color.claudeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(tint: Color? = nil, cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(tint: tint, cornerRadius: cornerRadius))
    }

    func glassCardCompact(tint: Color? = nil, cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassCardCompactModifier(tint: tint, cornerRadius: cornerRadius))
    }
}

// MARK: - Warm Gradient Background

struct WarmGradientBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: Color.claudeSurfaceTint, location: 0),
                Gradient.Stop(color: Color.claudeBackground, location: 0.4),
                Gradient.Stop(color: Color.claudeBackground, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
