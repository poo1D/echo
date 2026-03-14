import SwiftUI

enum TimeDimension: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var label: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        }
    }
}

struct DiaryTimelineSection: View {
    var entries: [DiaryEntry]
    @Binding var selectedEntry: DiaryEntry?
    @Binding var editingEntry: DiaryEntry?
    @Binding var showTagFilter: Bool
    var selectedTags: Set<String>
    var onDeleteRequest: (DiaryEntry) -> Void

    @State private var timeDimension: TimeDimension = .day
    @State private var swipeDirection: Edge = .trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("日记")
                    .font(.yuantiTitle2)
                    .foregroundStyle(.primary)

                Spacer()

                // Time dimension indicator
                HStack(spacing: 2) {
                    ForEach(TimeDimension.allCases, id: \.self) { dim in
                        Text(dim.label)
                            .font(.yuantiCaption2.weight(dim == timeDimension ? .bold : .regular))
                            .foregroundStyle(dim == timeDimension ? Color.claudeAccent : Color.claudeWarmGray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                dim == timeDimension
                                    ? Color.claudeAccent.opacity(0.12)
                                    : Color.clear,
                                in: Capsule()
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    timeDimension = dim
                                }
                            }
                    }
                }

                Button {
                    showTagFilter = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(selectedTags.isEmpty ? Color.claudeWarmGray : Color.claudeAccent)
                        .padding(8)
                        .background(
                            selectedTags.isEmpty
                                ? Color.claudeSurfaceTint
                                : Color.claudeAccent.opacity(0.12),
                            in: Circle()
                        )
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Week date row
            WeekDateRow()
                .padding(.horizontal)
                .padding(.top, 8)

            // Active tag filter chips
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                            Text(tag)
                                .font(.yuantiCaption2.weight(.medium))
                                .foregroundStyle(Color.claudeAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.claudeAccent.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }

            // Entries with swipe gesture
            Group {
                if filteredEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text(selectedTags.isEmpty ? "还没有记录" : "没有匹配的记录")
                            .font(.yuantiSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(groupedEntries, id: \.0) { label, dayEntries in
                            Section {
                                ForEach(dayEntries) { entry in
                                    DiaryCard(entry: entry)
                                        .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1.0 : 0.55)
                                                .scaleEffect(phase.isIdentity ? 1.0 : 0.93)
                                                .blur(radius: phase.isIdentity ? 0 : 1.5)
                                        }
                                        .onTapGesture { selectedEntry = entry }
                                        .contextMenu {
                                            Button {
                                                editingEntry = entry
                                            } label: {
                                                Label("编辑", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                onDeleteRequest(entry)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Text(label)
                                    .font(.yuantiTitle3)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        guard abs(horizontal) > 50 else { return }

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if horizontal < 0 {
                                // Swipe left → larger dimension
                                switch timeDimension {
                                case .day: timeDimension = .week
                                case .week: timeDimension = .month
                                case .month: break
                                }
                            } else {
                                // Swipe right → smaller dimension
                                switch timeDimension {
                                case .month: timeDimension = .week
                                case .week: timeDimension = .day
                                case .day: break
                                }
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Filtering & Grouping

    private var filteredEntries: [DiaryEntry] {
        if selectedTags.isEmpty { return entries }
        return entries.filter { entry in
            !selectedTags.isDisjoint(with: Set(entry.topics))
        }
    }

    private var groupedEntries: [(String, [DiaryEntry])] {
        let calendar = Calendar.current

        switch timeDimension {
        case .day:
            let grouped = Dictionary(grouping: filteredEntries) { entry in
                calendar.startOfDay(for: entry.createdAt)
            }
            return grouped.sorted { $0.key > $1.key }.map { (daySectionTitle($0.key), $0.value) }

        case .week:
            let grouped = Dictionary(grouping: filteredEntries) { entry in
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: entry.createdAt)
                return calendar.date(from: comps)!
            }
            return grouped.sorted { $0.key > $1.key }.map { (weekSectionTitle($0.key), $0.value) }

        case .month:
            let grouped = Dictionary(grouping: filteredEntries) { entry in
                let comps = calendar.dateComponents([.year, .month], from: entry.createdAt)
                return calendar.date(from: comps)!
            }
            return grouped.sorted { $0.key > $1.key }.map { (monthSectionTitle($0.key), $0.value) }
        }
    }

    private func daySectionTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE, M月d日, yyyy"
        return formatter.string(from: date)
    }

    private func weekSectionTitle(_ weekStart: Date) -> String {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        if calendar.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear) {
            return "本周 (\(fmt.string(from: weekStart)) - \(fmt.string(from: weekEnd)))"
        }
        return "\(fmt.string(from: weekStart)) - \(fmt.string(from: weekEnd))"
    }

    private func monthSectionTitle(_ monthStart: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: monthStart)
    }
}
