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
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
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

// MARK: - Glass Effect Container Modifier

struct GlassEffectContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

// MARK: - Glass Capsule Modifier

struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.clear)
                .glassEffect(.regular, in: .capsule)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Glass Circle Modifier

struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.clear)
                .glassEffect(.regular, in: .circle)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}
