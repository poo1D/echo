import SwiftUI

// MARK: - CelebrationOverlayView

struct CelebrationOverlayView: View {
    @Binding var isShowing: Bool
    @State private var animate = false

    // 48 pieces: 24 from left, 24 from right
    private static let count = 48

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<Self.count, id: \.self) { i in
                    ConfettiPiece(index: i, screenSize: geo.size, animate: animate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            animate = false
            withAnimation(.easeOut(duration: 1.4)) {
                animate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                isShowing = false
            }
        }
    }
}

// MARK: - Single Confetti Piece

private struct ConfettiPiece: View {
    let index: Int
    let screenSize: CGSize
    let animate: Bool

    // Deterministic pseudo-random helpers
    private func frac(_ seed: Int) -> CGFloat {
        CGFloat((seed &* 2654435761) & 0x7FFFFFFF) / CGFloat(0x7FFFFFFF)
    }

    private var fromLeft: Bool { index < 24 }

    private var startX: CGFloat {
        let t = frac(index * 7 + 1)
        return fromLeft
            ? t * screenSize.width * 0.18
            : screenSize.width - t * screenSize.width * 0.18
    }

    private var startY: CGFloat {
        let t = frac(index * 11 + 3)
        return screenSize.height * 0.35 + t * screenSize.height * 0.25
    }

    private var endX: CGFloat {
        let t = frac(index * 13 + 5)
        // Left-side pieces spray toward center-right; right-side toward center-left
        return fromLeft
            ? screenSize.width * (0.1 + t * 0.75)
            : screenSize.width * (0.15 + t * 0.75)
    }

    private var endY: CGFloat {
        let t = frac(index * 17 + 7)
        return screenSize.height * (-0.05 + t * 0.45)
    }

    private var pieceColor: Color {
        let palette: [Color] = [
            Color(hex: "FF6B35"),
            Color(hex: "FFD700"),
            Color(hex: "4CAF50"),
            Color(hex: "5B9CF6"),
            Color(hex: "E879A0"),
            Color(hex: "A78BFA"),
            Color(hex: "34D399"),
            Color(hex: "FB923C"),
        ]
        return palette[index % palette.count]
    }

    private var endRotation: Double {
        Double(frac(index * 19 + 9)) * 540 - 270
    }

    private var pieceSize: CGFloat {
        6 + frac(index * 23 + 11) * 8
    }

    private var delay: Double {
        Double(frac(index * 29 + 13)) * 0.18
    }

    var body: some View {
        pieceShape
            .foregroundStyle(pieceColor)
            .frame(width: pieceSize, height: pieceSize * shapeAspect)
            .rotationEffect(.degrees(animate ? endRotation : 0))
            .position(
                x: animate ? endX : startX,
                y: animate ? endY : startY
            )
            .opacity(animate ? 0 : 1)
            .animation(
                .spring(response: 0.9 + Double(frac(index * 31 + 2)) * 0.4,
                        dampingFraction: 0.65)
                .delay(delay),
                value: animate
            )
    }

    @ViewBuilder
    private var pieceShape: some View {
        switch index % 3 {
        case 0:  Circle()
        case 1:  RoundedRectangle(cornerRadius: 2)
        default: Rectangle()
        }
    }

    private var shapeAspect: CGFloat {
        index % 3 == 1 ? 0.5 : 1.0
    }
}
