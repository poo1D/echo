import SwiftUI
import UIKit

struct PhotoGridView: View {
    let photoFileNames: [String]

    var body: some View {
        let count = photoFileNames.count
        if count == 1 {
            diaryPhotoImage(fileName: photoFileNames[0])
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if count == 2 {
            HStack(spacing: 4) {
                diaryPhotoImage(fileName: photoFileNames[0])
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                diaryPhotoImage(fileName: photoFileNames[1])
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        } else if count >= 3 {
            let gridPhotos = Array(photoFileNames.prefix(4))
            let rows = gridPhotos.count <= 2 ? 1 : 2

            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        let startIdx = row * 2
                        let endIdx = min(startIdx + 2, gridPhotos.count)
                        ForEach(startIdx..<endIdx, id: \.self) { idx in
                            ZStack {
                                diaryPhotoImage(fileName: gridPhotos[idx])
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                if idx == 3 && count > 4 {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.black.opacity(0.4))
                                        .frame(height: 120)
                                    Text("+\(count - 4)")
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

func diaryPhotoImage(fileName: String) -> some View {
    let url = PhotoPickerService.photoURL(for: fileName)
    return Group {
        if let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
        }
    }
}
