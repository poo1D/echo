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
                .font(.yuantiBody)
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
                            .font(.yuantiCaption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.yuantiCaption)
                    .foregroundStyle(.tertiary)
            }

            // 5. Topic tags (max 4)
            if !entry.topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(entry.topics.prefix(4)), id: \.self) { topic in
                        Text(topic)
                            .font(.yuantiCaption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.claudeAccent.opacity(0.10))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.claudeAccent)
                    }
                }
            }

            // 6. AI Insight (expandable on tap)
            if let insight = entry.aiInsight {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(insight)
                        .font(.yuantiCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(showFullInsight ? nil : 2)
                    Spacer(minLength: 0)
                    Image(systemName: showFullInsight ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(8)
                .background(Color.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showFullInsight.toggle()
                    }
                }
            }
        }
        .padding()
        .glassCard()
        .padding(.horizontal)
    }
}
