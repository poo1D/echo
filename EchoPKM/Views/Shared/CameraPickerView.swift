import SwiftUI
import AVFoundation

// MARK: - Camera Preview (AVCaptureVideoPreviewLayer)

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Camera Manager

@Observable @MainActor
final class CameraManager: NSObject {

    enum CaptureMode { case photo, video }
    enum FlashMode    { case off, on, auto }

    // UI 状态（主线程）
    var captureMode: CaptureMode = .photo
    var flashMode: FlashMode = .off
    var isRecording = false
    var isFrontCamera = false

    // 捕获结果（view 通过 onChange 响应并触发 dismiss）
    var capturedPhoto: UIImage?
    var capturedVideoURL: URL?

    // AVFoundation 对象（通过 sessionQueue 访问，nonisolated(unsafe) 绕过 Swift 6 隔离检查）
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private let movieOutput = AVCaptureMovieFileOutput()
    nonisolated let sessionQueue = DispatchQueue(label: "com.echopkm.camera.session")

    // MARK: 初始化 Session

    func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // 视频输入
            if let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: cam),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoDeviceInput = input
            }

            // 麦克风输入（录像需要）
            if let mic = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(micInput) {
                self.session.addInput(micInput)
            }

            // 照片输出
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
            }

            // 视频输出
            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: 拍照

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        switch flashMode {
        case .on:   settings.flashMode = .on
        case .off:  settings.flashMode = .off
        case .auto: settings.flashMode = .auto
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: 录像

    func toggleRecording() {
        if isRecording {
            movieOutput.stopRecording()
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mov")
            movieOutput.startRecording(to: url, recordingDelegate: self)
            isRecording = true
        }
    }

    // MARK: 翻转镜头

    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newPos: AVCaptureDevice.Position = self.isFrontCamera ? .back : .front
            guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPos),
                  let newInput = try? AVCaptureDeviceInput(device: cam) else { return }

            self.session.beginConfiguration()
            if let old = self.videoDeviceInput { self.session.removeInput(old) }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDeviceInput = newInput
            }
            // 前置镜像
            if newPos == .front, let conn = self.movieOutput.connection(with: .video),
               conn.isVideoMirroringSupported {
                conn.isVideoMirrored = true
            }
            self.session.commitConfiguration()

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isFrontCamera = !self.isFrontCamera
            }
        }
    }

    // MARK: 闪光灯循环

    func cycleFlash() {
        switch flashMode {
        case .off:  flashMode = .on
        case .on:   flashMode = .auto
        case .auto: flashMode = .off
        }
    }
}

// MARK: - 照片 Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor [weak self] in
            self?.capturedPhoto = image
        }
    }
}

// MARK: - 录像 Delegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        guard error == nil else { return }
        Task { @MainActor [weak self] in
            self?.isRecording = false
            self?.capturedVideoURL = outputFileURL
        }
    }
}

// MARK: - 自定义相机视图

struct CustomCameraView: View {
    var onPhotoCapture: ((UIImage) -> Void)?
    var onVideoCapture: ((URL) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var cameraManager = CameraManager()
    @State private var shutterScale: CGFloat = 1.0

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 相机预览
            CameraPreviewLayer(session: cameraManager.session)
                .ignoresSafeArea()

            // 覆盖层
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomControls
            }
        }
        .statusBarHidden(true)
        .onAppear { cameraManager.configure() }
        .onDisappear { cameraManager.stopSession() }
        // 拍照完成 → 回调 → dismiss
        .onChange(of: cameraManager.capturedPhoto) { _, photo in
            guard let photo else { return }
            onPhotoCapture?(photo)
            dismiss()
        }
        // 录像完成 → 回调 → dismiss
        .onChange(of: cameraManager.capturedVideoURL) { _, url in
            guard let url else { return }
            onVideoCapture?(url)
            dismiss()
        }
    }

    // MARK: 顶部栏（日期 + 关闭）

    private var topBar: some View {
        HStack(alignment: .center) {
            Text(dateString)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                if cameraManager.isRecording { cameraManager.toggleRecording() }
                cameraManager.stopSession()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.18), in: Circle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 56)   // safe area 补偿
    }

    // MARK: 底部控制区

    private var bottomControls: some View {
        VStack(spacing: 28) {
            // 模式切换胶囊
            modeToggle

            // 快门行
            HStack {
                // 闪光灯
                Button { cameraManager.cycleFlash() } label: {
                    Image(systemName: flashIcon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(cameraManager.flashMode == .off ? .white.opacity(0.55) : .yellow)
                        .frame(width: 52, height: 52)
                }

                Spacer()

                // 快门按钮
                shutterButton

                Spacer()

                // 翻转镜头
                Button { cameraManager.flipCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 52, height: 52)
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.bottom, 52)
    }

    // MARK: 模式切换胶囊

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeLabel("照片", active: cameraManager.captureMode == .photo) {
                withAnimation(.easeInOut(duration: 0.2)) { cameraManager.captureMode = .photo }
            }
            modeLabel("视频", active: cameraManager.captureMode == .video) {
                withAnimation(.easeInOut(duration: 0.2)) { cameraManager.captureMode = .video }
            }
        }
        .background(Capsule().fill(.white.opacity(0.12)))
    }

    private func modeLabel(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? .black : .white.opacity(0.7))
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .background(active ? .white : .clear, in: Capsule())
        }
        .padding(3)
    }

    // MARK: 快门按钮

    private var shutterButton: some View {
        Button {
            withAnimation(.easeIn(duration: 0.08)) { shutterScale = 0.88 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { shutterScale = 1.0 }
            }
            switch cameraManager.captureMode {
            case .photo: cameraManager.capturePhoto()
            case .video: cameraManager.toggleRecording()
            }
        } label: {
            ZStack {
                // 外圆环
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 76, height: 76)

                // 内部填充（照片：白圆；录像中：圆角方块）
                if cameraManager.captureMode == .video {
                    RoundedRectangle(cornerRadius: cameraManager.isRecording ? 8 : 34)
                        .fill(cameraManager.isRecording ? .white : .red)
                        .frame(
                            width:  cameraManager.isRecording ? 30 : 60,
                            height: cameraManager.isRecording ? 30 : 60
                        )
                        .animation(.easeInOut(duration: 0.22), value: cameraManager.isRecording)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 62, height: 62)
                }
            }
        }
        .scaleEffect(shutterScale)
    }

    // MARK: 闪光灯图标

    private var flashIcon: String {
        switch cameraManager.flashMode {
        case .off:  return "bolt.slash.fill"
        case .on:   return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        }
    }
}

// MARK: - 检查相机可用性

var isCameraAvailable: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
}
