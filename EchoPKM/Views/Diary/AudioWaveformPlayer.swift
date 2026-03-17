import SwiftUI
import AVFoundation

struct AudioWaveformPlayer: View {
    let fileName: String

    @State private var samples: [Float] = []
    @State private var duration: TimeInterval = 0
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var progressTimer: Timer?

    private let barCount = 50

    var body: some View {
        HStack(spacing: 10) {
            // Play/pause button
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)
            }

            // Waveform
            waveformView
                .frame(height: 32)

            // Duration
            Text(formatDuration(isPlaying ? duration * (1 - progress) : duration))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
        .onAppear { loadAudioData() }
        .onDisappear { stopPlayback() }
    }

    // MARK: - Waveform Canvas

    private var waveformView: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard !samples.isEmpty else { return }

                let barWidth: CGFloat = max(2, (size.width - CGFloat(samples.count - 1) * 1.5) / CGFloat(samples.count))
                let spacing: CGFloat = 1.5
                let midY = size.height / 2

                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * (barWidth + spacing)
                    let barHeight = max(2, CGFloat(sample) * size.height * 0.9)
                    let rect = CGRect(
                        x: x,
                        y: midY - barHeight / 2,
                        width: barWidth,
                        height: barHeight
                    )
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                    let progressThreshold = progress * size.width
                    let color: Color = x < progressThreshold ? .blue : Color(.systemGray4)
                    context.fill(path, with: .color(color))
                }
            }
        }
    }

    // MARK: - Audio Data Loading

    private func loadAudioData() {
        let url = SpeechService.audioURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard frameCount > 0 else { return }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let totalFrames = Int(buffer.frameLength)

            // Downsample to barCount amplitude values
            let samplesPerBar = max(1, totalFrames / barCount)
            var amplitudes: [Float] = []

            for i in 0..<barCount {
                let start = i * samplesPerBar
                let end = min(start + samplesPerBar, totalFrames)
                guard start < totalFrames else { break }

                var sum: Float = 0
                for j in start..<end {
                    sum += abs(channelData[j])
                }
                amplitudes.append(sum / Float(end - start))
            }

            // Normalize to 0...1
            let maxAmp = amplitudes.max() ?? 1
            if maxAmp > 0 {
                amplitudes = amplitudes.map { $0 / maxAmp }
            }

            samples = amplitudes
            duration = Double(totalFrames) / format.sampleRate
        } catch {
            // Silently fail — card will just not show waveform
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        let url = SpeechService.audioURL(for: fileName)
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback 分类默认走扬声器，overrideOutputAudioPort 仅对 .playAndRecord 有效，不能在此调用
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1.0
            player?.play()
            isPlaying = true

            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let player = player else { return }
                if player.isPlaying {
                    progress = player.currentTime / player.duration
                } else {
                    stopPlayback()
                }
            }
        } catch {
            isPlaying = false
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
