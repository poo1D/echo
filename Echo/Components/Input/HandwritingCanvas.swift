import SwiftUI
import PencilKit

/// 手写画布 - 使用 PencilKit
struct HandwritingCanvas: UIViewRepresentable {
    @Binding var canvasData: Data?
    @Binding var isToolPickerVisible: Bool
    
    var backgroundColor: UIColor = .clear
    var inkColor: UIColor = UIColor(JournalColors.inkBlack)
    var inkWidth: CGFloat = 2
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = backgroundColor
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput  // 支持手指绘制
        
        // 设置默认工具
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: inkWidth)
        
        // 加载已有数据
        if let data = canvasData,
           let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        
        // 工具选择器
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        context.coordinator.toolPicker = toolPicker
        
        return canvas
    }
    
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.toolPicker?.setVisible(isToolPickerVisible, forFirstResponder: canvas)
        if isToolPickerVisible {
            canvas.becomeFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: HandwritingCanvas
        var toolPicker: PKToolPicker?
        
        init(_ parent: HandwritingCanvas) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.canvasData = canvasView.drawing.dataRepresentation()
        }
    }
}

/// 手写输入视图
struct HandwritingInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canvasData: Data?
    @State private var isToolPickerVisible = true
    @Binding var outputData: Data?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 纸张背景
                PaperTexture(style: .cream)
                
                // 手写画布
                HandwritingCanvas(
                    canvasData: $canvasData,
                    isToolPickerVisible: $isToolPickerVisible
                )
            }
            .navigationTitle("手写")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // 清除按钮
                        Button {
                            canvasData = nil
                        } label: {
                            Image(systemName: "trash")
                        }
                        
                        // 完成按钮
                        Button("完成") {
                            outputData = canvasData
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

/// 手写叠加层 - 显示保存的手写内容
struct HandwritingOverlay: View {
    let data: Data
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let drawing = try? PKDrawing(data: data) else { return }
        let bounds = drawing.bounds
        image = drawing.image(from: bounds, scale: UIScreen.main.scale)
    }
}

#Preview {
    HandwritingInputView(outputData: .constant(nil))
}
