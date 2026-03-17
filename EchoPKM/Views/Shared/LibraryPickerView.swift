import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 使用 PHPickerViewController 的相册选择器
/// 相比 SwiftUI PhotosPicker，支持 Live Photo（静态图 + 动态视频同时保留）
struct LibraryPickerView: UIViewControllerRepresentable {

    var photoPickerService: PhotoPickerService
    var videoPickerService: VideoPickerService
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 5
        config.filter = .any(of: [.images, .videos, .livePhotos])
        // 保留原始格式（Live Photo 的 .mov 组件不会被转码）
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPickerView

        init(parent: LibraryPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard !results.isEmpty else { return }

            for result in results {
                let provider = result.itemProvider
                if provider.hasItemConformingToTypeIdentifier(UTType.livePhoto.identifier) {
                    handleLivePhoto(provider)
                } else if provider.canLoadObject(ofClass: UIImage.self) {
                    handleImage(provider)
                } else {
                    // 普通视频
                    handleVideo(provider)
                }
            }
        }

        // MARK: Live Photo → 静态图 + 动态视频

        private func handleLivePhoto(_ provider: NSItemProvider) {
            // 1. 静态帧存入 photoPickerService
            provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                guard let image = obj as? UIImage else { return }
                Task { @MainActor in
                    self?.parent.photoPickerService.addCapturedImage(image)
                }
            }

            // 2. 动态视频存入 videoPickerService（QuickTime .mov）
            let movType = UTType.quickTimeMovie.identifier
            let fallbackType = UTType.movie.identifier
            let videoType = provider.hasItemConformingToTypeIdentifier(movType) ? movType : fallbackType

            provider.loadFileRepresentation(forTypeIdentifier: videoType) { [weak self] url, error in
                guard let url, error == nil else { return }
                // PHPicker 给的 URL 在 completion 后失效，需先复制
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".mov")
                try? FileManager.default.copyItem(at: url, to: tempURL)
                Task { @MainActor in
                    await self?.parent.videoPickerService.addCapturedVideo(from: tempURL)
                }
            }
        }

        // MARK: 普通图片

        private func handleImage(_ provider: NSItemProvider) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                guard let image = obj as? UIImage else { return }
                Task { @MainActor in
                    self?.parent.photoPickerService.addCapturedImage(image)
                }
            }
        }

        // MARK: 普通视频

        private func handleVideo(_ provider: NSItemProvider) {
            let movType = UTType.quickTimeMovie.identifier
            let mp4Type = UTType.mpeg4Movie.identifier
            let fallback = UTType.movie.identifier
            let typeId: String
            if provider.hasItemConformingToTypeIdentifier(movType) {
                typeId = movType
            } else if provider.hasItemConformingToTypeIdentifier(mp4Type) {
                typeId = mp4Type
            } else {
                typeId = fallback
            }

            provider.loadFileRepresentation(forTypeIdentifier: typeId) { [weak self] url, error in
                guard let url, error == nil else { return }
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "." + ext)
                try? FileManager.default.copyItem(at: url, to: tempURL)
                Task { @MainActor in
                    await self?.parent.videoPickerService.addCapturedVideo(from: tempURL)
                }
            }
        }
    }
}
