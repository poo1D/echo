import SwiftUI
import SwiftData

/// 共同手帐 - 仪式感翻阅
struct ScrapbookView: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex = 0
    @State private var showPageFlip = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 复古背景
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.92, blue: 0.88),
                        Color(red: 0.90, green: 0.85, blue: 0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if entries.isEmpty {
                    emptyState
                } else {
                    // 翻页容器
                    TabView(selection: $currentIndex) {
                        ForEach(entries.indices, id: \.self) { index in
                            ScrapbookPageView(entry: entries[index], pageNumber: index + 1, totalPages: entries.count)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.5), value: currentIndex)
                }
                
                // 底部页码指示器
                if !entries.isEmpty {
                    VStack {
                        Spacer()
                        pageIndicator
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("共同手帐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(JournalColors.inkBlack)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(JournalColors.warmGray)
            
            Text("还没有手帐记录")
                .font(JournalFonts.headline)
                .foregroundStyle(JournalColors.warmGray)
            
            Text("写下第一篇日记，开始和Echo的共同回忆吧")
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: 20) {
            // 上一页
            Button {
                withAnimation(.spring(response: 0.5)) {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
                    .foregroundStyle(currentIndex > 0 ? JournalColors.lavender : JournalColors.warmGray.opacity(0.3))
            }
            .disabled(currentIndex == 0)
            
            // 页码
            Text("\(currentIndex + 1) / \(entries.count)")
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.inkBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(JournalColors.warmWhite.opacity(0.9), in: Capsule())
            
            // 下一页
            Button {
                withAnimation(.spring(response: 0.5)) {
                    if currentIndex < entries.count - 1 {
                        currentIndex += 1
                    }
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title)
                    .foregroundStyle(currentIndex < entries.count - 1 ? JournalColors.lavender : JournalColors.warmGray.opacity(0.3))
            }
            .disabled(currentIndex >= entries.count - 1)
        }
    }
}

#Preview {
    ScrapbookView()
        .modelContainer(for: JournalEntry.self)
}
