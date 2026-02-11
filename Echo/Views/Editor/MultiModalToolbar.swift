import SwiftUI

struct MultiModalToolbar: View {
    @Binding var showVoiceRecorder: Bool
    @Binding var showPhotosPicker: Bool
    @Binding var showCamera: Bool
    @Binding var showHandwriting: Bool
    @Binding var showAIAssist: Bool
    
    var body: some View {
        if #available(iOS 26, *) {
            // iOS 26+ Liquid Glass 风格
            GlassEffectContainer(spacing: 24) {
                HStack(spacing: 24) {
                    GlassToolbarButton(icon: "sparkles") {
                        showAIAssist.toggle()
                    }
                    GlassToolbarButton(icon: "photo.on.rectangle") {
                        showPhotosPicker.toggle()
                    }
                    GlassToolbarButton(icon: "camera") {
                        showCamera.toggle()
                    }
                    GlassToolbarButton(icon: "waveform") {
                        showVoiceRecorder.toggle()
                    }
                    GlassToolbarButton(icon: "location") {
                        // 添加位置
                    }
                    GlassToolbarButton(icon: "star.bubble") {
                        showHandwriting.toggle()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        } else {
            // iOS 25及以下 Fallback
            HStack(spacing: 24) {
                FallbackToolbarButton(icon: "sparkles") {
                    showAIAssist.toggle()
                }
                FallbackToolbarButton(icon: "photo.on.rectangle") {
                    showPhotosPicker.toggle()
                }
                FallbackToolbarButton(icon: "camera") {
                    showCamera.toggle()
                }
                FallbackToolbarButton(icon: "waveform") {
                    showVoiceRecorder.toggle()
                }
                FallbackToolbarButton(icon: "location") {
                    // 添加位置
                }
                FallbackToolbarButton(icon: "star.bubble") {
                    showHandwriting.toggle()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Liquid Glass 工具栏按钮 (iOS 26+)
struct GlassToolbarButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(JournalColors.inkBlack)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: .circle)
        }
    }
}

// MARK: - Fallback 工具栏按钮
struct FallbackToolbarButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(JournalColors.inkBlack)
                .frame(width: 44, height: 44)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        MultiModalToolbar(
            showVoiceRecorder: .constant(false),
            showPhotosPicker: .constant(false),
            showCamera: .constant(false),
            showHandwriting: .constant(false),
            showAIAssist: .constant(false)
        )
    }
    .background(PaperTexture())
}
