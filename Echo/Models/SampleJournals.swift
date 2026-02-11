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
        )
    ]
}
