import SwiftUI
import AVFoundation

struct VideoThumbnailsView: View {
    let videoFileNames: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(videoFileNames, id: \.self) { fileName in
                    VideoThumbnailCard(fileName: fileName)
                }
            }
        }
    }
}

struct VideoThumbnailCard: View {
    let fileName: String
    @State private var thumbnail: UIImage?
    @State private var showingPlayer = false

    var body: some View {
        Button {
            showingPlayer = true
        } label: {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 160, height: 90)
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 3)
            }
        }
        .buttonStyle(.plain)
        .task {
            await generateThumbnail()
        }
        .sheet(isPresented: $showingPlayer) {
            VideoPlayerSheet(fileName: fileName)
        }
    }

    private func generateThumbnail() async {
        let url = VideoPickerService.videoURL(for: fileName)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)

        let time = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            await MainActor.run {
                self.thumbnail = UIImage(cgImage: cgImage)
            }
        }
    }
}
