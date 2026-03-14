import SwiftUI
import SwiftData

struct WeeklyLettersView: View {
    @Query(sort: \WeeklyReview.weekStartDate, order: .reverse) private var allReviews: [WeeklyReview]
    @State private var expandedReviewId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Subtitle
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.claudeAccent)
                    Text("每周日19:00 来自AI朋友的信")
                        .font(.subheadline)
                        .foregroundStyle(Color.claudeWarmGray)
                }
                .padding(.horizontal, 4)

                if allReviews.isEmpty {
                    emptyState
                } else {
                    Text("历史信箱:")
                        .font(.caption)
                        .foregroundStyle(Color.claudeWarmGray)
                        .padding(.horizontal, 4)

                    ForEach(allReviews) { review in
                        if expandedReviewId == review.id {
                            expandedLetterCard(review)
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        } else {
                            collapsedRow(review)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                    Image(systemName: "clock.fill")
                }
                .font(.subheadline)
                .foregroundStyle(Color.claudeAccent)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.open")
                .font(.system(size: 40))
                .foregroundStyle(Color.claudeWarmGray.opacity(0.4))
            Text("还没有来信哦")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Text("多写日记，Echo就会给你写信啦")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Collapsed Row

    private func collapsedRow(_ review: WeeklyReview) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                expandedReviewId = review.id
            }
        } label: {
            HStack(spacing: 12) {
                // Week info card (left)
                weekInfoCard(review)

                // Letter preview (right)
                VStack(alignment: .leading, spacing: 6) {
                    Text("亲爱的主人：")
                        .font(.yuantiSubheadline.weight(.medium))
                        .foregroundStyle(Color.claudeAccent)

                    Text(review.observation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .glassCardCompact(cornerRadius: 10)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Info Card

    private func weekInfoCard(_ review: WeeklyReview) -> some View {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: review.weekStartDate)
        let month = calendar.component(.month, from: review.weekStartDate)
        let weekOfYear = calendar.component(.weekOfYear, from: review.weekStartDate)

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "M/d"
        let dateStr = dateFmt.string(from: review.generatedAt)

        return VStack(spacing: 6) {
            Text("\(String(year))")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
            Text("\(month)月 第\(weekOfYear)周")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 40)

            Text(dateStr)
                .font(.caption2)
                .foregroundStyle(Color.claudeWarmGray)
            Text("Echo \u{1F4E7}")
                .font(.caption2)
                .foregroundStyle(Color.claudeAccent)
        }
        .padding(10)
        .frame(width: 90)
        .glassCardCompact()
    }

    // MARK: - Expanded Letter Card

    private func expandedLetterCard(_ review: WeeklyReview) -> some View {
        VStack(spacing: 0) {
            // Collapsed row at top (tap to collapse)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    expandedReviewId = nil
                }
            } label: {
                HStack(spacing: 12) {
                    weekInfoCard(review)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("亲爱的主人：")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.claudeAccent)

                        Text(review.observation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.claudeSurfaceTint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .buttonStyle(.plain)

            // Full letter
            VStack(alignment: .leading, spacing: 0) {
                // Metadata bar
                letterMetadataBar(review)

                // Dashed separator
                dashedSeparator

                // Letter body
                VStack(alignment: .leading, spacing: 16) {
                    Text("亲爱的主人：")
                        .font(.yuantiBody.weight(.medium))
                        .foregroundStyle(Color.claudeAccent)

                    Text(review.observation)
                        .font(.yuantiBody)
                        .foregroundStyle(.primary)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)

                    // Signature
                    HStack {
                        Spacer()
                        Text("Echo \u{1F427}")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.claudeAccent)
                    }
                }
                .padding(20)

                // Bottom dashed separator
                dashedSeparator
            }
            .glassCard(tint: .glassLetterTint, cornerRadius: 12)
            .padding(.top, 12)
        }
    }

    // MARK: - Metadata Bar

    private func letterMetadataBar(_ review: WeeklyReview) -> some View {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "M月d日 HH:mm"
        let dateStr = dateFmt.string(from: review.generatedAt)

        return HStack {
            HStack(spacing: 4) {
                Text("\u{1F48C}")
                Text("来信: \(dateStr)")
                    .font(.caption)
                    .foregroundStyle(Color.claudeWarmGray)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("\u{270D}\u{FE0F}")
                Text("Echo")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Share button
            ShareLink(item: "亲爱的主人：\n\n\(review.observation)\n\nEcho \u{1F427}") {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(Color.claudeWarmGray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Dashed Separator

    private var dashedSeparator: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundStyle(Color.claudeDivider)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

// MARK: - Line Shape

private struct Line: Shape {
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
