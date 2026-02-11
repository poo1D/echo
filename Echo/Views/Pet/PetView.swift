import SwiftUI

/// 可爱小企鹅宠物视图 - 带动态表情动画
struct PetView: View {
    @State private var isBlinking = false
    @State private var breathScale: CGFloat = 1.0
    @State private var bounceOffset: CGFloat = 0
    
    // 动画状态
    @State private var wingRotation: Double = 0
    @State private var headTilt: Double = 0
    @State private var jumpOffset: CGFloat = 0
    
    // 监听宠物状态
    private var petState: PetStateManager { PetStateManager.shared }
    
    var body: some View {
        ZStack {
            // 阴影
            Ellipse()
                .fill(Color.black.opacity(0.1))
                .frame(width: 80, height: 20)
                .offset(y: 70 + jumpOffset/2)
                .blur(radius: 5)
            
            // 企鹅身体
            VStack(spacing: 0) {
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
                        .frame(width: 100, height: 130)
                    
                    // 肚子
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(hex: "F5F5F5")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 70, height: 90)
                        .offset(y: 10)
                    
                    // 腮红（害羞时更红）
                    HStack(spacing: 50) {
                        Circle()
                            .fill(Color(hex: "FFB5BA").opacity(petState.currentAnimation == .shyLookDown ? 0.9 : 0.6))
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(Color(hex: "FFB5BA").opacity(petState.currentAnimation == .shyLookDown ? 0.9 : 0.6))
                            .frame(width: 18, height: 18)
                    }
                    .offset(y: -5)
                    
                    // 眼睛
                    HStack(spacing: 30) {
                        eyeView
                        eyeView
                    }
                    .offset(y: -25 + headTilt * 2)
                    
                    // 嘴巴
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "FFB347"))
                        .rotationEffect(.degrees(180))
                        .offset(y: -5 + headTilt * 2)
                    
                    // 翅膀（会摇动）
                    HStack(spacing: 75) {
                        Capsule()
                            .fill(Color(hex: "7B8BC0"))
                            .frame(width: 20, height: 50)
                            .rotationEffect(.degrees(15 + wingRotation))
                        
                        Capsule()
                            .fill(Color(hex: "7B8BC0"))
                            .frame(width: 20, height: 50)
                            .rotationEffect(.degrees(-15 - wingRotation))
                    }
                    .offset(y: 10)
                }
                .rotationEffect(.degrees(headTilt))
                
                // 脚
                HStack(spacing: 20) {
                    Ellipse()
                        .fill(Color(hex: "FFB347"))
                        .frame(width: 25, height: 12)
                    Ellipse()
                        .fill(Color(hex: "FFB347"))
                        .frame(width: 25, height: 12)
                }
                .offset(y: -5)
            }
        }
        .scaleEffect(breathScale)
        .offset(y: bounceOffset + jumpOffset)
        .onAppear {
            startIdleAnimations()
        }
        .onChange(of: petState.currentAnimation) { _, newAnimation in
            playAnimation(newAnimation)
        }
    }
    
    // MARK: - Eye View
    private var eyeView: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: 20, height: isBlinking ? 3 : 20)
            
            if !isBlinking {
                Circle()
                    .fill(.white)
                    .frame(width: 7)
                    .offset(x: 3, y: -3)
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 3)
                    .offset(x: -2, y: 2)
            }
        }
    }
    
    // MARK: - Idle Animations
    private func startIdleAnimations() {
        // 眨眼
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) { isBlinking = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.1)) { isBlinking = false }
            }
        }
        
        // 呼吸
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            breathScale = 1.05
        }
        
        // 轻微弹跳
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            bounceOffset = -5
        }
    }
    
    // MARK: - Play Animation
    private func playAnimation(_ animation: PetStateManager.PetAnimation) {
        switch animation {
        case .wingFlap:
            // 摇翅膀
            withAnimation(.easeInOut(duration: 0.15).repeatCount(6, autoreverses: true)) {
                wingRotation = 25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { wingRotation = 0 }
            }
            
        case .shyLookDown:
            // 害羞低头
            withAnimation(.easeInOut(duration: 0.3)) {
                headTilt = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.3)) { headTilt = 0 }
            }
            
        case .jump:
            // 开心跳跃
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                jumpOffset = -30
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    jumpOffset = 0
                }
            }
            // 同时摇翅膀
            withAnimation(.easeInOut(duration: 0.1).repeatCount(8, autoreverses: true)) {
                wingRotation = 20
            }
            
        case .nod:
            // 点头
            withAnimation(.easeInOut(duration: 0.2)) { headTilt = 5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeInOut(duration: 0.2)) { headTilt = -3 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) { headTilt = 0 }
            }
            
        case .idle:
            break
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "E8F4F8").ignoresSafeArea()
        PetView()
    }
}
