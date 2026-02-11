import SwiftUI

struct MoodCheckInCard: View {
    let isCompleted: Bool
    let currentMood: String?
    
    private let moodOptions = ["😊", "😌", "😔", "😤", "😴"]
    
    var body: some View {
        VStack(spacing: 20) {
            if isCompleted {
                completedView
            } else {
                checkInView
            }
        }
        .padding(24)
        .scrapbookStyle()
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: 16) {
            Text("Check-In complete.")
                .font(JournalFonts.headline)
                .foregroundStyle(JournalColors.warmGray)
            
            if let mood = currentMood {
                HStack(spacing: 12) {
                    Text(mood)
                        .font(.largeTitle)
                    Text("Excellent Mood")
                        .font(JournalFonts.body)
                        .foregroundStyle(JournalColors.inkBlack)
                }
            }
            
            // 标签
            HStack(spacing: 12) {
                MoodTagChip(icon: "sparkles", text: "Self-care")
                MoodTagChip(icon: "book", text: "Learning")
            }
        }
    }
    
    // MARK: - Check In View
    private var checkInView: some View {
        VStack(spacing: 20) {
            Text("How are you feeling?")
                .font(JournalFonts.headline)
                .foregroundStyle(JournalColors.inkBlack)
            
            HStack(spacing: 20) {
                ForEach(moodOptions, id: \.self) { mood in
                    Button {
                        // 选择心情
                    } label: {
                        Text(mood)
                            .font(.system(size: 32))
                    }
                }
            }
            
            Button {
                // 开始签到
            } label: {
                Text("Start Check-In")
                    .font(JournalFonts.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(JournalColors.inkBlack, in: Capsule())
            }
        }
    }
}

// MARK: - Mood Tag Chip
struct MoodTagChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(JournalFonts.caption)
        }
        .foregroundStyle(JournalColors.inkBlack)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(JournalColors.warmWhite, in: Capsule())
        .overlay {
            Capsule()
                .stroke(JournalColors.warmGray.opacity(0.2), lineWidth: 1)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MoodCheckInCard(isCompleted: false, currentMood: nil)
        MoodCheckInCard(isCompleted: true, currentMood: "😊")
    }
    .padding()
    .background(PaperTexture())
}
