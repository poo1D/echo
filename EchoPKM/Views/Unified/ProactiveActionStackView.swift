import SwiftUI
import SwiftData

// MARK: - ActionCard

private struct ActionCard: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: CardAction

    enum CardAction {
        case schedule(ScheduleItem)
        case habit(String)
    }
}

// MARK: - ProactiveActionStackView

struct ProactiveActionStackView: View {
    let todaySchedules: [ScheduleItem]
    let recentHabits: [HabitEntry]
    @Binding var showCelebration: Bool

    @Environment(\.modelContext) private var modelContext

    @State private var dismissedIDs: Set<String> = []
    @State private var completedIDs: Set<String> = []
    @State private var dragOffset: CGSize = .zero

    // MARK: - Computed card list

    private var visibleCards: [ActionCard] {
        let excluded = dismissedIDs.union(completedIDs)
        var cards: [ActionCard] = []

        for s in todaySchedules where !excluded.contains("s_\(s.id)") {
            let timeStr = s.date.formatted(date: .omitted, time: .shortened)
            cards.append(ActionCard(
                id: "s_\(s.id)",
                title: s.title,
                subtitle: "今天 \(timeStr)",
                icon: "calendar",
                color: Color(hex: "4A90D9"),
                action: .schedule(s)
            ))
        }

        for name in pendingHabitNames where !excluded.contains("h_\(name)") {
            let emoji = HabitStreakData.emojiFor(name)
            cards.append(ActionCard(
                id: "h_\(name)",
                title: "\(emoji) \(name.capitalized)",
                subtitle: "今天还没记录",
                icon: "flame.fill",
                color: Color(hex: "FF6B35"),
                action: .habit(name)
            ))
        }

        return cards
    }

    /// Habits active in the past 7 days but not yet logged today
    private var pendingHabitNames: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return [] }

        let weekHabits = recentHabits.filter { $0.date >= weekAgo }
        let allNames = Set(weekHabits.map { $0.name })
        let todayNames = Set(recentHabits.filter { calendar.isDate($0.date, inSameDayAs: today) }.map { $0.name })
        return Array(allNames.subtracting(todayNames)).sorted()
    }

    // MARK: - Body

    var body: some View {
        let cards = visibleCards
        if !cards.isEmpty {
            let display = Array(cards.prefix(3))
            ZStack(alignment: .top) {
                ForEach(Array(display.enumerated()), id: \.element.id) { idx, card in
                    let isTop = idx == 0
                    ActionCardRowView(
                        card: card,
                        isTop: isTop,
                        dragOffset: isTop ? dragOffset : .zero,
                        onComplete: { completeCard(card) }
                    )
                    .offset(y: CGFloat(idx) * 9)
                    .scaleEffect(1.0 - CGFloat(idx) * 0.04, anchor: .top)
                    .opacity(1.0 - Double(idx) * 0.15)
                    .zIndex(Double(display.count - idx))
                    .gesture(isTop ? dragGesture(for: card) : nil)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .frame(height: 60 + CGFloat(min(display.count - 1, 2)) * 9)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cards.map(\.id))
        }
    }

    // MARK: - Gestures & Actions

    private func dragGesture(for card: ActionCard) -> some Gesture {
        DragGesture()
            .onChanged { v in
                dragOffset = v.translation
            }
            .onEnded { v in
                if abs(v.translation.width) > 80 {
                    let flyX: CGFloat = v.translation.width > 0 ? 520 : -520
                    withAnimation(.easeOut(duration: 0.22)) {
                        dragOffset = CGSize(width: flyX, height: v.translation.height * 0.4)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        dragOffset = .zero
                        dismissedIDs.insert(card.id)
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func completeCard(_ card: ActionCard) {
        switch card.action {
        case .schedule(let s):
            s.isCompleted = true
            try? modelContext.save()
        case .habit(let name):
            let entry = HabitEntry(name: name, date: Date(), completed: true)
            modelContext.insert(entry)
            try? modelContext.save()
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            completedIDs.insert(card.id)
        }
        showCelebration = true
    }
}

// MARK: - ActionCardRowView

private struct ActionCardRowView: View {
    let card: ActionCard
    let isTop: Bool
    let dragOffset: CGSize
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(card.color, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    Circle()
                        .fill(card.color.opacity(0.1))
                        .frame(width: 26, height: 26)
                }
            }
            .buttonStyle(.plain)

            // Icon
            Image(systemName: card.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(card.color)
                .frame(width: 28, height: 28)
                .background(card.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.yuanti(14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(card.subtitle)
                    .font(.yuantiCaption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(isTop ? 0.92 : 0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(isTop ? 0.07 : 0.03), radius: 8, y: 3)
        .offset(dragOffset)
        .rotationEffect(.degrees(isTop ? Double(dragOffset.width) / 28 : 0))
    }
}
