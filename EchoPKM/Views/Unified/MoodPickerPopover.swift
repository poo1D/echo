import SwiftUI

struct MoodPickerPopover: View {
    @Binding var isPresented: Bool
    @Binding var selectedMoodEmoji: String?
    var onMoodSelected: ((String) -> Void)? = nil

    @State private var showToast = false
    @State private var titleIndex = 0
    @State private var toastIndex = 0

    private let titles = [
        "今天心情怎么样？",
        "现在感觉如何？",
        "选一个最像你此刻的状态",
        "今天过得怎样？",
        "此刻，你是什么心情？"
    ]

    private let toasts = [
        "好的，我在听",
        "收到，说来听听",
        "嗯，我陪着你",
        "随时可以说",
        "我听着呢"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(spacing: 16) {
            Text(titles[titleIndex])
                .font(.yuantiHeadline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MoodUtils.emojis, id: \.self) { emoji in
                    Button {
                        selectMood(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 48, height: 48)
                            .background(
                                selectedMoodEmoji == emoji
                                    ? Color.claudeAccent.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            if showToast {
                Text(toasts[toastIndex])
                    .font(.yuantiCaption)
                    .foregroundStyle(Color.claudeAccent)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .onAppear {
            titleIndex = Int.random(in: 0..<titles.count)
            toastIndex = Int.random(in: 0..<toasts.count)
        }
    }

    private func selectMood(_ emoji: String) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        selectedMoodEmoji = emoji
        onMoodSelected?(emoji)

        withAnimation(.easeIn(duration: 0.2)) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                isPresented = false
                showToast = false
            }
        }
    }
}
