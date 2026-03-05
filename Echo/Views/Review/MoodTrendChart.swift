import SwiftUI

/// 心情趋势折线图 — 手帐风格
struct MoodTrendChart: View {
    let dataPoints: [MoodDataPoint]
    
    // 图表尺寸
    private let chartHeight: CGFloat = 140
    private let dotSize: CGFloat = 28
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(JournalColors.lavender)
                Text("心情趋势")
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
                Spacer()
                Text("最近 7 天")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            
            if dataPoints.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
        .padding()
        .scrapbookStyle()
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Text("📊")
                    .font(.largeTitle)
                Text("记录更多日记来查看趋势")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
    
    // MARK: - Chart View
    private var chartView: some View {
        VStack(spacing: 8) {
            // 图表区域
            GeometryReader { geo in
                let width = geo.size.width
                let points = calculatePoints(in: CGSize(width: width, height: chartHeight))
                
                ZStack {
                    // 背景网格线
                    gridLines
                    
                    // 渐变填充
                    if points.count > 1 {
                        gradientFill(points: points, in: CGSize(width: width, height: chartHeight))
                    }
                    
                    // 连接线
                    if points.count > 1 {
                        curveLine(points: points)
                    }
                    
                    // 数据点 + emoji
                    ForEach(Array(zip(dataPoints.indices, points)), id: \.0) { index, point in
                        emojiDot(for: dataPoints[index], at: point)
                    }
                }
            }
            .frame(height: chartHeight)
            
            // X 轴标签
            HStack {
                ForEach(dataPoints) { point in
                    Text(point.dayLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(
                            Calendar.current.isDateInToday(point.date)
                                ? JournalColors.lavender
                                : JournalColors.warmGray
                        )
                        .fontWeight(Calendar.current.isDateInToday(point.date) ? .bold : .regular)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Grid Lines
    private var gridLines: some View {
        VStack {
            ForEach(0..<3) { _ in
                Divider()
                    .overlay(JournalColors.warmGray.opacity(0.15))
                Spacer()
            }
            Divider()
                .overlay(JournalColors.warmGray.opacity(0.15))
        }
    }
    
    // MARK: - Gradient Fill
    private func gradientFill(points: [CGPoint], in size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: points[0].x, y: size.height))
            path.addLine(to: points[0])
            
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midX = (prev.x + curr.x) / 2
                path.addCurve(
                    to: curr,
                    control1: CGPoint(x: midX, y: prev.y),
                    control2: CGPoint(x: midX, y: curr.y)
                )
            }
            
            path.addLine(to: CGPoint(x: points.last!.x, y: size.height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    JournalColors.lavender.opacity(0.25),
                    JournalColors.lavender.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Curve Line
    private func curveLine(points: [CGPoint]) -> some View {
        Path { path in
            path.move(to: points[0])
            
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midX = (prev.x + curr.x) / 2
                path.addCurve(
                    to: curr,
                    control1: CGPoint(x: midX, y: prev.y),
                    control2: CGPoint(x: midX, y: curr.y)
                )
            }
        }
        .stroke(
            JournalColors.lavender,
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
    }
    
    // MARK: - Emoji Dot
    private func emojiDot(for point: MoodDataPoint, at position: CGPoint) -> some View {
        Text(point.emoji)
            .font(.system(size: 16))
            .frame(width: dotSize, height: dotSize)
            .background(
                Circle()
                    .fill(JournalColors.warmWhite)
                    .shadow(color: JournalColors.lavender.opacity(0.3), radius: 4, y: 2)
            )
            .position(position)
    }
    
    // MARK: - Calculate Points
    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard !dataPoints.isEmpty else { return [] }
        
        let padding: CGFloat = dotSize / 2 + 4
        let drawableWidth = size.width - padding * 2
        let drawableHeight = size.height - padding * 2
        
        let count = dataPoints.count
        let step = count > 1 ? drawableWidth / CGFloat(count - 1) : 0
        
        return dataPoints.enumerated().map { index, point in
            let x = padding + CGFloat(index) * step
            // 分数 1-5 映射到 y 轴（高分在上）
            let normalizedY = CGFloat(point.score - 1) / 4.0
            let y = padding + drawableHeight * (1 - normalizedY)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - 数据模型

struct MoodDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let emoji: String
    let score: Int // 1-5
    
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        let label = formatter.string(from: date)
        // 取最后一个字：周一→一
        return String(label.suffix(1))
    }
    
    /// 从 MoodPicker.Mood emoji 映射到分数
    static func scoreFromEmoji(_ emoji: String?) -> Int {
        switch emoji {
        case "🤩": return 5
        case "😊": return 4
        case "😌": return 3
        case "😴": return 2
        case "😢": return 1
        case "😤": return 1
        default: return 3
        }
    }
}

#Preview {
    VStack {
        MoodTrendChart(dataPoints: [
            MoodDataPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, emoji: "😌", score: 3),
            MoodDataPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, emoji: "😊", score: 4),
            MoodDataPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, emoji: "🤩", score: 5),
            MoodDataPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, emoji: "😊", score: 4),
            MoodDataPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, emoji: "😢", score: 1),
            MoodDataPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, emoji: "😌", score: 3),
            MoodDataPoint(date: Date(), emoji: "😊", score: 4),
        ])
        
        MoodTrendChart(dataPoints: [])
    }
    .padding()
    .background(PaperTexture())
}
