import SwiftUI

/// 森林场景背景 - Finch风格沉浸式场景（稳定版本）
struct ForestSceneBackground: View {
    var body: some View {
        ZStack {
            // 天空渐变 (全屏)
            LinearGradient(
                colors: [
                    Color(red: 0.53, green: 0.81, blue: 0.92), // 天蓝
                    Color(red: 0.76, green: 0.88, blue: 0.72)  // 浅绿
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 使用GeometryReader仅用于获取尺寸
            GeometryReader { geo in
                ZStack {
                    // 太阳
                    SunView()
                        .position(x: geo.size.width * 0.85, y: 80)
                    
                    // 远处的山丘
                    DistantHillsShape()
                        .fill(Color(red: 0.35, green: 0.55, blue: 0.35))
                        .frame(height: geo.size.height)
                    
                    // 草地
                    VStack(spacing: 0) {
                        Spacer()
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.75, blue: 0.45),
                                Color(red: 0.45, green: 0.65, blue: 0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.55)
                    }
                    
                    // 中景树木 (固定位置)
                    MiddleTreesView(geo: geo)
                    
                    // 左右两侧大树
                    ForegroundTreesView(geo: geo)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sun View
struct SunView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 80, height: 80)
            Circle()
                .fill(Color.yellow)
                .frame(width: 50, height: 50)
        }
    }
}

// MARK: - Distant Hills Shape
struct DistantHillsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let baseY = rect.height * 0.35
        
        path.move(to: CGPoint(x: 0, y: baseY + 50))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.3, y: baseY),
            control: CGPoint(x: width * 0.15, y: baseY - 30)
        )
        path.addQuadCurve(
            to: CGPoint(x: width * 0.6, y: baseY + 20),
            control: CGPoint(x: width * 0.45, y: baseY - 20)
        )
        path.addQuadCurve(
            to: CGPoint(x: width, y: baseY + 40),
            control: CGPoint(x: width * 0.8, y: baseY - 10)
        )
        path.addLine(to: CGPoint(x: width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Middle Trees View (固定位置避免随机闪烁)
struct MiddleTreesView: View {
    let geo: GeometryProxy
    
    // 固定的树木配置
    private let treeConfigs: [(x: CGFloat, size: CGFloat, yOffset: CGFloat)] = [
        (0.05, 70, 0),
        (0.15, 80, 10),
        (0.25, 65, 5),
        (0.4, 85, 15),
        (0.55, 75, 8),
        (0.7, 80, 3),
        (0.85, 70, 12),
        (0.95, 75, 6)
    ]
    
    var body: some View {
        let baseY = geo.size.height * 0.38
        
        ZStack {
            ForEach(0..<treeConfigs.count, id: \.self) { i in
                TreeShape(size: treeConfigs[i].size)
                    .fill(Color(red: 0.25, green: 0.5, blue: 0.3))
                    .position(
                        x: geo.size.width * treeConfigs[i].x,
                        y: baseY - treeConfigs[i].yOffset
                    )
            }
        }
    }
}

// MARK: - Foreground Trees View
struct ForegroundTreesView: View {
    let geo: GeometryProxy
    
    var body: some View {
        ZStack {

        }
    }
}

// MARK: - Tree Shape
struct TreeShape: Shape {
    let size: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let centerY = rect.midY
        
        // 三层三角形树冠
        let layers: [(yOffset: CGFloat, widthFactor: CGFloat)] = [
            (0, 0.6),
            (size * 0.25, 0.8),
            (size * 0.5, 1.0)
        ]
        
        for layer in layers {
            let layerWidth = size * layer.widthFactor
            let layerHeight = size * 0.5
            let topY = centerY - size + layer.yOffset
            
            path.move(to: CGPoint(x: centerX, y: topY))
            path.addLine(to: CGPoint(x: centerX - layerWidth / 2, y: topY + layerHeight))
            path.addLine(to: CGPoint(x: centerX + layerWidth / 2, y: topY + layerHeight))
            path.closeSubpath()
        }
        
        return path
    }
}

// MARK: - Large Tree Shape
struct LargeTreeShape: Shape {
    let size: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let centerY = rect.midY
        
        // 四层三角形树冠
        let layers: [(yOffset: CGFloat, widthFactor: CGFloat)] = [
            (0, 0.5),
            (size * 0.2, 0.7),
            (size * 0.4, 0.9),
            (size * 0.6, 1.1)
        ]
        
        for layer in layers {
            let layerWidth = size * layer.widthFactor
            let layerHeight = size * 0.35
            let topY = centerY - size + layer.yOffset
            
            path.move(to: CGPoint(x: centerX, y: topY))
            path.addLine(to: CGPoint(x: centerX - layerWidth / 2, y: topY + layerHeight))
            path.addLine(to: CGPoint(x: centerX + layerWidth / 2, y: topY + layerHeight))
            path.closeSubpath()
        }
        
        return path
    }
}

// MARK: - Radial Glow Effect
struct RadialGlowEffect: View {
    let color: Color
    
    var body: some View {
        ZStack {
            // 放射状光线
            ForEach(0..<12, id: \.self) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8, height: 80)
                    .offset(y: -60)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            
            // 中心光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, color.opacity(0.5), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
        }
    }
}

#Preview {
    ForestSceneBackground()
}
