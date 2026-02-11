import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("explore.")
                        .font(JournalFonts.largeTitle)
                        .foregroundStyle(JournalColors.inkBlack)
                    
                    // 个性洞察
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Insights")
                            .font(JournalFonts.headline)
                            .foregroundStyle(JournalColors.inkBlack)
                        
                        InsightStatCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Mood Trends",
                            value: "Improving",
                            color: JournalColors.mintGreen
                        )
                        
                        InsightStatCard(
                            icon: "clock",
                            title: "Best Writing Time",
                            value: "Evening",
                            color: JournalColors.lavender
                        )
                        
                        InsightStatCard(
                            icon: "flame",
                            title: "Current Streak",
                            value: "7 days",
                            color: JournalColors.peach
                        )
                    }
                    
                    // 发现模板
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Templates")
                                .font(JournalFonts.headline)
                                .foregroundStyle(JournalColors.inkBlack)
                            Spacer()
                            Button("See All") {}
                                .font(JournalFonts.caption)
                                .foregroundStyle(JournalColors.warmGray)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                TemplateCard(title: "Morning Pages", icon: "sunrise")
                                TemplateCard(title: "Evening Reflection", icon: "moon")
                                TemplateCard(title: "Gratitude", icon: "heart")
                                TemplateCard(title: "Goal Setting", icon: "target")
                            }
                        }
                    }
                }
                .padding()
            }
            .background(PaperTexture())
        }
    }
}

// MARK: - Insight Stat Card
struct InsightStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(JournalColors.inkBlack)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
                Text(value)
                    .font(JournalFonts.headline)
                    .foregroundStyle(JournalColors.inkBlack)
            }
            
            Spacer()
        }
        .padding()
        .scrapbookStyle()
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(JournalColors.softPink.opacity(0.3))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(JournalColors.inkBlack)
            }
            
            Text(title)
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.inkBlack)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100)
        .padding()
        .scrapbookStyle()
    }
}

#Preview {
    ExploreView()
}
