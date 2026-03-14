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
                            .frame(width: 260, height: 260)
                            .glassEffect(.regular, in: .circle)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 260, height: 260)
                            .shadow(color: Color.claudeAccent.opacity(0.15), radius: 20, y: 6)
                    }

                    PetView(petState: petState)
                        .scaleEffect(1.25)
                        .allowsHitTesting(false)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(height: 300)

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
