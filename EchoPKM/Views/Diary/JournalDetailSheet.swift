import SwiftUI

struct JournalDetailSheet: View {
    let entry: DiaryEntry
    var onDelete: ((DiaryEntry) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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

                    // 3. Summary text (full, no truncation)
                    Text(entry.summary)
                        .font(.yuantiBody)
                        .foregroundStyle(.primary)

                    // 4. Mood + time + location row
                    HStack(spacing: 12) {
                        if let emoji = entry.moodEmoji {
                            Text(emoji)
                                .font(.title3)
                        }

                        Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.yuantiCaption)
                            .foregroundStyle(.secondary)

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
                    }

                    // 5. Topic tags (FlowLayout)
                    if !entry.topics.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(entry.topics, id: \.self) { topic in
                                Text(topic)
                                    .font(.yuantiCaption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.08))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    // 6. AI Insight
                    if let insight = entry.aiInsight {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text(insight)
                                .font(.yuantiCallout)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 7. View Conversation link
                    NavigationLink {
                        TranscriptReplayView(entry: entry)
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.body)
                            Text("查看对话")
                                .font(.yuantiBody)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Color.clear)
            .navigationTitle("条目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("编辑") { showingEditSheet = true }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditEntrySheet(entry: entry) {
                    dismiss()
                    onDelete?(entry)
                }
            }
        }
    }
}

// MARK: - Transcript Replay View

private struct TranscriptReplayView: View {
    let entry: DiaryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let transcript = entry.decodedTranscript
                if transcript.isEmpty {
                    Text("暂无对话记录")
                        .foregroundStyle(.tertiary)
                        .padding()
                } else {
                    ForEach(transcript) { msg in
                        VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 4) {
                            // Inline photos
                            if !msg.photoFileNames.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(msg.photoFileNames, id: \.self) { fileName in
                                        let url = PhotoPickerService.photoURL(for: fileName)
                                        if let data = try? Data(contentsOf: url),
                                           let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }

                            // Inline videos
                            if !msg.videoFileNames.isEmpty {
                                VideoThumbnailsView(videoFileNames: msg.videoFileNames)
                            }

                            HStack {
                                if msg.role == "user" { Spacer(minLength: 40) }
                                Text(msg.content)
                                    .padding(10)
                                    .background(
                                        msg.role == "user"
                                            ? Color.claudeUserBubble
                                            : Color.claudeAssistantBubble
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                                    .font(.yuantiCallout)
                                if msg.role == "assistant" { Spacer(minLength: 40) }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("对话")
        .navigationBarTitleDisplayMode(.inline)
    }
}
