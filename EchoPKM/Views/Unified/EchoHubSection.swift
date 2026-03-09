import SwiftUI
import SwiftData

struct EchoHubSection: View {
    var petState: PetState
    var greeting: String
    var proactiveCards: [ProactiveCardData]
    var onTapEcho: () -> Void
    var onQuickAction: (ProactiveCardData) -> Void

    @State private var floatOffsets: [CGFloat] = [0, 0, 0, 0]
    @State private var bubblesVisible = false
    @State private var completedBubbles: Set<UUID> = []

    private let bubblePositions: [CGPoint] = [
        CGPoint(x: -100, y: -60),
        CGPoint(x: 100, y: -50),
        CGPoint(x: -110, y: 30),
        CGPoint(x: 110, y: 40)
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Bubble zone + Echo
            ZStack {
                // Proactive bubbles
                ForEach(Array(visibleCards.enumerated()), id: \.element.id) { index, card in
                    if !completedBubbles.contains(card.id) {
                        ProactiveBubble(card: card) {
                            completeBubble(card)
                        }
                        .offset(
                            x: bubblePositions[index % bubblePositions.count].x,
                            y: bubblePositions[index % bubblePositions.count].y + floatOffsets[index % 4]
                        )
                        .transition(.scale.combined(with: .opacity))
                        .opacity(bubblesVisible ? 1 : 0)
                        .scaleEffect(bubblesVisible ? 1 : 0.5)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.15),
                            value: bubblesVisible
                        )
                    }
                }

                // Echo penguin in white circle
                Button(action: onTapEcho) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 160, height: 160)
                            .shadow(color: Color.claudeAccent.opacity(0.15), radius: 12, y: 4)

                        PetView(petState: petState)
                            .scaleEffect(0.85)
                            .allowsHitTesting(false)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 200)

            // Greeting text
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(Color.claudeWarmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineLimit(2)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.claudeSurfaceTint, Color.claudeBackground],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            startFloatingAnimation()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                bubblesVisible = true
            }
        }
    }

    private var visibleCards: [ProactiveCardData] {
        Array(proactiveCards.prefix(4))
    }

    private func completeBubble(_ card: ProactiveCardData) {
        onQuickAction(card)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            completedBubbles.insert(card.id)
        }
    }

    private func startFloatingAnimation() {
        for i in 0..<4 {
            let delay = Double(i) * 0.4
            let duration = 2.0 + Double(i) * 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    floatOffsets[i] = 8
                }
            }
        }
    }
}

// MARK: - Proactive Bubble

private struct ProactiveBubble: View {
    let card: ProactiveCardData
    let onTap: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                showCheckmark = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onTap()
            }
        } label: {
            HStack(spacing: 6) {
                if showCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: card.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: card.iconColor))
                }

                Text(card.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(showCheckmark ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showCheckmark)
    }
}
