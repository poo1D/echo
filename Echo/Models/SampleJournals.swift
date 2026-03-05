import Foundation

/// 10篇示例日记 - 用于验证AI日程习惯提取效果
struct SampleJournals {
    struct SampleEntry: Identifiable {
        let id: UUID
        let title: String
        let content: String
        let date: Date
    }
    
    static let entries: [SampleEntry] = [
        // 1. 包含明确日程
        SampleEntry(
            id: UUID(),
            title: "忙碌的周一",
            content: """
            今天早上起来有点累，但还是按时出门了。
            明天早上9点有个重要的产品会议，需要准备PPT。
            下午和小李约了3点一起讨论项目方案。
            晚上回家后看了会书，感觉很充实。
            """,
            date: Date()
        ),
        
        // 2. 习惯养成
        SampleEntry(
            id: UUID(),
            title: "坚持早起第5天",
            content: """
            连续5天早起啦！今天6点就醒了，感觉精神特别好。
            早起后跑了3公里，出了一身汗感觉很畅快。
            早餐吃了燕麦和水果，健康饮食也坚持3天了。
            希望能继续保持这个好习惯！
            """,
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        
        // 3. 情绪低落
        SampleEntry(
            id: UUID(),
            title: "有点累",
            content: """
            最近工作压力好大，感觉有点喘不过气来。
            今天又加班到9点，回家后只想躺着什么也不干。
            希望周末能好好休息一下。
            后天有个deadline，还需要再努力一把。
            """,
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        ),
        
        // 4. 开心日常
        SampleEntry(
            id: UUID(),
            title: "开心的一天",
            content: """
            今天心情超好！和朋友约了周六下午2点一起喝下午茶。
            中午点了最爱的寿司外卖，吃得很满足。
            下班后去健身房锻炼了1小时，这是连续运动的第7天了！
            感觉最近状态越来越好了。
            """,
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        ),
        
        // 5. 学习成长
        SampleEntry(
            id: UUID(),
            title: "学习Swift",
            content: """
            今天学习了SwiftUI的动画效果，实现了一个很酷的翻页动画！
            每天学习1小时编程已经坚持10天了，感觉进步很大。
            下周一晚上8点有一个线上技术分享会要参加。
            希望能学到更多实用的技巧。
            """,
            date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        ),
        
        // 6. 周末计划
        SampleEntry(
            id: UUID(),
            title: "周末安排",
            content: """
            终于到周五啦！这周真的太累了。
            周六早上10点约了牙医检查牙齿。
            周日下午打算和家人一起去公园野餐。
            晚上复习一下下周一的presentation内容。
            """,
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        ),
        
        // 7. 阅读习惯
        SampleEntry(
            id: UUID(),
            title: "读完一本书",
            content: """
            今天终于读完了《原子习惯》，感触很深！
            每天睡前阅读30分钟的习惯已经坚持了14天。
            决定开始实践书中的方法，每天写日记就是第一步。
            明天去图书馆借下一本书看。
            """,
            date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        ),
        
        // 8. 社交日程
        SampleEntry(
            id: UUID(),
            title: "朋友聚会",
            content: """
            今天和大学室友们聚餐，聊了好多往事，笑得肚子都疼了。
            约好了下个月15号再聚一次，这次换我请客。
            回家路上买了杯奶茶，心情美美的。
            晚上早睡，已经连续一周11点前入睡了。
            """,
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        ),
        
        // 9. 工作日程
        SampleEntry(
            id: UUID(),
            title: "项目进展",
            content: """
            项目终于进入了测试阶段！
            明天下午2点有个评审会议，需要准备demo演示。
            周三上午和客户有电话会议，要确认需求细节。
            最近每天冥想5分钟帮助我保持专注，这是第4天了。
            """,
            date: Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        ),
        
        // 10. 综合日记
        SampleEntry(
            id: UUID(),
            title: "充实的一天",
            content: """
            今天真是充实的一天！
            早上6点起床晨跑（连续早起第8天），然后准备了健康早餐。
            上午处理了几个紧急邮件，下午参加了团队培训。
            明天上午11点有个1对1的绩效谈话，有点紧张但也期待。
            晚上继续我的阅读习惯，今天读了《深度工作》的第三章。
            睡前写日记，记录这美好的一天。感恩！
            """,
            date: Calendar.current.date(byAdding: .day, value: -9, to: Date())!
        ),
        
        // 11. 反复出现的咖啡习惯 + 人物
        SampleEntry(
            id: UUID(),
            title: "和小李的下午",
            content: """
            今天下午和小李去了那家新开的咖啡馆，点了一杯拿铁。
            我真的好喜欢喝咖啡，每天至少一杯。
            小李最近在准备考研，聊了很多他的学习计划。
            回来的路上买了一本新的心理学书籍，准备晚上翻翻。
            """,
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        ),
        
        // 12. 失眠 + 焦虑
        SampleEntry(
            id: UUID(),
            title: "又失眠了",
            content: """
            昨晚又失眠到凌晨2点，翻来覆去睡不着。
            脑子里一直在想下周的答辩，紧张得不行。
            今天上课完全没精神，中午趴在桌上睡了一觉才好一点。
            晚上喝了杯热牛奶，希望今晚能早点入睡。
            """,
            date: Calendar.current.date(byAdding: .day, value: -11, to: Date())!
        ),
        
        // 13. 跑步习惯加强
        SampleEntry(
            id: UUID(),
            title: "跑步新记录",
            content: """
            今天跑步跑了5公里，破了自己的记录！太开心了！
            坚持每天跑步已经快两周了，感觉体力明显好了很多。
            跑完去吃了一碗牛肉面犒劳自己。
            妈妈打电话过来关心我，叮嘱我注意身体不要太拼。
            """,
            date: Calendar.current.date(byAdding: .day, value: -12, to: Date())!
        ),
        
        // 14. 社交压力
        SampleEntry(
            id: UUID(),
            title: "社交恐惧发作",
            content: """
            今天参加了一个不太熟的聚会，全程都很紧张。
            不知道该说什么，感觉自己格格不入。
            回来之后一个人宅在宿舍看了两集综艺才放松下来。
            我真的不擅长社交啊，有点担心以后工作面试怎么办。
            """,
            date: Calendar.current.date(byAdding: .day, value: -13, to: Date())!
        ),
        
        // 15. 妈妈 + 温暖
        SampleEntry(
            id: UUID(),
            title: "收到妈妈的包裹",
            content: """
            今天收到妈妈寄来的包裹，里面有我最爱吃的自制饼干和一封手写信。
            看完信有点想哭，妈妈说让我好好吃饭别老点外卖。
            晚上自己做了一顿简单的晚餐，番茄炒蛋和米饭。
            吃着妈妈做的饼干，觉得好幸福。
            """,
            date: Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        ),
        
        // 16. 编程学习 + 咖啡
        SampleEntry(
            id: UUID(),
            title: "码了一天代码",
            content: """
            今天写了一整天代码，实现了一个很复杂的功能，成就感满满。
            中间休息的时候冲了一杯手冲咖啡，好喝到飞起。
            每天学习编程这个习惯真的给我带来了很大的成长。
            小王给我推荐了一个新的开源框架，明天研究一下。
            """,
            date: Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        ),
        
        // 17. 期中考试压力
        SampleEntry(
            id: UUID(),
            title: "压力好大",
            content: """
            还有一周就期中考试了，感觉好多东西都没复习完。
            今天在图书馆待了8个小时，但效率并不高。
            焦虑让我根本静不下心来，看着书发呆。
            和小李互相鼓励了一下，约好明天一起图书馆学习。
            """,
            date: Calendar.current.date(byAdding: .day, value: -16, to: Date())!
        ),
        
        // 18. 运动 + 好心情
        SampleEntry(
            id: UUID(),
            title: "打了一场篮球",
            content: """
            下午和同学打了两个小时篮球，太爽了！
            运动真的是最好的解压方式，打完球感觉所有烦恼都消失了。
            晚上和室友一起吃了火锅，边吃边聊，一晚上都在笑。
            快乐就是这么简单呀！
            """,
            date: Calendar.current.date(byAdding: .day, value: -17, to: Date())!
        ),
        
        // 19. 阅读 + 反思
        SampleEntry(
            id: UUID(),
            title: "读《被讨厌的勇气》",
            content: """
            今天开始读《被讨厌的勇气》，第一章就被击中了。
            \"一切烦恼都来自人际关系\"，这句话让我想了很久。
            每天阅读的习惯让我看到了很多不同的视角。
            希望自己能慢慢学会不那么在意别人的眼光。
            """,
            date: Calendar.current.date(byAdding: .day, value: -18, to: Date())!
        ),
        
        // 20. 里程碑
        SampleEntry(
            id: UUID(),
            title: "拿到了实习offer！",
            content: """
            天哪天哪天哪！！！我拿到了xx公司的暑期实习offer！！！
            面了三轮终于通过了，打电话告诉妈妈的时候她比我还激动。
            小李和小王都发来祝贺，今晚一起出去庆祝。
            这段时间的努力终于有了回报，我要哭了😭
            感谢每一天的坚持，编程、阅读、跑步，都让我成为更好的自己。
            """,
            date: Calendar.current.date(byAdding: .day, value: -19, to: Date())!
        )
    ]
}
