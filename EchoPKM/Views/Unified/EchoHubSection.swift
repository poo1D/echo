import SwiftUI
import SwiftData

struct EchoHubSection: View {
    var petState: PetState
    var greeting: String
    var averageMoodAtmosphere: MoodAtmosphere = .neutral
    var onTapEcho: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Echo penguin in white circle
            Button(action: onTapEcho) {
                ZStack {
                    if #available(iOS 26.0, *) {
                        Circle()
                            .fill(.clear)
                            .frame(width: 160, height: 160)
                            .glassEffect(.regular, in: .circle)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 160, height: 160)
                            .shadow(color: Color.claudeAccent.opacity(0.15), radius: 12, y: 4)
                    }

                    PetView(petState: petState)
                        .scaleEffect(0.85)
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
            .frame(height: 200)

            // Greeting text
            Text(greeting)
                .font(.yuantiSubheadline)
                .foregroundStyle(Color.claudeWarmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineLimit(2)
        }
        .padding(.vertical, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(hubBackground)
    }

    private var hubBackground: some View {
        let topColor = averageMoodAtmosphere.gradient.first ?? Color.claudeSurfaceTint
        return LinearGradient(
            stops: [
                Gradient.Stop(color: topColor, location: 0),
                Gradient.Stop(color: topColor, location: 0.5),
                Gradient.Stop(color: Color.claudeBackground, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 1.5), value: averageMoodAtmosphere)
    }
}
