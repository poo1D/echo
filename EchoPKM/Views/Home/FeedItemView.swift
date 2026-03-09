import SwiftUI

// MARK: - Feed Item Router

struct FeedItemView: View {
    let item: FeedItem

    var body: some View {
        switch item {
        case .proactiveCard(let data):
            ProactiveCardView(data: data)
        case .userMessage(let data):
            UserBubbleView(data: data)
        case .agentPipeline(let snapshot):
            AgentPipelineView(snapshot: snapshot)
        case .assistantMessage(let data):
            AssistantMessageView(data: data)
        case .actionConfirm(let data):
            ActionConfirmView(data: data)
        }
    }
}

// MARK: - Proactive Card

private struct ProactiveCardView: View {
    let data: ProactiveCardData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: data.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: data.iconColor))
                .frame(width: 36, height: 36)
                .background(Color(hex: data.iconColor).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(data.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.claudeAssistantBubble)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - User Bubble

private struct UserBubbleView: View {
    let data: UserMessageData

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 6) {
                // Photo thumbnails
                if !data.photoFileNames.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(data.photoFileNames, id: \.self) { fileName in
                            let url = PhotoPickerService.photoURL(for: fileName)
                            if let imageData = try? Data(contentsOf: url),
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }

                // Video thumbnails
                if !data.videoFileNames.isEmpty {
                    VideoThumbnailsView(videoFileNames: data.videoFileNames)
                }

                Text(data.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.claudeUserBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                    .foregroundStyle(.primary)
                    .font(.body)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Agent Pipeline Visualization

struct AgentPipelineView: View {
    let snapshot: PipelineSnapshot

    var body: some View {
        VStack(spacing: 6) {
            // Phase 0: On-device RAG
            agentRow(icon: "antenna.radiowaves.left.and.right",
                     name: "语义检索",
                     status: snapshot.ragStatus)
            agentRow(icon: "brain.head.profile", name: "情绪分析", status: snapshot.emotionStatus)
            agentRow(icon: "magnifyingglass", name: "记忆分析", status: snapshot.memoryStatus)
            agentRow(icon: "bolt.fill", name: "行动提取", status: snapshot.actionStatus)

            if case .running = snapshot.synthesisStatus {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.claudeAccent)
                    Text("正在综合回复...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color(hex: "F8F8FA"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func agentRow(icon: String, name: String, status: PipelineSnapshot.AgentStatus) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(statusColor(status))
                .frame(width: 16)

            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            switch status {
            case .idle:
                Text("Waiting")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            case .running:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Running...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .completed(let summary):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "4CAF50"))
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            case .failed:
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.7))
                    Text("Failed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusColor(_ status: PipelineSnapshot.AgentStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .running: return Color.claudeAccent
        case .completed: return Color(hex: "4CAF50")
        case .failed: return .red.opacity(0.7)
        }
    }
}

// MARK: - Assistant Message (with Rich Cards)

private struct AssistantMessageView: View {
    let data: AssistantMessageData

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // AI avatar
            Circle()
                .fill(Color.claudeAccent)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                // Rich content cards
                ForEach(data.richCards) { card in
                    RichContentCardView(content: card)
                }

                // Text content
                if !data.textContent.isEmpty {
                    Text(data.textContent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.claudeAssistantBubble)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                        .foregroundStyle(.primary)
                        .font(.body)
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal)
    }
}

// MARK: - Action Confirm

private struct ActionConfirmView: View {
    let data: ActionConfirmData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: actionIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "4CAF50"))

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(data.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if data.isExecuted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "4CAF50"))
            }
        }
        .padding(10)
        .background(Color(hex: "E8F5E9").opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "4CAF50").opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var actionIcon: String {
        switch data.actionType {
        case .scheduleCreated: return "calendar.badge.plus"
        case .habitLogged: return "flame.fill"
        case .moodRecorded: return "heart.fill"
        }
    }
}
