import Foundation
import SwiftData

/// 预定义标签体系 — 限制 LLM 只能从固定标签池中选择，避免标签泛滥
enum TopicTagService {

    // MARK: - 标签定义

    /// 标签类别
    enum Category: String, CaseIterable {
        case work = "工作"
        case emotion = "情感"
        case life = "生活"
        case health = "健康"
        case growth = "成长"
        case leisure = "休闲"
    }

    /// 每个类别下的标签池
    static let tagPool: [Category: [String]] = [
        .work:    ["工作", "职场压力", "职业发展", "同事关系"],
        .emotion: ["恋爱", "家人", "友情", "孤独感", "自我反思"],
        .life:    ["日常", "美食", "旅行", "购物", "宠物", "家务"],
        .health:  ["运动", "睡眠", "健康", "冥想"],
        .growth:  ["学习", "阅读", "技能提升"],
        .leisure: ["电影", "音乐", "摄影", "游戏"],
    ]

    /// 所有合法标签（扁平列表）
    static let allTags: [String] = {
        Category.allCases.flatMap { tagPool[$0] ?? [] }
    }()

    /// 供 LLM prompt 使用的标签列表文本
    static let tagListForPrompt: String = {
        Category.allCases.map { category in
            let tags = tagPool[category]?.joined(separator: "、") ?? ""
            return "\(category.rawValue): \(tags)"
        }.joined(separator: "\n")
    }()

    // MARK: - 同义词映射（旧标签 → 标准标签）

    /// 将自由生成的旧标签映射到标准标签
    private static let synonymMap: [String: String] = [
        // 工作类
        "上班": "工作", "职场": "工作", "办公": "工作",
        "加班": "职场压力", "压力": "职场压力", "deadline": "职场压力",
        "会议": "工作", "项目": "工作",
        "升职": "职业发展", "面试": "职业发展", "跳槽": "职业发展",
        "同事": "同事关系", "领导": "同事关系", "团队": "同事关系",

        // 情感类
        "感情": "恋爱", "约会": "恋爱", "对象": "恋爱",
        "家庭": "家人", "父母": "家人", "妈妈": "家人", "爸爸": "家人", "视频": "家人",
        "朋友": "友情", "社交": "友情",
        "孤独": "孤独感", "一个人": "孤独感", "寂寞": "孤独感",
        "情绪": "自我反思", "心情": "自我反思", "焦虑": "自我反思",

        // 生活类
        "做饭": "美食", "吃饭": "美食", "火锅": "美食", "咖啡": "美食", "食堂": "美食",
        "出游": "旅行", "故宫": "旅行",
        "逛街": "购物",
        "整理": "家务", "打扫": "家务", "大扫除": "家务",
        "散步": "日常", "天气": "日常",

        // 健康类
        "跑步": "运动", "健身": "运动", "瑜伽": "运动", "走路": "运动",
        "早起": "健康", "养生": "健康",
        "失眠": "睡眠",
        "放松": "冥想",

        // 成长类
        "编程": "技能提升", "Swift": "技能提升", "写作": "技能提升",
        "看书": "阅读", "读书": "阅读", "科幻": "阅读",

        // 休闲类
        "看电影": "电影", "追剧": "电影",
        "拍照": "摄影",
    ]

    // MARK: - 标准化

    /// 将一组标签标准化：映射同义词 + 过滤非法标签 + 去重 + 限制数量
    static func normalize(_ rawTopics: [String], maxCount: Int = 3) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for topic in rawTopics {
            let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            // 尝试同义词映射
            let mapped = synonymMap[trimmed] ?? trimmed
            // 只保留合法标签
            guard allTags.contains(mapped), !seen.contains(mapped) else { continue }
            seen.insert(mapped)
            result.append(mapped)
            if result.count >= maxCount { break }
        }

        return result
    }

    /// 查找标签所属类别
    static func category(for tag: String) -> Category? {
        for (cat, tags) in tagPool {
            if tags.contains(tag) { return cat }
        }
        return nil
    }

    // MARK: - 数据迁移

    private static let migrationKey = "TopicTagService.migrated.v1"

    /// 一次性迁移：将已有日记的旧标签标准化
    @MainActor
    static func migrateIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let descriptor = FetchDescriptor<DiaryEntry>()
        guard let entries = try? modelContext.fetch(descriptor) else { return }

        var changed = false
        for entry in entries {
            let normalized = normalize(entry.topics)
            if normalized != entry.topics {
                entry.topics = normalized
                changed = true
            }
        }

        if changed {
            try? modelContext.save()
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
