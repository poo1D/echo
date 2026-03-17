import SwiftUI
import PhotosUI

struct MultimodalInputBar: View {
    @Binding var text: String
    var speechService: SpeechService
    var isStreaming: Bool
    @Bindable var photoPickerService: PhotoPickerService
    @Bindable var videoPickerService: VideoPickerService
    @Bindable var locationService: LocationService
    var onSend: (String, [String], [String], PendingLocation?) -> Void

    @State private var isVoiceMode = false
    @State private var micPulse = false
    @State private var showingLocationPicker = false
    @FocusState private var isTextFieldFocused: Bool

    // Swipe gesture state
    @State private var isLongPressing = false
    @State private var swipeOffset: CGSize = .zero
    @State private var selectedDirection: SwipeDirection? = nil
    @State private var showCamera = false
    @State private var showMediaLibrary = false

    // Swipe direction enum
    enum SwipeDirection: CaseIterable {
        case left   // 相机（拍照/录视频）
        case up     // 语音
        case right  // 相册（图片/视频）

        var icon: String {
            switch self {
            case .left: return "camera.fill"
            case .up: return "mic.fill"
            case .right: return "photo.fill"
            }
        }

        var tint: Color {
            switch self {
            case .left: return .blue
            case .up: return .orange
            case .right: return .green
            }
        }

        var offset: CGSize {
            switch self {
            case .left: return CGSize(width: -76, height: -52)
            case .up: return CGSize(width: 0, height: -90)
            case .right: return CGSize(width: 76, height: -52)
            }
        }
    }

    // Threshold for direction detection
    private let activationThreshold: CGFloat = 35

    var body: some View {
        VStack(spacing: 8) {
            // Pending media previews
            pendingMediaRow

            // Video processing indicator
            if videoPickerService.isProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("处理视频中...")
                        .font(.yuantiCaption)
                        .foregroundStyle(.secondary)
                }
            }

