import SwiftUI

struct WeeklyLetterSheet: View {
    let observation: String
    let entryCount: Int
    let weekLabel: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Penguin header
                    VStack(spacing: 8) {
                        PetView(petState: PetState())
                            .scaleEffect(0.5)
                            .frame(width: 80, height: 100)
                            .allowsHitTesting(false)

                        Text("Echo's Letter")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.claudeDeepAccent)
                    }
                    .padding(.top, 8)

                    // Letter body
                    VStack(alignment: .leading, spacing: 16) {
                        Text("亲爱的主人，")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(observation)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("—— 你的Echo 🐧")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.claudeAccent)
                                Text(weekLabel)
                                    .font(.caption)
                                    .foregroundStyle(Color.claudeWarmGray)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.claudeSurfaceTint)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Footer
                    Text("基于本周 \(entryCount) 篇日记")
                        .font(.caption)
                        .foregroundStyle(Color.claudeWarmGray)
                }
                .padding(20)
            }
            .background(Color.claudeBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.claudeWarmGray)
                    }
                }
            }
        }
    }
}
