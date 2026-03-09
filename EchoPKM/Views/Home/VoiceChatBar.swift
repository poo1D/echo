import SwiftUI
import PhotosUI

/// Voice-first input bar with large mic button, text field, photo picker, video picker, and location
struct VoiceChatBar: View {
    @Binding var text: String
    var speechService: SpeechService
    var isStreaming: Bool
    @Bindable var photoPickerService: PhotoPickerService
    @Bindable var videoPickerService: VideoPickerService
    @Bindable var locationService: LocationService
    var onSend: (String, [String], [String], PendingLocation?) -> Void

    @State private var showingTextField = false
    @State private var showingLocationPicker = false
    @State private var micPulse = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Pending location label
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

            // Pending photos preview
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

            // Pending videos preview
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

                                    // Play icon overlay
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                        .frame(width: 80, height: 60)

                                    // Duration badge
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

            // Text input row
            HStack(spacing: 10) {
                // Photo picker button
                PhotosPicker(
                    selection: $photoPickerService.selectedItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
                .onChange(of: photoPickerService.selectedItems) { _, _ in
                    Task { await photoPickerService.processSelectedItems() }
                }

                // Video picker button
                PhotosPicker(
                    selection: $videoPickerService.selectedItems,
                    maxSelectionCount: 1,
                    matching: .videos
                ) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
                .onChange(of: videoPickerService.selectedItems) { _, _ in
                    Task { await videoPickerService.processSelectedItems() }
                }

                // Location button
                Button {
                    isTextFieldFocused = false
                    showingLocationPicker = true
                } label: {
                    Image(systemName: locationService.pendingLocation != nil ? "location.fill" : "location")
                        .font(.system(size: 20))
                        .foregroundStyle(locationService.pendingLocation != nil ? .orange : .blue)
                }

                TextField("Say something...", text: $text, axis: .vertical)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...4)

                // Send button
                Button {
                    sendText()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? .blue : .gray)
                }
                .disabled(!canSend || isStreaming)
            }
            .padding(.horizontal)

            // Mic button
            Button {
                Task { await toggleRecording() }
            } label: {
                ZStack {
                    Circle()
                        .fill(speechService.isRecording ? Color.red : Color.blue)
                        .frame(width: 64, height: 64)
                        .shadow(color: (speechService.isRecording ? Color.red : Color.blue).opacity(0.4), radius: 8, y: 2)

                    Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(isStreaming)
            .scaleEffect(micPulse ? 1.1 : 1.0)
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

            if speechService.isRecording {
                Text("Listening...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("tap to talk")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty || !photoPickerService.pendingImages.isEmpty || !videoPickerService.pendingVideos.isEmpty
    }

    private func toggleRecording() async {
        isTextFieldFocused = false
        if speechService.isRecording {
            speechService.stopRecording()
            // Auto-send if there's transcribed text
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                sendText()
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
