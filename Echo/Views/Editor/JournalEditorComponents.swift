import SwiftUI
import PhotosUI

/// 心情选择器组件
struct MoodPicker: View {
    @Binding var selectedMood: Mood
    @Binding var intensity: Double
    
    enum Mood: String, CaseIterable {
        case happy = "😊"
        case excited = "🤩"
        case calm = "😌"
        case tired = "😴"
        case sad = "😢"
        case angry = "😤"
        
        var label: String {
            switch self {
            case .happy: return "开心"
            case .excited: return "兴奋"
            case .calm: return "平静"
            case .tired: return "疲惫"
            case .sad: return "难过"
            case .angry: return "烦躁"
            }
        }
        
        var color: Color {
            switch self {
            case .happy: return JournalColors.mintGreen
            case .excited: return Color.yellow
            case .calm: return JournalColors.skyBlue
            case .tired: return JournalColors.warmGray
            case .sad: return JournalColors.softPink
            case .angry: return Color.red.opacity(0.6)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 表情选择
            HStack(spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    moodButton(mood)
                }
            }
            
            // 强度滑块
            VStack(spacing: 8) {
                HStack {
                    Text("强度")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    Spacer()
                    Text("\(Int(intensity * 100))%")
                        .font(JournalFonts.caption)
                        .foregroundStyle(selectedMood.color)
                }
                
                Slider(value: $intensity, in: 0...1)
                    .tint(selectedMood.color)
            }
        }
        .padding()
        .background(JournalColors.warmWhite.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func moodButton(_ mood: Mood) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedMood = mood
            }
        } label: {
            VStack(spacing: 4) {
                Text(mood.rawValue)
                    .font(.system(size: selectedMood == mood ? 32 : 24))
                if selectedMood == mood {
                    Text(mood.label)
                        .font(.system(size: 10))
                        .foregroundStyle(mood.color)
                }
            }
            .frame(width: 50, height: 50)
            .background(selectedMood == mood ? mood.color.opacity(0.2) : Color.clear, in: Circle())
            .scaleEffect(selectedMood == mood ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

/// 日记照片网格组件
struct JournalPhotoGrid: View {
    @Binding var selectedPhotos: [UIImage]
    @State private var photosPickerItems: [PhotosPickerItem] = []
    
    let maxPhotos = 9
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("照片 (\(selectedPhotos.count)/\(maxPhotos))")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                // 已选照片
                ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { index, image in
                    photoThumbnail(image, index: index)
                }
                
                // 添加按钮
                if selectedPhotos.count < maxPhotos {
                    addPhotoButton
                }
            }
        }
        .onChange(of: photosPickerItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedPhotos.append(image)
                    }
                }
                photosPickerItems.removeAll()
            }
        }
    }
    
    private func photoThumbnail(_ image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 删除按钮
            Button {
                withAnimation {
                    _ = selectedPhotos.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .offset(x: 6, y: -6)
        }
    }
    
    private var addPhotoButton: some View {
        PhotosPicker(selection: $photosPickerItems, maxSelectionCount: maxPhotos - selectedPhotos.count, matching: .images) {
            VStack {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(JournalColors.lavender)
            }
            .frame(width: 100, height: 100)
            .background(JournalColors.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(JournalColors.lavender.opacity(0.5))
            )
        }
    }
}

/// 保存Loading动画（小企鹅认真阅读）
struct SavingOverlay: View {
    @State private var eyeScale: CGFloat = 1.0
    @State private var dotOffset: CGFloat = 0
    @State private var isBlinking = false
    @State private var headTilt: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 小企鹅认真阅读的表情
                ZStack {
                    // 身体
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8B9DC3"), Color(hex: "6B7AA1")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 80, height: 100)
                    
                    // 肚子
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(hex: "F5F5F5")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 55, height: 70)
                        .offset(y: 8)
                    
                    // 腮红
                    HStack(spacing: 40) {
                        Circle()
                            .fill(Color(hex: "FFB5BA").opacity(0.6))
                            .frame(width: 14, height: 14)
                        Circle()
                            .fill(Color(hex: "FFB5BA").opacity(0.6))
                            .frame(width: 14, height: 14)
                    }
                    .offset(y: -5)
                    
                    // 眼睛（放大表示认真看）
                    HStack(spacing: 24) {
                        eyeView
                        eyeView
                    }
                    .offset(y: -20)
                    .scaleEffect(eyeScale)
                    
                    // 嘴巴
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "FFB347"))
                        .rotationEffect(.degrees(180))
                        .offset(y: -4)
                    
                    // 翅膀
                    HStack(spacing: 60) {
                        Capsule()
                            .fill(Color(hex: "7B8BC0"))
                            .frame(width: 16, height: 40)
                            .rotationEffect(.degrees(15))
                        
                        Capsule()
                            .fill(Color(hex: "7B8BC0"))
                            .frame(width: 16, height: 40)
                            .rotationEffect(.degrees(-15))
                    }
                    .offset(y: 8)
                }
                .rotationEffect(.degrees(headTilt))
                
                // 加载文字
                HStack(spacing: 4) {
                    Text("正在认真阅读")
                        .font(JournalFonts.body)
                        .foregroundStyle(.white)
                    
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                            .offset(y: i == Int(dotOffset) ? -5 : 0)
                    }
                }
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .onAppear {
            // 眼睛放大动画
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                eyeScale = 1.1
            }
            // 点点动画
            withAnimation(.linear(duration: 0.6).repeatForever()) {
                dotOffset = 3
            }
            // 轻微歪头
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                headTilt = 3
            }
            // 眨眼
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.1)) { isBlinking = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.1)) { isBlinking = false }
                }
            }
        }
    }
    
    private var eyeView: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 16, height: isBlinking ? 2 : 16)
            
            if !isBlinking {
                Circle()
                    .fill(.white)
                    .frame(width: 5)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

#Preview("Mood Picker") {
    @Previewable @State var mood = MoodPicker.Mood.happy
    @Previewable @State var intensity = 0.7
    
    MoodPicker(selectedMood: $mood, intensity: $intensity)
        .padding()
}

#Preview("Photo Grid") {
    @Previewable @State var photos: [UIImage] = []
    
    JournalPhotoGrid(selectedPhotos: $photos)
        .padding()
}

#Preview("Saving Overlay") {
    SavingOverlay()
}
