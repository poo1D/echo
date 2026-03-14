import SwiftUI

// MARK: - Pet Accessory System

enum PetAccessory: String, CaseIterable, Hashable {
    case umbrella       // rain / sad
    case sunglasses     // happy / sunny
    case sweatband      // exercise / workout
    case sleepCap       // late night / tired
    case musicNote      // music related
    case book           // reading related
    case heart          // low mood / care

    var icon: String {
        switch self {
        case .umbrella: return "umbrella.fill"
        case .sunglasses: return "eyeglasses"
        case .sweatband: return "figure.run"
        case .sleepCap: return "moon.zzz.fill"
        case .musicNote: return "music.note"
        case .book: return "book.fill"
        case .heart: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .umbrella: return Color(hex: "4A90D9")
        case .sunglasses: return .black
        case .sweatband: return .red
        case .sleepCap: return Color(hex: "7B68EE")
        case .musicNote: return Color(hex: "FF6B35")
        case .book: return Color(hex: "8B4513")
        case .heart: return Color(hex: "E8A0BF")
        }
    }

    var offset: CGSize {
        switch self {
        case .umbrella: return CGSize(width: 25, height: -75)
        case .sunglasses: return CGSize(width: 0, height: -28)
        case .sweatband: return CGSize(width: 0, height: -48)
        case .sleepCap: return CGSize(width: 15, height: -70)
        case .musicNote: return CGSize(width: 30, height: -70)
        case .book: return CGSize(width: -50, height: 5)
        case .heart: return CGSize(width: 30, height: -55)
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .umbrella: return 22
        case .sunglasses: return 16
        case .sweatband: return 14
        case .sleepCap: return 20
        case .musicNote: return 18
        case .book: return 16
        case .heart: return 16
        }
    }
}

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
    var accessories: Set<PetAccessory> = []

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

        // Update accessories based on message content
        updateAccessories(from: message, moodScore: mood == .happy ? 4 : (mood == .worried ? 2 : 3), hour: Calendar.current.component(.hour, from: Date()))

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

    func updateAccessories(from message: String, moodScore: Int, hour: Int) {
        let lower = message.lowercased()
        var newAccessories = Set<PetAccessory>()

        // Exercise / workout
        if lower.contains("运动") || lower.contains("跑步") || lower.contains("健身") ||
           lower.contains("exercise") || lower.contains("workout") || lower.contains("gym") ||
           lower.contains("瑜伽") || lower.contains("yoga") {
            newAccessories.insert(.sweatband)
        }

        // Music
        if lower.contains("音乐") || lower.contains("music") || lower.contains("歌") || lower.contains("song") {
            newAccessories.insert(.musicNote)
        }

        // Reading
        if lower.contains("阅读") || lower.contains("看书") || lower.contains("read") || lower.contains("book") {
            newAccessories.insert(.book)
        }

        // Late night / tired
        if hour >= 22 || hour < 5 || lower.contains("困") || lower.contains("sleepy") || lower.contains("失眠") {
            newAccessories.insert(.sleepCap)
        }

        // Happy / sunny
        if moodScore >= 4 {
            newAccessories.insert(.sunglasses)
        }

        // Sad / rain
        if lower.contains("雨") || lower.contains("rain") || lower.contains("难过") || lower.contains("sad") {
            newAccessories.insert(.umbrella)
        }

        // Low mood care
        if moodScore <= 2 {
            newAccessories.insert(.heart)
        }

        accessories = newAccessories
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

                    // Accessories overlay
                    ForEach(Array(petState.accessories), id: \.self) { accessory in
                        Image(systemName: accessory.icon)
                            .font(.system(size: accessory.fontSize, weight: .semibold))
                            .foregroundStyle(accessory.color)
                            .offset(accessory.offset)
                            .transition(.scale.combined(with: .opacity))
                    }
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
        .animation(.easeInOut(duration: 0.3), value: petState.accessories)
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
