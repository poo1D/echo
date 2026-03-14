import SwiftUI

// MARK: - Memory Recall Card

struct MemoryRecallCard: View {
    let data: MemoryRecallData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "7B68EE"))
                Text("相关记忆")
                    .font(.yuantiCaption.weight(.semibold))
                    .foregroundStyle(Color(hex: "7B68EE"))
                Spacer()
                Text(data.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if let emoji = data.moodEmoji {
                    Text(emoji)
                        .font(.title3)
                }
                Text(data.summary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }

            if !data.relevanceReason.isEmpty {
                Text(data.relevanceReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .glassCardCompact(tint: .glassMemoryTint)
    }
}

// MARK: - Mood Trend Card

struct MoodTrendCard: View {
    let data: MoodTrendData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: trendIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(trendColor)
                Text("心情趋势")
                    .font(.yuantiCaption.weight(.semibold))
                    .foregroundStyle(trendColor)
            }

            Text(data.insight)
                .font(.subheadline)
                .foregroundStyle(.primary)

            // Mini trend visualization
            if !data.scores.isEmpty {
                HStack(spacing: 4) {
                    ForEach(data.scores.suffix(7), id: \.date) { item in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(moodColor(for: item.score))
                            .frame(width: 20, height: CGFloat(item.score) * 8)
                    }
                }
                .frame(height: 40, alignment: .bottom)
            }
        }
        .padding(12)
        .glassCardCompact(tint: trendColor.opacity(0.15))
    }

    private var trendIcon: String {
        switch data.trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch data.trend {
        case "improving": return Color(hex: "4CAF50")
        case "declining": return Color(hex: "FF6B35")
        default: return Color(hex: "FFB347")
        }
    }

    private func moodColor(for score: Int) -> Color {
        switch score {
        case 1: return Color(hex: "FF8A65")
        case 2: return Color(hex: "FFB74D")
        case 3: return Color(hex: "FFD54F")
        case 4: return Color(hex: "AED581")
        case 5: return Color(hex: "81C784")
        default: return .gray
        }
    }
}

// MARK: - Schedule Confirm Card

struct ScheduleConfirmCard: View {
    let data: ScheduleConfirmData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "4A90D9"))

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.subheadline.weight(.medium))
                Text(data.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = data.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if data.isNew {
                Text("已添加")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "4A90D9"))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .glassCardCompact(tint: Color(hex: "4A90D9").opacity(0.12))
    }
}

// MARK: - Habit Streak Card

struct HabitStreakCard: View {
    let data: HabitStreakData

    var body: some View {
        HStack(spacing: 10) {
            Text(data.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.habitName.capitalized)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text("本周: \(data.streakCount)次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if data.change > 0 {
                        Text("+\(data.change)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: "4CAF50"))
                    }
                }
            }

            Spacer()

            // Streak dots
            HStack(spacing: 3) {
                ForEach(0..<min(data.streakCount, 7), id: \.self) { _ in
                    Circle()
                        .fill(Color(hex: "FF6B35"))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(12)
        .glassCardCompact(tint: .glassHabitTint)
    }
}

// MARK: - Pattern Insight Card

struct PatternInsightCard: View {
    let data: PatternInsightData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "FFB347"))
                Text("规律")
                    .font(.yuantiCaption.weight(.semibold))
                    .foregroundStyle(Color(hex: "FFB347"))
                if data.occurrences > 0 {
                    Spacer()
                    Text("观察到 \(data.occurrences) 次")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(data.pattern)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            if !data.evidence.isEmpty {
                Text(data.evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .glassCardCompact(tint: Color(hex: "FFB347").opacity(0.12))
    }
}

// MARK: - Rich Content Card Router

struct RichContentCardView: View {
    let content: RichContent

    var body: some View {
        switch content {
        case .memoryRecall(let data):
            MemoryRecallCard(data: data)
        case .moodTrend(let data):
            MoodTrendCard(data: data)
        case .scheduleConfirm(let data):
            ScheduleConfirmCard(data: data)
        case .habitStreak(let data):
            HabitStreakCard(data: data)
        case .patternInsight(let data):
            PatternInsightCard(data: data)
        case .healthInsight(let data):
            HealthInsightCard(data: data)
        }
    }
}

// MARK: - Health Insight Card

struct HealthInsightCard: View {
    let data: HealthInsightData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(data.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            Text(data.detail)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let correlation = data.correlation, !correlation.isEmpty {
                Text(correlation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .glassCardCompact(tint: .glassHealthTint)
    }

    private var iconName: String {
        switch data.type {
        case .sleepMood: return "moon.fill"
        case .exerciseBoost: return "figure.run"
        case .stepGoal: return "shoeprints.fill"
        case .sleepWarning: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch data.type {
        case .sleepMood: return Color(hex: "7B68EE")
        case .exerciseBoost: return Color(hex: "4CAF50")
        case .stepGoal: return Color(hex: "FF6B35")
        case .sleepWarning: return Color(hex: "FFB347")
        }
    }
}
