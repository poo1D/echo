import Foundation
import SwiftData

enum SampleDataService {
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<DiaryEntry>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let calendar = Calendar.current
        let now = Date()

        // --- Diary Entries: spread across last 4 weeks + today ---
        // (dayOffset, hour, summary, mood, score, topics, insight, locationName?, lat?, lon?)
        let samples: [(Int, Int, String, String, Int, [String], String, String?, Double?, Double?)] = [
            // Week -4
            (-27, 9,  "早起跑了三公里，空气很好，感觉整个人都活过来了。",
             "💪", 5, ["运动", "跑步"], "坚持跑步的习惯正在养成！", "奥林匹克森林公园", 40.0209, 116.3847),
            (-26, 20, "加班到很晚，项目deadline快到了，心里有点焦虑。",
             "😰", 2, ["工作", "加班", "压力"], "记得给自己留些喘息的空间。", nil, nil, nil),
            (-25, 15, "下午和同事一起喝了杯咖啡，聊了很多有趣的事。",
             "😊", 4, ["社交", "咖啡"], "和人交流总能让你充电。", "Manner Coffee", 39.9816, 116.3118),

            // Week -3
            (-20, 10, "周末去了趟故宫，人不算多，拍了很多好看的照片。",
             "🤩", 5, ["旅行", "摄影", "故宫"], "记录生活的美好瞬间。", "故宫博物院", 39.9163, 116.3972),
            (-19, 21, "晚上试了新的冥想app，第一次坚持了20分钟，很平静。",
             "😌", 4, ["冥想", "放松"], "内心的宁静是最好的礼物。", nil, nil, nil),
            (-18, 12, "中午吃了学校食堂的新菜，味道一般但价格便宜。",
             "😐", 3, ["美食", "日常"], "平淡的日子也值得记录。", nil, nil, nil),
            (-17, 22, "看完了《三体》第二部，情节太震撼了，久久不能平静。",
             "🤩", 5, ["阅读", "科幻"], "好书能打开新的世界。", nil, nil, nil),

            // Week -2
            (-13, 8,  "清晨瑜伽30分钟，身体柔韧性好了很多。",
             "😊", 4, ["运动", "瑜伽"], "身体和心灵都在成长。", nil, nil, nil),
            (-12, 19, "和妈妈视频聊了一个小时，她最近种了很多花，很开心。",
             "🥰", 5, ["家人", "视频"], "家人的爱是最温暖的力量。", nil, nil, nil),
            (-11, 14, "下午的会议很无聊，但结束后和团队达成了共识。",
             "😐", 3, ["工作", "会议"], "耐心也是一种能力。", nil, nil, nil),
            (-10, 20, "尝试做了红烧肉，虽然有点咸但总体成功！拍照发了朋友圈。",
             "😊", 4, ["做饭", "美食"], "厨艺在进步中！", nil, nil, nil),
            (-9, 17, "在公园散步时突然下雨了，跑到亭子里避雨，反而觉得很浪漫。",
             "😌", 4, ["散步", "天气"], "意外总能带来惊喜。", "玉渊潭公园", 39.9120, 116.3200),

            // Week -1
            (-6, 9,  "今天开始学习Swift编程，跟着教程写了第一个Hello World。",
             "🤩", 5, ["学习", "编程", "Swift"], "学习新技能的感觉真好。", nil, nil, nil),
            (-5, 21, "工作上被领导批评了，心情有点低落，晚上吃了顿火锅安慰自己。",
             "😢", 2, ["工作", "情绪", "美食"], "低谷也会过去的。", "海底捞", 39.9950, 116.3280),
            (-4, 15, "陪朋友去看了电影《沙丘2》，视觉效果太棒了。",
             "😊", 4, ["电影", "社交"], "和朋友在一起总是快乐的。", "万达影城", 39.9800, 116.3500),
            (-3, 10, "周末大扫除，整理了书架，扔掉了一堆不需要的东西，神清气爽。",
             "💪", 4, ["整理", "家务"], "断舍离让生活更简单。", nil, nil, nil),
            (-2, 20, "晚上失眠了，脑子里想了很多事情，凌晨两点才睡着。",
             "😴", 2, ["睡眠", "焦虑"], "试试睡前做些放松练习。", nil, nil, nil),
            (-1, 11, "去菜市场买了新鲜蔬菜，做了一顿健康午餐，很满足。",
             "😊", 4, ["做饭", "健康"], "好好吃饭就是善待自己。", nil, nil, nil),

            // Today
            (0, 9, "早起阳光很好，泡了杯咖啡坐在窗边，感觉生活很美好。",
             "🤩", 5, ["早起", "咖啡", "心情"], "感恩每一个美好的早晨。", "家", 39.9929, 116.3380),
        ]

        for (dayOffset, hour, summary, mood, score, topics, insight, locName, lat, lon) in samples {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let entryDate = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: date)!

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

        // --- Mood check-in entry for today ---
        let moodCheckin = DiaryEntry(
            summary: "心情记录: 😊",
            moodEmoji: "😊",
            moodScore: 4,
            topics: [MoodUtils.moodCheckinTopic]
        )
        moodCheckin.createdAt = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        modelContext.insert(moodCheckin)

        try? modelContext.save()

        // --- Schedules ---
        let sampleSchedules: [(Int, String, String?)] = [
            (0,  "下午团队周会", "3点，线上会议"),
            (1,  "看牙医", "年度检查"),
            (3,  "和小李吃饭", "约在大悦城"),
            (5,  "提交项目报告", nil),
            (7,  "妈妈生日", "准备礼物！"),
        ]
        for (dayOffset, title, notes) in sampleSchedules {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let hour = dayOffset == 0 ? 15 : 10
            let scheduleDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
            let schedule = ScheduleItem(title: title, date: scheduleDate, notes: notes)
            modelContext.insert(schedule)
        }

        // --- Habits: spread across 5 weeks for heatmap ---
        let habitData: [(Int, String)] = [
            // Week -4 (4 weeks ago)
            (-27, "exercise"), (-26, "reading"), (-25, "exercise"),
            (-24, "meditation"), (-23, "exercise"), (-23, "reading"),
            (-22, "cooking"),

            // Week -3
            (-20, "exercise"), (-20, "meditation"), (-19, "reading"),
            (-18, "exercise"), (-17, "reading"), (-17, "cooking"),
            (-16, "exercise"), (-16, "meditation"),

            // Week -2
            (-13, "exercise"), (-13, "yoga"), (-12, "reading"),
            (-11, "exercise"), (-11, "meditation"), (-10, "cooking"),
            (-10, "reading"), (-9, "exercise"), (-9, "walking"),
            (-8, "yoga"),

            // Week -1
            (-6, "exercise"), (-6, "reading"), (-5, "cooking"),
            (-4, "exercise"), (-4, "meditation"), (-3, "exercise"),
            (-3, "reading"), (-3, "cooking"),
            (-2, "reading"), (-1, "exercise"), (-1, "cooking"),

            // This week
            (0, "exercise"), (0, "reading"),
        ]
        for (dayOffset, name) in habitData {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let habit = HabitEntry(name: name, date: date)
            modelContext.insert(habit)
        }

        try? modelContext.save()
    }
}
