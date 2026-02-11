import SwiftUI
import PhotosUI

/// 照片选择器视图
struct PhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isLoading = false
    @Binding var attachments: [SelectedPhoto]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 已选照片预览
                if selectedImages.isEmpty {
                    emptyState
                } else {
                    selectedPhotosGrid
                }
                
                // 选择更多照片
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("选择照片", systemImage: "photo.on.rectangle.angled")
                        .font(JournalFonts.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(JournalColors.inkBlack, in: Capsule())
                }
                .onChange(of: selectedItems) { _, newItems in
                    loadImages(from: newItems)
                }
                
                Spacer()
            }
            .padding()
            .background(PaperTexture())
            .navigationTitle("添加照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        completeSelection()
                    }
                    .disabled(selectedImages.isEmpty)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(JournalColors.warmGray)
            Text("点击下方按钮选择照片")
                .font(JournalFonts.body)
                .foregroundStyle(JournalColors.warmGray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .scrapbookStyle()
    }
    
    // MARK: - Selected Photos Grid
    private var selectedPhotosGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(.rect(cornerRadius: 12))
                        
                        // 删除按钮
                        Button {
                            removeImage(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, .red)
                                .font(.title3)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding()
        }
        .frame(maxHeight: 400)
        .scrapbookStyle()
    }
    
    // MARK: - Actions
    private func loadImages(from items: [PhotosPickerItem]) {
        isLoading = true
        selectedImages = []
        
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImages.append(image)
                    }
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func removeImage(at index: Int) {
        selectedImages.remove(at: index)
        selectedItems.remove(at: index)
    }
    
    private func completeSelection() {
        attachments = selectedImages.map { SelectedPhoto(image: $0) }
        dismiss()
    }
}

// MARK: - Selected Photo Model
struct SelectedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    var position: CGPoint = .zero
    var rotation: Double = Double.random(in: -5...5)
    var scale: CGFloat = 1.0
}

#Preview {
    PhotoPickerView(attachments: .constant([]))
}
