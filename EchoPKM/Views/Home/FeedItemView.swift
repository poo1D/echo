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
                    .font(.yuanti(15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(data.subtitle)
                    .font(.yuantiCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .glassCard(tint: .glassDefaultTint, cornerRadius: 14)
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
                // Stacked photo display
                if !data.photoFileNames.isEmpty {
                    StackedPhotosView(photoFileNames: data.photoFileNames)
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
                    .font(.yuantiBody)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Stacked Photos View

private struct StackedPhotosView: View {
    let photoFileNames: [String]

    // Order tracks which photo is on top; indices into photoFileNames
    @State private var order: [Int] = []
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    // Transforms for background cards (index 0 = bottom-most visible)
    private static let bgTransforms: [(rotation: Double, x: CGFloat, y: CGFloat)] = [
        (-8, -25, 14),
        (6,  20, -10),
        (-4, -15, -16),
        (5,  18,  8),
    ]

    var body: some View {
        let count = photoFileNames.count

        if count == 1 {
            singlePhotoView(fileName: photoFileNames[0])
        } else {
            stackedDraggableView
        }
    }

    // MARK: - Single Photo

    private func singlePhotoView(fileName: String) -> some View {
        let url = PhotoPickerService.photoURL(for: fileName)
        return Group {
            if let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 200)
            }
        }
    }

    // MARK: - Stacked + Draggable

    private var stackedDraggableView: some View {
        let indices = currentOrder
        let total = indices.count
        // Show up to 3 cards: bottom cards first, top card last
        let visible = Array(indices.suffix(min(3, total)))

        return ZStack {
            ForEach(Array(visible.enumerated()), id: \.element) { stackPos, photoIndex in
                let isTop = stackPos == visible.count - 1
                let depth = visible.count - 1 - stackPos  // 0 = top, 1 = second, 2 = third

                photoCard(fileName: photoFileNames[photoIndex], size: isTop ? 155 : 135)
                    .rotationEffect(cardRotation(isTop: isTop, depth: depth))
                    .offset(cardOffset(isTop: isTop, depth: depth))
                    .scaleEffect(isTop ? 1.0 : 1.0 - CGFloat(depth) * 0.04)
                    .zIndex(Double(stackPos))
                    .gesture(isTop ? dragGesture : nil)
            }

            // Photo counter badge
            if total > 1 {
                Text("\(topDisplayIndex + 1)/\(total)")
                    .font(.yuanti(11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.5), in: Capsule())
                    .offset(x: 55, y: -75)
                    .zIndex(10)
            }
        }
        .frame(width: 220, height: 220)
        .onAppear {
            if order.isEmpty {
                order = Array(0..<photoFileNames.count)
            }
        }
    }

    private var currentOrder: [Int] {
        order.isEmpty ? Array(0..<photoFileNames.count) : order
    }

    private var topDisplayIndex: Int {
        currentOrder.last ?? 0
    }

    // MARK: - Card Transforms

    private func cardRotation(isTop: Bool, depth: Int) -> Angle {
        if isTop {
            // Slight rotation follows drag
            return .degrees(Double(dragOffset.width) / 20)
        }
        let t = Self.bgTransforms[depth % Self.bgTransforms.count]
        return .degrees(t.rotation)
    }

    private func cardOffset(isTop: Bool, depth: Int) -> CGSize {
        if isTop {
            return dragOffset
        }
        let t = Self.bgTransforms[depth % Self.bgTransforms.count]
        return CGSize(width: t.x, height: t.y)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 60
                let totalDrag = abs(value.translation.width) + abs(value.translation.height)

                if totalDrag > threshold {
                    // Fling the top card away, then cycle
                    let flyX = value.translation.width * 3
                    let flyY = value.translation.height * 3

                    withAnimation(.easeIn(duration: 0.2)) {
                        dragOffset = CGSize(width: flyX, height: flyY)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // Move top card to the bottom
                        var newOrder = currentOrder
                        let top = newOrder.removeLast()
                        newOrder.insert(top, at: 0)

                        dragOffset = .zero
                        isDragging = false

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            order = newOrder
                        }
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }
            }
    }

    // MARK: - Photo Card

    private func photoCard(fileName: String, size: CGFloat) -> some View {
        let url = PhotoPickerService.photoURL(for: fileName)
        return Group {
            if let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size * 1.2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white, lineWidth: 2.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size * 1.2)
            }
        }
    }
}

// MARK: - Agent Pipeline Visualization

struct AgentPipelineView: View {
    let snapshot: PipelineSnapshot

