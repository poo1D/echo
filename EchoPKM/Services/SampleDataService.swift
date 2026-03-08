import Foundation
import SwiftData

enum SampleDataService {
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<DiaryEntry>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let calendar = Calendar.current
        let now = Date()

        // (dayOffset, summary, mood, score, topics, insight, locationName?, latitude?, longitude?)
        let samples: [(Int, String, String, Int, [String], String, String?, Double?, Double?)] = [
            (-7, "Hit the gym for a solid workout session. Felt strong and energized afterwards.",
             "💪", 5, ["exercise", "health"],
             "Second week of consistent workouts!",
             "Fitness Center, Haidian", 39.9842, 116.3074),
            (-6, "Work meeting dragged on forever. Felt drained by endless discussions with no clear outcome.",
             "😔", 2, ["work", "meetings"],
             "Even tough meetings show you care.",
             nil, nil, nil),
            (-5, "Tried a new pasta recipe from that cooking channel. Turned out surprisingly good!",
             "😊", 4, ["cooking", "food"],
             "Home cooking is becoming a habit.",
             nil, nil, nil),
            (-4, "Deadline pressure at work was intense. Took a walk during lunch and it helped clear my head.",
             "😮‍💨", 2, ["work", "stress", "walking"],
             "Walking helps you reset — remember that.",
             nil, nil, nil),
            (-3, "Met up with an old friend for coffee. We talked for hours and it felt great to reconnect.",
             "☕", 5, ["friends", "social"],
             "Friend time clearly lights you up.",
             "Starbucks, Zhongguancun", 39.9816, 116.3118),
            (-2, "Quiet day at home reading. Finished two chapters of that novel. Peaceful and restorative.",
             "😌", 3, ["reading", "rest"],
             "Calm days matter as much as exciting ones.",
             nil, nil, nil),
            (-1, "Had a small friction with a coworker about project direction. We talked it out eventually.",
             "😕", 2, ["work", "conflict"],
             "You handled the conflict — that takes maturity.",
             nil, nil, nil),
            (0, "Woke up early feeling refreshed. Beautiful morning light. Starting the day with intention.",
             "🌅", 4, ["morning", "optimism"],
             "Starting the day with intention feels great.",
             "Home, Wudaokou", 39.9929, 116.3380)
        ]

        for (dayOffset, summary, mood, score, topics, insight, locName, lat, lon) in samples {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let randomHour = Int.random(in: 8...21)
            let entryDate = calendar.date(bySettingHour: randomHour, minute: Int.random(in: 0...59), second: 0, of: date)!

            let entry = DiaryEntry(
                summary: summary,
                moodEmoji: mood,
                moodScore: score,
                topics: topics,
                aiInsight: insight,
                locationName: locName,
                latitude: lat,
                longitude: lon
            )
            entry.createdAt = entryDate
            modelContext.insert(entry)
        }

        try? modelContext.save()

        // Seed sample schedules (future events)
        let sampleSchedules: [(Int, String, String?)] = [
            (2, "Dentist appointment", "Annual checkup at 2pm"),
            (5, "Team presentation", "Q1 review with product team"),
            (7, "Coffee with Sarah", nil)
        ]
        for (dayOffset, title, notes) in sampleSchedules {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let schedule = ScheduleItem(title: title, date: date, notes: notes)
            modelContext.insert(schedule)
        }

        // Seed sample habits (past week)
        let sampleHabits: [(Int, String)] = [
            (-6, "exercise"), (-4, "exercise"), (-2, "exercise"), (-1, "exercise"),
            (-5, "cooking"), (-1, "cooking"),
            (-3, "reading"), (-2, "reading"),
            (-4, "walking")
        ]
        for (dayOffset, name) in sampleHabits {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let habit = HabitEntry(name: name, date: date)
            modelContext.insert(habit)
        }

        try? modelContext.save()
    }
}
