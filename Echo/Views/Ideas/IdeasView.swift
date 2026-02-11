import SwiftUI

struct IdeasView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("ideas.")
                        .font(JournalFonts.largeTitle)
                        .foregroundStyle(JournalColors.inkBlack)
                    
                    // 写作提示
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Writing Prompts")
                            .font(JournalFonts.headline)
                            .foregroundStyle(JournalColors.inkBlack)
                        
                        IdeaCard(
                            emoji: "💭",
                            title: "What made you smile today?",
                            category: "Gratitude"
                        )
                        
                        IdeaCard(
                            emoji: "🎯",
                            title: "What's one goal you're working towards?",
                            category: "Goals"
                        )
                        
                        IdeaCard(
                            emoji: "🌱",
                            title: "What did you learn recently?",
                            category: "Growth"
                        )
                    }
                    
                    // AI生成的提示
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(JournalColors.lavender)
                            Text("AI Suggested")
                                .font(JournalFonts.headline)
                                .foregroundStyle(JournalColors.inkBlack)
                        }
                        
                        IdeaCard(
                            emoji: "✨",
                            title: "Based on your recent entries, try reflecting on your progress this week.",
                            category: "Personalized"
                        )
                    }
                }
                .padding()
            }
            .background(PaperTexture())
        }
    }
}

// MARK: - Idea Card
struct IdeaCard: View {
    let emoji: String
    let title: String
    let category: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.largeTitle)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(JournalFonts.body)
                    .foregroundStyle(JournalColors.inkBlack)
                Text(category)
                    .font(JournalFonts.caption)
                    .foregroundStyle(JournalColors.warmGray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(JournalColors.warmGray)
        }
        .padding()
        .scrapbookStyle()
    }
}

#Preview {
    IdeasView()
}
