import SwiftUI

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    private var weekDays: [Date] {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                DayButton(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date)
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = date
                    }
                }
            }
        }
    }
}

// MARK: - Day Button
struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(2).uppercased()
    }
    
    private var dayOfMonth: String {
        "\(calendar.component(.day, from: date))"
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(dayOfWeek)
                    .font(JournalFonts.caption)
                    .foregroundStyle(isSelected ? JournalColors.inkBlack : JournalColors.warmGray)
                
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(JournalColors.inkBlack)
                            .frame(width: 32, height: 32)
                    }
                    
                    Text(dayOfMonth)
                        .font(JournalFonts.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .white : JournalColors.inkBlack)
                }
                
                // 已记录指示器
                if isToday && !isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(JournalColors.warmGray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WeekCalendarView(selectedDate: .constant(Date()))
        .padding()
        .background(PaperTexture())
}
