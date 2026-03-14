import Foundation
import SwiftData

enum SampleDataService {
    /// Returns the seeded entries if seeding was performed, nil otherwise
    @discardableResult
    static func seedIfNeeded(modelContext: ModelContext) -> [DiaryEntry]? {
        let descriptor = FetchDescriptor<DiaryEntry>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return nil }

        let calendar = Calendar.current
        let now = Date()
        var seededEntries: [DiaryEntry] = []

        // --- Diary Entries: spread across last 4 weeks + today ---
        // (dayOffset, hour, summary, mood, score, topics, insight, locationName?, lat?, lon?)
        // Demo故事线：25岁独居职场女生，在新城市打拼，用Echo记录真实生活
        // 核心叙事：工作压力反复出现 → 运动/阅读是情绪出口 → AI能发现这个规律
        let samples: [(Int, Int, String, String, Int, [String], String, String?, Double?, Double?)] = [
            // Week -4：刚入职新团队，兴奋中带着压力
            (-27, 8,  "第一次独立主导需求评审，会上说着说着有点卡壳，但最后还是撑过来了。领导说思路可以、细节再打磨。",
             "😰", 3, ["工作", "职场压力"], "每次开口都是一次练习，慢慢来。", nil, nil, nil),
            (-26, 21, "晚上跑了五公里，跑的时候什么都不想，只听着耳机里的音乐，感觉把今天的焦虑全甩掉了。",
             "💪", 5, ["运动", "健康"], "运动是你最稳定的情绪出口。", "奥林匹克森林公园", 40.0209, 116.3847),
            (-25, 15, "和同事小林喝咖啡，她说她刚来的时候也经常被改需求，现在习惯了。感觉不那么孤单了。",
             "😊", 4, ["同事关系", "友情"], "同频的人总能带来力量。", "Manner Coffee", 39.9816, 116.3118),
            (-24, 20, "连续加班三天，今天终于把方案改完交出去了。累，但有点成就感。给自己点了外卖犒劳。",
             "😌", 4, ["工作", "成就感"], "扛过来了，就是进步。", nil, nil, nil),

            // Week -3：明显的情绪低谷，被说了一次
            (-20, 22, "今晚睡不着，脑子里一直在回放下午开会的画面。领导当着大家面说我的方案不够落地，旁边几个同事都看着我。我当时脸很红，说了句我回去再想想就坐下了。",
             "😢", 1, ["工作", "职场压力", "自我反思"], "被当众否定很难受——但你没有崩，这已经很厉害了。", nil, nil, nil),
            (-19, 8,  "昨晚哭了一会儿，今早起来反而清醒了。出门跑了步，跑完想明白了：方案确实太理想化，我需要多问实际业务的人。",
             "💪", 4, ["运动", "自我反思"], "你有把低谷变成燃料的能力。", "奥林匹克森林公园", 40.0209, 116.3847),
            (-18, 21, "看书看到了一句话：被否定不是终点，是校准。突然觉得上周的事其实还好。泡了杯花茶，读了两个小时，很平静。",
             "😌", 4, ["阅读", "自我反思"], "你总能在书里找到力量。", nil, nil, nil),
            (-17, 12, "中午约了产品里最懂业务的同事吃饭，她跟我讲了很多实际的落地逻辑，我边吃边记笔记。",
             "😊", 4, ["工作", "同事关系"], "主动求教，是成长最快的方式。", nil, nil, nil),

            // Week -2：逐渐回升，小习惯在积累
            (-13, 7,  "开始定了个小目标：每天早起跑步，哪怕二十分钟。今天第一天，天还没亮，路上只有我一个人，有点酷。",
             "💪", 5, ["运动", "健康"], "第一步永远是最难的，你迈出去了。", "奥林匹克森林公园", 40.0209, 116.3847),
            (-12, 19, "和妈妈视频，她说我气色比上次好多了，问我是不是谈恋爱了哈哈。其实只是最近多运动了。",
             "🥰", 5, ["家人"], "妈妈总是第一个发现你变好的人。", nil, nil, nil),
            (-11, 14, "今天的周会，我主动提了一个优化点，领导当场说这个方向对。旁边那个同事给我比了个大拇指。",
             "😊", 4, ["工作", "成就感"], "三周前的你一定没想到会走到这里。", nil, nil, nil),
            (-10, 21, "跑步已经连续七天了！配速还是很慢，但坚持下来了。睡眠也好很多，昨晚十一点就睡着了。",
             "💪", 5, ["运动", "健康", "成就感"], "七天的习惯正在悄悄改变你。", nil, nil, nil),
            (-9, 20,  "读完了《蛤蟆先生去看心理医生》，里面说到成人自我状态，感觉就是在说我。又看了很久。",
             "😌", 4, ["阅读", "自我反思"], "好书会在对的时候遇见你。", nil, nil, nil),

            // Week -1：状态最好的一周，但周四又被批了一次——模式很清晰
            (-6, 8,   "早跑+读书，完美的早晨。今天要提案，有点紧张，但感觉准备好了。",
             "💪", 5, ["运动", "工作"], "状态在线，今天会很好。", nil, nil, nil),
            (-5, 22,  "提案通过了！领导说这次有说服力多了。下班后一个人去吃了喜欢的螺蛳粉庆祝，超满足。",
             "🤩", 5, ["工作", "成就感"], "你用三周的时间证明了自己。", "遇见小面", 39.9950, 116.3280),
            (-4, 20,  "开会的时候有个方案被领导否了，说执行成本太高。我今天好像还好，没有之前那么在意了。下班跑了步。",
             "😊", 3, ["工作", "职场压力", "运动"], "你和三周前的那个晚上已经不一样了。", nil, nil, nil),
            (-3, 11,  "周末在家，做了顿自己最喜欢吃的炒饭，开着窗户，放着歌，独处的感觉有时候挺好的。",
             "😌", 4, ["美食", "日常"], "学会享受独处，是一种成熟。", nil, nil, nil),
            (-2, 21,  "读了两小时书，发现自己最近一个月读完三本了——以前一本都读不完。运动也连续十五天了。有点想给自己鼓个掌。",
             "🤩", 5, ["阅读", "运动", "成就感"], "你正在悄悄变成更好的自己。", nil, nil, nil),
            (-1, 20,  "周日下午在咖啡馆坐了两个小时，写了下周的计划，顺便把上周的事都整理了一遍。感觉很踏实。",
             "😌", 4, ["自我反思", "日常"], "留出空间复盘，是高效的秘密。", "Manner Coffee", 39.9816, 116.3118),

            // Today
            (0, 9, "今天天气好，泡了咖啡坐在窗边，明天要开周会，有点期待又有点紧张。但感觉和一个月前不一样了，没那么怕了。",
             "😊", 4, ["日常", "工作"], "你比自己想象的更有韧性。", "家", 39.9929, 116.3380),
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
            seededEntries.append(entry)
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
        seededEntries.append(moodCheckin)

        try? modelContext.save()

        // --- Schedules ---
        let sampleSchedules: [(Int, String, String?)] = [
            (0,  "产品周会", "汇报上周进展，准备好数据"),
            (1,  "和小林午饭", "她说有事找我聊"),
            (3,  "代码评审", "下午两点，线上"),
            (5,  "提交季度报告", "截止周五下班前"),
            (7,  "妈妈生日", "记得提前买好礼物！"),
        ]
        for (dayOffset, title, notes) in sampleSchedules {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let hour = dayOffset == 0 ? 15 : 10
            let scheduleDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
            let schedule = ScheduleItem(title: title, date: scheduleDate, notes: notes)
            modelContext.insert(schedule)
        }

        // --- Habits: 展示运动+阅读两条清晰连续的习惯线，与故事线对应 ---
        let habitData: [(Int, String)] = [
            // Week -4（开始跑步）
            (-26, "exercise"), (-25, "reading"),
            (-24, "exercise"), (-23, "reading"),
            (-22, "exercise"),

            // Week -3（低谷后用运动恢复）
            (-19, "exercise"), (-19, "reading"),
            (-18, "reading"), (-17, "exercise"),
            (-16, "exercise"), (-16, "reading"),

            // Week -2（连续七天运动里程碑）
            (-13, "exercise"), (-13, "reading"),
            (-12, "exercise"), (-11, "exercise"),
            (-11, "reading"), (-10, "exercise"),
            (-10, "reading"), (-9, "exercise"),
            (-9, "reading"),

            // Week -1（连续十五天，阅读三本）
            (-6, "exercise"), (-6, "reading"),
            (-5, "exercise"), (-5, "reading"),
            (-4, "exercise"), (-4, "reading"),
            (-3, "exercise"), (-3, "reading"),
            (-2, "exercise"), (-2, "reading"),
            (-1, "exercise"), (-1, "reading"),

            // This week
            (0, "exercise"), (0, "reading"),
        ]
        for (dayOffset, name) in habitData {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
            let habit = HabitEntry(name: name, date: date)
            modelContext.insert(habit)
        }

        try? modelContext.save()

        return seededEntries
    }
}