    var body: some View {
        VStack(spacing: 10) {
            // Intent label
            if let intentType = snapshot.intentType {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 11, weight: .semibold))
                    Text(intentType)
                        .font(.yuanti(12, weight: .semibold))
                }
                .foregroundStyle(Color.claudeAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.claudeAccent.opacity(0.1), in: Capsule())
            }

            // Agent circles row
            HStack(spacing: 16) {
                AgentCircle(
                    emoji: "🧠",
                    name: "情绪",
                    status: snapshot.emotionStatus
                )
                AgentCircle(
                    emoji: "🔎",
                    name: "记忆",
                    status: snapshot.memoryStatus
                )
                AgentCircle(
                    emoji: "⚡",
                    name: "行动",
                    status: snapshot.actionStatus
                )
                AgentCircle(
                    emoji: "💚",
                    name: "健康",
                    status: snapshot.healthStatus
                )
            }

            // Connector lines to synthesis
            if isSynthesizing || isSynthesisComplete {
                VStack(spacing: 4) {
                    // Converging lines visual
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.claudeAccent.opacity(0.3))
                                .frame(width: 1, height: 16)
                        }
                    }
                    .frame(width: 60)

                    // Synthesis bubble
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.claudeAccent)

                        if case .running = snapshot.synthesisStatus {
                            ThinkingDotsView()
                        } else if case .completed = snapshot.synthesisStatus {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "4CAF50"))
                        } else {
                            Text("合成中")
                                .font(.yuantiCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.claudeAssistantBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                }
            }

            // RAG status (compact)
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10))
                    .foregroundStyle(statusColor(snapshot.ragStatus))
                if case .completed(let summary) = snapshot.ragStatus {
                    Text(summary)
                        .font(.yuantiCaption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .glassCard(tint: nil, cornerRadius: 14)
        .padding(.horizontal)
    }

    private var isSynthesizing: Bool {
        if case .running = snapshot.synthesisStatus { return true }
        return false
    }

    private var isSynthesisComplete: Bool {
        if case .completed = snapshot.synthesisStatus { return true }
        return false
    }

    private func statusColor(_ status: PipelineSnapshot.AgentStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .running: return Color.claudeAccent
        case .completed: return Color(hex: "4CAF50")
        case .skipped: return .gray.opacity(0.4)
        case .failed: return .red.opacity(0.7)
        }
    }
}

// MARK: - Agent Circle

private struct AgentCircle: View {
    let emoji: String
    let name: String
    let status: PipelineSnapshot.AgentStatus

    @State private var rotation: Double = 0
    @State private var showCheck = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .fill(circleBackground)
                    .frame(width: 44, height: 44)

                // Running: spinning ring
                if case .running = status {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.claudeAccent, lineWidth: 2.5)
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(rotation))
                }

                // Skipped: dashed circle
                if case .skipped = status {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.gray.opacity(0.4))
                        .frame(width: 44, height: 44)
                }

                // Content
                if case .skipped = status {
                    Text("--")
                        .font(.yuanti(12, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.5))
                } else if showCheck {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "4CAF50"))
                        .transition(.scale.combined(with: .opacity))
                } else if case .failed = status {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red.opacity(0.7))
                } else {
                    Text(emoji)
                        .font(.system(size: 18))
                }
            }

            Text(name)
                .font(.yuanti(11, weight: .medium))
                .foregroundStyle({
                    switch status {
                    case .skipped: return Color.secondary.opacity(0.5)
                    default: return Color.secondary
                    }
                }())
        }
        .onAppear {
            if case .running = status {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
        .onChange(of: status) { oldStatus, newStatus in
            if case .completed = newStatus {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showCheck = true
                }
            }
            if case .running = newStatus {
                rotation = 0
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }

    private var circleBackground: Color {
        switch status {
        case .idle: return Color(hex: "F0F0F2")
        case .running: return Color.claudeAccent.opacity(0.1)
        case .completed: return Color(hex: "E8F5E9")
        case .skipped: return Color(hex: "F5F5F5")
        case .failed: return Color.red.opacity(0.08)
        }
    }
}

// MARK: - Thinking Dots Animation

private struct ThinkingDotsView: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.claudeAccent)
                    .frame(width: 5, height: 5)
                    .offset(y: dotOffsets[index])
            }
        }
        .onAppear {
            for i in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
                ) {
                    dotOffsets[i] = -4
                }
            }
        }
    }
}

// MARK: - Assistant Message (with Rich Cards) — blue soft-glow bubble

private struct AssistantMessageView: View {
    let data: AssistantMessageData

    // Echo blue palette
    private let echoBubbleBg = Color(hex: "EFF4FF")       // very pale blue
    private let echoGlowColor = Color(hex: "5B9CF6")      // soft blue for glow

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Rich content cards
                ForEach(data.richCards) { card in
                    RichContentCardView(content: card)
                }

                // Text content — pale blue bg + blue soft-glow shadow
                if !data.textContent.isEmpty {
                    Text(data.textContent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(echoBubbleBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: echoGlowColor.opacity(0.18), radius: 8, y: 2)
                        .shadow(color: echoGlowColor.opacity(0.08), radius: 16, y: 4)
                        .foregroundStyle(.primary)
                        .font(.yuantiBody)
                } else if data.richCards.isEmpty {
                    // Loading state — show thinking dots while pipeline is running
                    ThinkingDotsView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(echoBubbleBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: echoGlowColor.opacity(0.12), radius: 8, y: 2)
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
                    .font(.yuanti(12, weight: .medium))
                    .foregroundStyle(.primary)
                Text(data.detail)
                    .font(.yuantiCaption2)
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
        .glassCardCompact(tint: .glassSuccessTint)
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
