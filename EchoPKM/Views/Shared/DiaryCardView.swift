import SwiftUI

struct DiaryCard: View {
    let entry: DiaryEntry

    @State private var showFullInsight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Photo grid
            if !entry.photoFileNames.isEmpty {
                PhotoGridView(photoFileNames: entry.photoFileNames)
            }

            // 1b. Video thumbnails
            if !entry.videoFileNames.isEmpty {
                VideoThumbnailsView(videoFileNames: entry.videoFileNames)
            }

            // 2. Audio waveform player
            if let firstAudio = entry.audioFileNames.first {
                AudioWaveformPlayer(fileName: firstAudio)
            }

            // 3. Summary text
            Text(entry.summary)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(showFullInsight ? nil : 4)

            // 4. Bottom info row: mood + location + time
            HStack(spacing: 12) {
                if let emoji = entry.moodEmoji {
                    Text(emoji)
                        .font(.title3)
                }

                if let loc = entry.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(loc)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // 5. Topic tags (max 4)
            if !entry.topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(entry.topics.prefix(4)), id: \.self) { topic in
                        Text(topic)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.claudeAccent.opacity(0.10))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.claudeAccent)
                    }
                }
            }

            // 6. AI Insight (expandable on long press)
            if let insight = entry.aiInsight {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(showFullInsight ? nil : 2)
                }
                .padding(showFullInsight ? 8 : 0)
                .background(showFullInsight ? Color.purple.opacity(0.05) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .glassCard()
        .scaleEffect(showFullInsight ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showFullInsight)
        .padding(.horizontal)
        .onLongPressGesture(minimumDuration: 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showFullInsight.toggle()
            }
        }
    }
}