            if isVoiceMode {
                voiceModeView
            } else {
                textInputRow
            }
        }
        .padding(.bottom, 8)
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(locationService: locationService)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CustomCameraView(
                onPhotoCapture: { image in
                    photoPickerService.addCapturedImage(image)
                },
                onVideoCapture: { url in
                    Task { await videoPickerService.addCapturedVideo(from: url) }
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMediaLibrary) {
            LibraryPickerView(
                photoPickerService: photoPickerService,
                videoPickerService: videoPickerService
            )
        }
        .onChange(of: speechService.transcribedText) { _, newValue in
            if speechService.isRecording && !newValue.isEmpty {
                text = newValue
            }
        }
        .onChange(of: photoPickerService.selectedItems) { _, _ in
            Task { await photoPickerService.processSelectedItems() }
        }
        .onChange(of: videoPickerService.selectedItems) { _, _ in
            Task { await videoPickerService.processSelectedItems() }
        }
    }

    // MARK: - Main Input View (Swipe-first design)

    private var textInputRow: some View {
        VStack(spacing: 12) {
            // Primary: Large swipe button
            ZStack {
                // Swipe direction indicators (shown during long press)
                if isLongPressing {
                    swipeIndicatorsView
                        .transition(.opacity.combined(with: .scale))
                }

                // Main + button with gesture
                swipeGestureButton
            }
            .frame(height: 56)

            // Hint text
            if !isLongPressing && !isTextFieldFocused {
                Text("长按选择")
                    .font(.yuantiCaption2)
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }

            // Secondary: Compact text input row
            HStack(spacing: 8) {
                // Expand to text field
                TextField("或者打字...", text: $text, axis: .vertical)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.yuantiSubheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                    .lineLimit(1...3)

                // Location button
                Button {
                    isTextFieldFocused = false
                    showingLocationPicker = true
                } label: {
                    Image(systemName: locationService.pendingLocation != nil ? "location.fill" : "location")
                        .font(.system(size: 18))
                        .foregroundStyle(locationService.pendingLocation != nil ? .orange : Color(.tertiaryLabel))
                }

                // Send button
                Button {
                    sendText()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canSend ? Color.claudeAccent : Color(.systemGray4))
                }
                .disabled(!canSend || isStreaming)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Swipe Gesture Button (Larger, primary)

    private var swipeGestureButton: some View {
        ZStack {
            // Outer glow when active
            if isLongPressing {
                Circle()
                    .fill(Color.claudeAccent.opacity(0.15))
                    .frame(width: 72, height: 72)
                    .blur(radius: 8)
            }

            Circle()
                .fill(isLongPressing ? Color(.systemGray4) : Color.claudeAccent)
                .frame(width: 56, height: 56)
                .shadow(color: Color.claudeAccent.opacity(isLongPressing ? 0.1 : 0.35), radius: isLongPressing ? 2 : 6, y: 2)
                .scaleEffect(isLongPressing ? 0.9 : 1.0)

            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(isLongPressing ? Color.primary : Color.white)
                .rotationEffect(.degrees(isLongPressing ? 45 : 0))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLongPressing)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isLongPressing && value.translation == .zero {
                        // Start long press detection
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            isLongPressing = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }

                    if isLongPressing {
                        swipeOffset = value.translation
                        let newDirection = detectDirection(from: swipeOffset)
                        if newDirection != selectedDirection {
                            selectedDirection = newDirection
                            if newDirection != nil {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                }
                .onEnded { _ in
                    if let direction = selectedDirection {
                        handleDirectionSelection(direction)
                    }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isLongPressing = false
                        swipeOffset = .zero
                        selectedDirection = nil
                    }
                }
        )
    }

    // MARK: - Swipe Direction Indicators (Icons only)

    private var swipeIndicatorsView: some View {
        ZStack {
            // Background blur overlay
            Circle()
                .fill(Color.claudeSurfaceTint.opacity(0.4))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(y: -36)

            // Direction options (icons only)
            ForEach(SwipeDirection.allCases, id: \.self) { direction in
                swipeOptionView(for: direction)
                    .offset(direction.offset)
            }
        }
    }

    private func swipeOptionView(for direction: SwipeDirection) -> some View {
        let isSelected = selectedDirection == direction
        let size: CGFloat = isSelected ? 70 : 62

        return ZStack {
            // Liquidglass base — frosted material circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)

            // Tinted overlay — only when selected
            if isSelected {
                Circle()
                    .fill(direction.tint.opacity(0.22))
                    .frame(width: size, height: size)
            }

            // Border — neutral when idle, tinted when selected
            Circle()
                .strokeBorder(
                    isSelected ? direction.tint.opacity(0.70) : Color.primary.opacity(0.12),
                    lineWidth: isSelected ? 1.5 : 1.0
                )
                .frame(width: size, height: size)

            // Icon — colored when selected, secondary when idle
            Image(systemName: direction.icon)
                .font(.system(size: isSelected ? 28 : 24, weight: .semibold))
                .foregroundStyle(isSelected ? direction.tint : Color.secondary)
        }
        .shadow(
            color: isSelected ? direction.tint.opacity(0.45) : Color.black.opacity(0.08),
            radius: isSelected ? 16 : 5,
            y: isSelected ? 5 : 2
        )
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
    }

    // MARK: - Direction Detection

    private func detectDirection(from offset: CGSize) -> SwipeDirection? {
        let distance = sqrt(offset.width * offset.width + offset.height * offset.height)
        guard distance > activationThreshold else { return nil }

        // Calculate angle (in degrees, 0 = right, 90 = up, 180/-180 = left, -90 = down)
        let angle = atan2(-offset.height, offset.width) * 180 / .pi

        // Map angles to directions (only upward semicircle)
        if angle > 120 || angle < -150 {
            // Left-upper quadrant → Photo
            return .left
        } else if angle >= 60 && angle <= 120 {
            // Top → Voice
            return .up
        } else if angle > 0 && angle < 60 {
            // Right-upper quadrant → Video
            return .right
        }

        return nil
    }

    private func handleDirectionSelection(_ direction: SwipeDirection) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        isTextFieldFocused = false

        switch direction {
        case .left:
            if isCameraAvailable {
                showCamera = true
            } else {
                // 模拟器没有相机，降级为相册
                showMediaLibrary = true
            }
        case .up:
            enterVoiceMode()
        case .right:
            showMediaLibrary = true
        }
    }

    // MARK: - Voice Mode

    private var voiceModeView: some View {
        VStack(spacing: 16) {
            // Waveform placeholder
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.claudeAccent.opacity(0.6))
                        .frame(width: 3, height: speechService.isRecording ? CGFloat.random(in: 8...28) : 8)
                        .animation(
                            .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.05),
                            value: speechService.isRecording
                        )
                }
            }
            .frame(height: 32)

            // Pulsing mic button
            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.red : Color.claudeAccent)
                    .frame(width: 64, height: 64)
                    .shadow(
                        color: (speechService.isRecording ? Color.red : Color.claudeAccent).opacity(0.4),
                        radius: 8, y: 2
                    )

                Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(micPulse ? 1.1 : 1.0)
            .onTapGesture {
                Task { await toggleRecording() }
            }
            .onChange(of: speechService.isRecording) { _, recording in
                if recording {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        micPulse = true
                    }
                } else {
                    withAnimation(.default) {
                        micPulse = false
                    }
                }
            }

            Text(speechService.isRecording ? "聆听中..." : "点击录音")
                .font(.yuantiCaption)
                .foregroundStyle(.secondary)

            // Cancel / Send row
            HStack(spacing: 40) {
                Button {
                    exitVoiceMode()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }

                Button {
                    if speechService.isRecording {
                        speechService.stopRecording()
                    }
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        sendText()
                    }
                    exitVoiceMode()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? Color.claudeAccent : .gray)
                }
                .disabled(!canSend)
            }
        }
        .padding(.vertical, 8)
        .transition(.opacity)
    }

    // MARK: - Pending Media Row

    private var pendingMediaRow: some View {
        VStack(spacing: 8) {
            // Location
            if let loc = locationService.pendingLocation {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(loc.name)
                        .font(.yuantiCaption)
                        .lineLimit(1)
                    Button {
                        locationService.clearPending()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.08), in: Capsule())
            }

            // Photos
            if !photoPickerService.pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photoPickerService.pendingImages) { photo in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photo.thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    photoPickerService.removePending(id: photo.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Videos
            if !videoPickerService.pendingVideos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(videoPickerService.pendingVideos) { video in
                            ZStack(alignment: .topTrailing) {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(uiImage: video.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                        .frame(width: 80, height: 60)

                                    Text(VideoPickerService.formatDuration(video.duration))
                                        .font(.yuanti(9, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
                                        .padding(4)
                                }

                                Button {
                                    videoPickerService.removePending(id: video.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Actions

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
            || !photoPickerService.pendingImages.isEmpty
            || !videoPickerService.pendingVideos.isEmpty
    }

    private func enterVoiceMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVoiceMode = true
        }
        text = ""
        Task { await speechService.startRecording() }
    }

    private func exitVoiceMode() {
        if speechService.isRecording {
            speechService.stopRecording()
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            isVoiceMode = false
        }
    }

    private func toggleRecording() async {
        isTextFieldFocused = false
        if speechService.isRecording {
            speechService.stopRecording()
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                sendText()
                exitVoiceMode()
            }
        } else {
            text = ""
            await speechService.startRecording()
        }
    }

    private func sendText() {
        isTextFieldFocused = false
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let photoFiles = photoPickerService.consumePendingFileNames()
        let videoFiles = videoPickerService.consumePendingFileNames()
        let location = locationService.consumePending()
        guard !trimmed.isEmpty || !photoFiles.isEmpty || !videoFiles.isEmpty else { return }
        let messageText = trimmed.isEmpty ? (videoFiles.isEmpty ? "[照片]" : "[视频]") : trimmed
        onSend(messageText, photoFiles, videoFiles, location)
        text = ""
    }
}
