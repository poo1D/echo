import SwiftUI
import PhotosUI

struct PendingPhoto: Identifiable {
    let id = UUID()
    let fileName: String
    let thumbnail: UIImage
}

@Observable @MainActor
final class PhotoPickerService {
    var selectedItems: [PhotosPickerItem] = []
    var pendingImages: [PendingPhoto] = []

    func processSelectedItems() async {
        for item in selectedItems {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }

            let fileName = "photo_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).jpg"
            let url = Self.photoURL(for: fileName)

            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                try? jpegData.write(to: url)
            }

            let thumbnailSize = CGSize(width: 120, height: 120)
            let thumbnail = image.preparingThumbnail(of: thumbnailSize) ?? image

            pendingImages.append(PendingPhoto(fileName: fileName, thumbnail: thumbnail))
        }
        selectedItems.removeAll()
    }

    func removePending(id: UUID) {
        pendingImages.removeAll { $0.id == id }
    }

    func consumePendingFileNames() -> [String] {
        let names = pendingImages.map(\.fileName)
        pendingImages.removeAll()
        return names
    }

    static func photoURL(for fileName: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }
}
