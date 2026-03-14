import SwiftUI
import AVFoundation

/// 相机拍照 / 录像的 UIViewControllerRepresentable 包装器
/// mediaTypes 同时包含图片和视频，用户可在相机 UI 内切换
struct CameraPickerView: UIViewControllerRepresentable {

    var onPhotoCapture: ((UIImage) -> Void)?
    var onVideoCapture: ((URL) -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.videoQuality = .typeMedium
        picker.videoMaximumDuration = 60
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let mediaType = info[.mediaType] as? String
            parent.dismiss()

            if mediaType == "public.image" {
                let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
                if let image {
                    parent.onPhotoCapture?(image)
                }
            } else if mediaType == "public.movie" {
                if let url = info[.mediaURL] as? URL {
                    parent.onVideoCapture?(url)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// 检查相机是否可用（模拟器无相机）
var isCameraAvailable: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
}
