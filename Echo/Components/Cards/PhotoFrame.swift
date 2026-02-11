import SwiftUI

/// 照片框组件 - 带手帐装饰效果
struct PhotoFrame: View {
    let image: UIImage
    var rotation: Double = 0
    var showTape: Bool = true
    var tapeColor: Color = JournalColors.softPink
    
    var body: some View {
        ZStack {
            // 照片主体
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(.rect(cornerRadius: 4))
            
            // 白色边框（拍立得效果）
                .padding(8)
                .background(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            
            // 纸胶带装饰
            if showTape {
                WashiTape(color: tapeColor, rotation: Double.random(in: -10...10))
                    .offset(y: -100)
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

/// 可拖拽的照片框
struct DraggablePhotoFrame: View {
    @Binding var photo: SelectedPhoto
    let onDelete: () -> Void
    
    @State private var isDragging = false
    @GestureState private var dragOffset = CGSize.zero
    
    var body: some View {
        PhotoFrame(
            image: photo.image,
            rotation: photo.rotation,
            tapeColor: JournalColors.tapeColors.randomElement() ?? JournalColors.softPink
        )
        .scaleEffect(photo.scale)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .offset(dragOffset)
        .position(photo.position)
        .gesture(dragGesture)
        .gesture(doubleTapGesture)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                photo.rotation += 15
            } label: {
                Label("旋转", systemImage: "rotate.right")
            }
        }
        .animation(.spring(response: 0.3), value: isDragging)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                isDragging = true
            }
            .onEnded { value in
                isDragging = false
                photo.position.x += value.translation.width
                photo.position.y += value.translation.height
            }
    }
    
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring) {
                    photo.scale = photo.scale == 1.0 ? 1.5 : 1.0
                }
            }
    }
}

#Preview {
    ZStack {
        PaperTexture()
        
        if let image = UIImage(systemName: "photo") {
            PhotoFrame(image: image)
        }
    }
}
