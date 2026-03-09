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

    @State private var isExpanded = false
    @State private var isVoiceMode = false
    @State private var micPulse = false
    @State private var showingLocationPicker = false
    @FocusState private var isTextFieldFocused: Bool

    // Radial fan configuration
    private let radialItems: [(icon: String, label: String)] = [
        ("mic.fill", "Voice"),
        ("camera.fill", "Photo"),
        ("video.fill", "Video"),
        ("location.fill", "Location")
    ]
    private let fanRadius: CGFloat = 65
    // Angles for upward arc: -150° to -30°, 4 items evenly spaced
    private let fanAngles: [Double] = [-150, -110, -70, -30]

    var body: some View {
        VStack(spacing: 8) {
            // Pending media previews
            pendingMediaRow

            // Video processing indicator
            if videoPickerService.isProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Processing video...")
                        .font(.caption)
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
        .onChange(of: speechService.transcribedText) { _, newValue in
            if speechService.isRecording && !newValue.isEmpty {
                text = newValue
            }
        }
    }

    // MARK: - Text Input Row (collapsed/expanded)

    private var textInputRow: some View {
        HStack(spacing: 10) {
            // Text field
            TextField("Say something...", text: $text, axis: .vertical)
                .focused($isTextFieldFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...4)

            // Bloom [+] button with radial fan
            ZStack {
                // Radial items (shown when expanded)
                ForEach(Array(radialItems.enumerated()), id: \.offset) { index, item in
                    radialButton(index: index, item: item)
                        .offset(radialOffset(for: index))
                        .opacity(isExpanded ? 1 : 0)
                        .scaleEffect(isExpanded ? 1 : 0.3)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.7)
                            .delay(isExpanded ? Double(index) * 0.04 : 0),
                            value: isExpanded
                        )
                }

                // Bloom button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                    if !isExpanded {
                        isTextFieldFocused = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isExpanded ? Color(.systemGray4) : Color.claudeAccent)
                            .frame(width: 36, height: 36)

                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isExpanded ? Color.primary : Color.white)
                            .rotationEffect(.degrees(isExpanded ? 45 : 0))
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            isExpanded = false
                            enterVoiceMode()
                        }
                )
            }
            .frame(width: 36, height: 36)
            .zIndex(1)

            // Send button
            Button {
                sendText()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Color.claudeAccent : .gray)
            }
            .disabled(!canSend || isStreaming)
        }
        .padding(.horizontal)
    }

    // MARK: - Radial Button

    @ViewBuilder
    private func radialButton(index: Int, item: (icon: String, label: String)) -> some View {
        switch index {
        case 1: // Photo
            PhotosPicker(
                selection: $photoPickerService.selectedItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                radialIcon(systemName: item.icon)
            }
            .onChange(of: photoPickerService.selectedItems) { _, _ in
                Task { await photoPickerService.processSelectedItems() }
                collapseBloom()
            }

        case 2: // Video
            PhotosPicker(
                selection: $videoPickerService.selectedItems,
                maxSelectionCount: 1,
                matching: .videos
            ) {
                radialIcon(systemName: item.icon)
            }
            .onChange(of: videoPickerService.selectedItems) { _, _ in
                Task { await videoPickerService.processSelectedItems() }
                collapseBloom()
            }

        default: // Voice (0), Location (3)
            Button {
                handleRadialTap(index)
            } label: {
                radialIcon(systemName: item.icon)
            }
        }
    }

    private func radialIcon(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.claudeSurfaceTint)
                .frame(width: 44, height: 44)

            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.claudeAccent)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private func radialOffset(for index: Int) -> CGSize {
        let angle = fanAngles[index] * .pi / 180
        return CGSize(
            width: cos(angle) * fanRadius,
            height: sin(angle) * fanRadius
        )
    }

    private func handleRadialTap(_ index: Int) {
        switch index {
        case 0: // Voice
            collapseBloom()
            enterVoiceMode()
        case 3: // Location
            collapseBloom()
            isTextFieldFocused = false
            showingLocationPicker = true
        default:
            break
        }
    }

    private func collapseBloom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            isExpanded = false
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

            Text(speechService.isRecording ? "Listening..." : "Tap to record")
                .font(.caption)
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
                        .font(.caption)
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
                                        .font(.system(size: 9, weight: .medium))
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
        let messageText = trimmed.isEmpty ? (videoFiles.isEmpty ? "[Photo]" : "[Video]") : trimmed
        onSend(messageText, photoFiles, videoFiles, location)
        text = ""
    }
}
