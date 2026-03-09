import SwiftUI

// MARK: - Pet State

enum PetMood: String, CaseIterable {
    case happy, neutral, tired, worried
}

enum PetAnimation: String {
    case idle, wingFlap, shyLookDown, jump, nod, searching
}

enum PipelinePhase {
    case agentsRunning
    case synthesizing
    case completed
}

@Observable
class PetState {
    var mood: PetMood = .neutral
    var currentAnimation: PetAnimation = .idle

    func react(to message: String) {
        let lower = message.lowercased()

        if lower.contains("happy") || lower.contains("great") || lower.contains("excited") || lower.contains("love") {
            mood = .happy
            currentAnimation = .jump
        } else if lower.contains("tired") || lower.contains("exhausted") || lower.contains("sleepy") {
            mood = .tired
            currentAnimation = .shyLookDown
        } else if lower.contains("worried") || lower.contains("anxious") || lower.contains("stress") || lower.contains("nervous") {
            mood = .worried
            currentAnimation = .nod
        } else if lower.contains("thank") || lower.contains("nice") || lower.contains("good") {
            mood = .happy
            currentAnimation = .wingFlap
        } else {
            currentAnimation = .nod
        }

        // Reset to idle after animation plays
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            currentAnimation = .idle
        }
    }

    func reactToPipeline(_ phase: PipelinePhase) {
        switch phase {
        case .agentsRunning:
            currentAnimation = .searching
        case .synthesizing:
            currentAnimation = .nod
        case .completed:
            currentAnimation = .wingFlap
        }

        if phase == .completed {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                currentAnimation = .idle
            }
        }
    }
}

// MARK: - Pet View (Penguin)

struct PetView: View {
    var petState: PetState

    @State private var isBlinking = false
    @State private var breathScale: CGFloat = 1.0
    @State private var bounceOffset: CGFloat = 0
    @State private var wingRotation: Double = 0
    @State private var headTilt: Double = 0
    @State private var jumpOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.1))
                .frame(width: 80, height: 20)
                .offset(y: 70 + jumpOffset / 2)
                .blur(radius: 5)

            VStack(spacing: 0) {
                ZStack {
                    // Body
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8B9DC3"), Color(hex: "6B7AA1")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 100, height: 130)

                    // Belly
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(hex: "F5F5F5")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 70, height: 90)
                        .offset(y: 10)

                    // Cheeks
                    HStack(spacing: 50) {
                        Circle()
                            .fill(Color(hex: "FFB5BA").opacity(petState.currentAnimation == .shyLookDown ? 0.9 : 0.6))
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(Color(hex: "FFB5BA").opacity(petState.currentAnimation == .shyLookDown ? 0.9 : 0.6))
                            .frame(width: 18, height: 18)
                    }
                    .offset(y: -5)

                    // Eyes
                    HStack(spacing: 30) {
                        eyeView
                        eyeView
                    }
                    .offset(y: -25 + headTilt * 2)

                    // Beak
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "FFB347"))
                        .rotationEffect(.degrees(180))
                        .offset(y: -5 + headTilt * 2)

                    // Wings
                    HStack(spacing: 75) {
                        Capsule()
                            .fill(Color(hex: "7B8BC0"))
                            .frame(width: 20, height: 50)
                            .rotationEffect(.degrees(15 + wingRotation))

                        Capsule()
                            .fill(Color(hex: "7B8BC0"))
                            .frame(width: 20, height: 50)
                            .rotationEffect(.degrees(-15 - wingRotation))
                    }
                    .offset(y: 10)
                }
                .rotationEffect(.degrees(headTilt))

                // Feet
                HStack(spacing: 20) {
                    Ellipse()
                        .fill(Color(hex: "FFB347"))
                        .frame(width: 25, height: 12)
                    Ellipse()
                        .fill(Color(hex: "FFB347"))
                        .frame(width: 25, height: 12)
                }
                .offset(y: -5)
            }
        }
        .scaleEffect(breathScale)
        .offset(y: bounceOffset + jumpOffset)
        .onAppear {
            startIdleAnimations()
        }
        .onChange(of: petState.currentAnimation) { _, newAnimation in
            playAnimation(newAnimation)
        }
    }

    // MARK: - Eye

    private var eyeView: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 20, height: isBlinking ? 3 : 20)

            if !isBlinking {
                Circle()
                    .fill(.white)
                    .frame(width: 7)
                    .offset(x: 3, y: -3)
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 3)
                    .offset(x: -2, y: 2)
            }
        }
    }

    // MARK: - Idle Animations

    private func startIdleAnimations() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) { isBlinking = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.1)) { isBlinking = false }
            }
        }

        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            breathScale = 1.05
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            bounceOffset = -5
        }
    }

    // MARK: - Action Animations

    private func playAnimation(_ animation: PetAnimation) {
        switch animation {
        case .wingFlap:
            withAnimation(.easeInOut(duration: 0.15).repeatCount(6, autoreverses: true)) {
                wingRotation = 25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { wingRotation = 0 }
            }

        case .shyLookDown:
            withAnimation(.easeInOut(duration: 0.3)) { headTilt = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.3)) { headTilt = 0 }
            }

        case .jump:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { jumpOffset = -30 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { jumpOffset = 0 }
            }
            withAnimation(.easeInOut(duration: 0.1).repeatCount(8, autoreverses: true)) {
                wingRotation = 20
            }

        case .nod:
            withAnimation(.easeInOut(duration: 0.2)) { headTilt = 5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeInOut(duration: 0.2)) { headTilt = -3 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) { headTilt = 0 }
            }

        case .searching:
            // Head rotates left and right, looking around
            withAnimation(.easeInOut(duration: 0.3).repeatCount(6, autoreverses: true)) {
                headTilt = 15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.3)) { headTilt = 0 }
            }

        case .idle:
            break
        }
    }
}

#Preview {
    PetView(petState: PetState())
        .padding()
        .background(Color(hex: "E8F4F8"))
}
