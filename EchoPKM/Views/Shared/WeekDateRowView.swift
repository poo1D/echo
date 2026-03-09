import SwiftUI

struct WeekDateRow: View {
    private let calendar = Calendar.current
    private let today = Date()

    var body: some View {
        HStack {
            ForEach(weekDays, id: \.self) { date in
                VStack(spacing: 4) {
                    Text(dayLetter(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption.weight(calendar.isDateInToday(date) ? .bold : .regular))
                        .foregroundStyle(calendar.isDateInToday(date) ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background(
                            calendar.isDateInToday(date)
                                ? Color.claudeAccent
                                : Color.clear
                        )
                        .clipShape(Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekDays: [Date] {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
