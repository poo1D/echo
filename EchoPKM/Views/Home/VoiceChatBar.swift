import SwiftUI
import PhotosUI

/// Voice-first input bar with large mic button, text field, photo picker, and location
struct VoiceChatBar: View {
    @Binding var text: String
    var speechService: SpeechService
    var isStreaming: Bool
    @Bindable var photoPickerService: PhotoPickerService
    @Bindable var locationService: LocationService
    var onSend: (String, [String], PendingLocation?) -> Void

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
        !text.trimmingCharacters(in: .whitespaces).isEmpty || !photoPickerService.pendingImages.isEmpty
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
        let location = locationService.consumePending()
        guard !trimmed.isEmpty || !photoFiles.isEmpty else { return }
        let messageText = trimmed.isEmpty ? "[Photo]" : trimmed
        onSend(messageText, photoFiles, location)
        text = ""
    }
}
