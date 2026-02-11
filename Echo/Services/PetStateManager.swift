import SwiftUI
import SwiftData

/// 宠物状态管理器 - 跨页面共享
@Observable @MainActor
final class PetStateManager {
    static let shared = PetStateManager()
    
    // MARK: - 基础状态
    var energy: Double = 12
    var maxEnergy: Double = 20
    var affection: Int = 3
    var level: Int = 1
    
    // MARK: - 宠物心情
    var mood: PetMood = .neutral
    var moodMessage: String = "今天感觉不错~"
    
    // MARK: - 气泡动态内容
    var moodBubbleText: String = "今天心情如何？"
    var hugBubbleText: String = "我一直在这里"
    var scheduleBubbleText: String = "暂无日程提醒"
    var growthBubbleText: String = "和我聊天获得能量"
    
    // MARK: - 宠物动画状态
    var currentAnimation: PetAnimation = .idle
    
    // MARK: - 喂养状态
    var lastFeedTime: Date?
    var showFeedingSuccess = false
    var feedingMessage = ""
    
    // MARK: - 最近日记内容
    var lastJournalContent: String = ""
    
    enum PetMood: String {
        case happy = "开心"
        case neutral = "平静"
        case tired = "疲惫"
        case excited = "兴奋"
        case shy = "害羞"
    }
    
    enum PetAnimation: String {
        case idle = "待机"
        case wingFlap = "摇翅膀"
        case shyLookDown = "害羞低头"
        case jump = "开心跳跃"
        case nod = "点头"
    }
    
    private init() {
        // 启动随机温暖话术定时器
        startHugBubbleTimer()
    }
    
    // MARK: - 喂养宠物
    func feed(journalContent: String) {
        lastJournalContent = journalContent
        let energyGain = min(5.0, maxEnergy - energy)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            energy += energyGain
        }
        
        // 检查升级
        if energy >= maxEnergy {
            levelUp()
        }
        
        // 分析心情并更新所有气泡
        analyzeAndUpdateBubbles(from: journalContent)
        
        // 记录时间
        lastFeedTime = Date()
        
        // 触发成功动画
        feedingMessage = "+\(Int(energyGain)) 能量"
        showFeedingSuccess = true
        
        // 触发宠物动画
        triggerAnimation(mood == .happy ? .wingFlap : .nod)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showFeedingSuccess = false
        }
    }
    
    // MARK: - 分析日记并更新气泡
    private func analyzeAndUpdateBubbles(from content: String) {
        // 情绪分析
        let positiveWords = ["开心", "高兴", "棒", "成功", "感谢", "爱", "幸福", "期待"]
        let negativeWords = ["累", "疲惫", "难", "焦虑", "压力", "烦", "失眠", "担心"]
        let excitedWords = ["太好了", "哇", "激动", "兴奋", "终于"]
        
        let positiveCount = positiveWords.filter { content.contains($0) }.count
        let negativeCount = negativeWords.filter { content.contains($0) }.count
        let excitedCount = excitedWords.filter { content.contains($0) }.count
        
        // 更新心情（快速本地判断，用于动画触发）
        if excitedCount > 0 {
            mood = .excited
        } else if positiveCount > negativeCount {
            mood = .happy
        } else if negativeCount > 0 {
            mood = .tired
        } else {
            mood = .neutral
        }
        
        // 更新成长气泡（这个保持本地计算）
        updateGrowthBubble()
        
        // 使用AI分析更新其他气泡内容
        Task {
            let contents = await AIBubbleAnalyzer.shared.analyzeJournal(content)
            moodBubbleText = contents.mood
            hugBubbleText = contents.hug
            scheduleBubbleText = contents.schedule
            // growth保持本地计算的进度信息
        }
    }
    
    // MARK: - 更新成长气泡
    private func updateGrowthBubble() {
        let remaining = maxEnergy - energy
        if remaining <= 5 {
            growthBubbleText = "再写一篇日记我就升级啦！🎉"
        } else if remaining <= 10 {
            growthBubbleText = "还差\(Int(remaining))点能量升级~"
        } else {
            growthBubbleText = "Lv.\(level) → Lv.\(level+1) 进行中"
        }
    }
    
    // MARK: - 随机温暖话术
    private func startHugBubbleTimer() {
        let hugMessages = [
            "我一直在这里",
            "无论发生什么，我都陪着你",
            "你今天很棒哦~",
            "累了就休息一下吧",
            "想和你说：你很重要",
            "每一天都值得被记录",
            "谢谢你愿意和我分享"
        ]
        
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.hugBubbleText = hugMessages.randomElement() ?? "我一直在这里"
            }
        }
    }
    
    // MARK: - 触发动画
    func triggerAnimation(_ animation: PetAnimation) {
        currentAnimation = animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.currentAnimation = .idle
        }
    }
    
    // MARK: - 对话结束后奖励
    func onConversationEnd() {
        energy = min(maxEnergy, energy + 3)
        affection = min(5, affection + 1)
        triggerAnimation(.wingFlap)
        
        feedingMessage = "+3 能量 💬"
        showFeedingSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showFeedingSuccess = false
        }
    }
    
    private func levelUp() {
        level += 1
        affection = min(5, affection + 1)
        energy = 0
        maxEnergy += 5
        feedingMessage = "🎉 升级了！Lv.\(level)"
        triggerAnimation(.jump)
    }
}
