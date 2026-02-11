import SwiftUI

struct AIInsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(JournalColors.lavender)
                Text("AI 洞察")
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                Spacer()
                Text(insight.generatedAt, style: .relative)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            
            // 洞察内容
            Text(insight.summary)
                .font(JournalFonts.body)
                .foregroundStyle(JournalColors.inkBlack)
                .lineLimit(3)
            
            // 情绪标签
            if !insight.moodTags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(insight.moodTags, id: \.self) { tag in
                        Text(tag)
                            .font(JournalFonts.caption)
                            .foregroundStyle(JournalColors.inkBlack)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(JournalColors.softPink.opacity(0.5), in: Capsule())
                    }
                }
            }
            
            // 模式识别
            if let pattern = insight.patternDetected {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                    Text(pattern)
                        .font(JournalFonts.caption)
                }
                .foregroundStyle(JournalColors.mintGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(JournalColors.mintGreen.opacity(0.2), in: Capsule())
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(JournalColors.warmWhite)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
        // 轻微旋转模拟手帐贴纸效果
        .rotationEffect(.degrees(-1.5))
    }
}

#Preview {
    let sampleInsight = AIInsight(
        summary: "今天你的情绪非常稳定，在工作和学习中都保持了良好的专注力。",
        moodAnalysis: "积极向上"
    )
    
    return AIInsightCard(insight: sampleInsight)
        .padding()
        .background(PaperTexture())
}
