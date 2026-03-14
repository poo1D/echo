import SwiftUI
import SwiftData

struct WeeklyLettersView: View {
    @Query(sort: \WeeklyReview.weekStartDate, order: .reverse) private var allReviews: [WeeklyReview]
    @State private var expandedReviewId: UUID?
    @State private var petState = PetState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Subtitle
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.claudeAccent)
                    Text("每周日 19:00，来自 Echo 的一封信")
                        .font(.yuantiSubheadline)
                        .foregroundStyle(Color.claudeWarmGray)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

                if allReviews.isEmpty {
                    emptyState
                } else {
                    ForEach(allReviews) { review in
                        if expandedReviewId == review.id {
                            expandedLetterCard(review)
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        } else {
                            collapsedCard(review)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .padding()
        }
        .background { WarmGradientBackground() }
        .navigationTitle("每周来信")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            PetView(petState: petState)
                .scaleEffect(0.5)
                .frame(width: 60, height: 70)
                .allowsHitTesting(false)
            VStack(spacing: 6) {
                Text("还没有来信")
                    .font(.yuantiSubheadline)
                    .foregroundStyle(.secondary)
                Text("多记录日记，Echo 就会给你写信啦")
                    .font(.yuantiCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Mini Pet

    private var miniPet: some View {
        PetView(petState: petState)
            .scaleEffect(0.32)
            .frame(width: 40, height: 46)
            .allowsHitTesting(false)
    }

    // MARK: - Collapsed Card

    private func collapsedCard(_ review: WeeklyReview) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedReviewId = review.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack(spacing: 8) {
                    miniPet
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekTitle(for: review))
                            .font(.yuanti(15, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(formattedDate(review.generatedAt))
                            .font(.yuantiCaption)
                            .foregroundStyle(Color.claudeWarmGray)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.claudeWarmGray.opacity(0.6))
                }

                // Divider
                Rectangle()
                    .fill(Color.claudeDivider)
                    .frame(height: 1)

                // Letter preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("亲爱的主人：")
                        .font(.yuanti(12, weight: .bold))
                        .foregroundStyle(Color.claudeAccent)
                    Text(review.observation)
                        .font(.yuantiCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Footer
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Echo")
                            .font(.yuantiCaption)
                            .foregroundStyle(Color.claudeWarmGray)
                        Image(systemName: "envelope")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.claudeAccent)
                    }
                }
            }
            .padding(14)
            .glassCard(tint: .glassLetterTint, cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Letter Card

    private func expandedLetterCard(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                miniPet
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekTitle(for: review))
                        .font(.yuanti(15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(formattedLongDate(review.generatedAt))
                        .font(.yuantiCaption)
                        .foregroundStyle(Color.claudeWarmGray)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        expandedReviewId = nil
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.claudeWarmGray.opacity(0.8))
                        .padding(8)
                        .background(Color.claudeWarmGray.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Top dashed separator
            dashedDivider

            // Letter body
            VStack(alignment: .leading, spacing: 14) {
                Text("亲爱的主人：")
                    .font(.yuanti(15, weight: .bold))
                    .foregroundStyle(Color.claudeAccent)

                Text(review.observation)
                    .font(.yuantiBody)
                    .foregroundStyle(.primary)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Echo")
                            .font(.yuanti(14, weight: .bold))
                            .foregroundStyle(Color.claudeAccent)
                        Text(formattedDate(review.generatedAt))
                            .font(.yuantiCaption2)
                            .foregroundStyle(Color.claudeWarmGray)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            // Bottom dashed separator
            dashedDivider

            // Action bar
            HStack {
                ShareLink(item: "亲爱的主人：\n\n\(review.observation)\n\nEcho 🐧") {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                        Text("分享")
                            .font(.yuantiCaption)
                    }
                    .foregroundStyle(Color.claudeWarmGray)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .glassCard(tint: .glassLetterTint, cornerRadius: 14)
    }

    // MARK: - Helpers

    private var dashedDivider: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(Color.claudeDivider)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func weekTitle(for review: WeeklyReview) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: review.weekStartDate)
        let weekOfMonth = calendar.component(.weekOfMonth, from: review.weekStartDate)
        return "\(month)月 第\(weekOfMonth)周"
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M/d HH:mm"
        return fmt.string(from: date)
    }

    private func formattedLongDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月d日 HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Line Shape

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#Preview {
    NavigationStack {
        WeeklyLettersView()
            .modelContainer(for: [WeeklyReview.self], inMemory: true)
    }
}

