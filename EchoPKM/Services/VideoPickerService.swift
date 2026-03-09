import SwiftUI
import PhotosUI
import AVFoundation

struct PendingVideo: Identifiable {
    let id = UUID()
    let fileName: String
    let thumbnail: UIImage
    let duration: TimeInterval
}

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

@Observable @MainActor
final class VideoPickerService {
    var selectedItems: [PhotosPickerItem] = []
    var pendingVideos: [PendingVideo] = []
    var isProcessing = false

    func processSelectedItems() async {
        guard !selectedItems.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        for item in selectedItems {
            guard let video = try? await item.loadTransferable(type: VideoTransferable.self) else { continue }

            let sourceURL = video.url
            let asset = AVURLAsset(url: sourceURL)

            // Check duration (max 60s)
            guard let duration = try? await asset.load(.duration) else { continue }
            let durationSeconds = CMTimeGetSeconds(duration)
            guard durationSeconds > 0 && durationSeconds <= 60 else { continue }

            // Compress with AVAssetExportSession
            let fileName = "video_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).mp4"
            let outputURL = Self.videoURL(for: fileName)

            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else { continue }
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4

            await exportSession.export()
            guard exportSession.status == .completed else { continue }

            // Generate thumbnail
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: outputURL))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 240)

            let thumbnailTime = CMTimeMakeWithSeconds(min(1.0, durationSeconds / 2), preferredTimescale: 600)
            let thumbnail: UIImage
            if let cgImage = try? generator.copyCGImage(at: thumbnailTime, actualTime: nil) {
                thumbnail = UIImage(cgImage: cgImage)
            } else {
                thumbnail = UIImage(systemName: "video.fill")!
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: sourceURL)

            pendingVideos.append(PendingVideo(fileName: fileName, thumbnail: thumbnail, duration: durationSeconds))
        }
        selectedItems.removeAll()
    }

    func removePending(id: UUID) {
        if let video = pendingVideos.first(where: { $0.id == id }) {
            let url = Self.videoURL(for: video.fileName)
            try? FileManager.default.removeItem(at: url)
        }
        pendingVideos.removeAll { $0.id == id }
    }

    func consumePendingFileNames() -> [String] {
        let names = pendingVideos.map(\.fileName)
        pendingVideos.removeAll()
        return names
    }

    static func videoURL(for fileName: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
