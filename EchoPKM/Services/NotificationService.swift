import Foundation
import UserNotifications

/// Smart care notification service - triggers on app foreground
@Observable @MainActor
final class NotificationService: NSObject {
    
    private(set) var isAuthorized = false
    private var lastNotificationDate: Date?
    
    /// Demo mode: always trigger a notification on foreground
    var isDemoMode = true
    
    /// Minimum interval between notifications (avoid spamming)
    private let minimumInterval: TimeInterval = 30 // Demo: 30 seconds
    
    // MARK: - Permission
    
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            
            if granted {
                // Allow notifications to show when app is in foreground
                center.delegate = self
            }
            print("[Notification] Authorization: \(granted ? "granted" : "denied")")
        } catch {
            print("[Notification] Authorization error: \(error)")
            isAuthorized = false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        if isAuthorized {
            UNUserNotificationCenter.current().delegate = self
        }
    }
    
    // MARK: - Smart Care Notification
    
    /// Check and send smart care notification on app foreground
    func checkAndSendSmartCare(
        entries: [DiaryEntry],
        habits: [HabitEntry],
        schedules: [ScheduleItem]
    ) {
        guard isAuthorized else {
            print("[Notification] Not authorized, skipping")
            return
        }
        
        // Check minimum interval
        if let lastDate = lastNotificationDate,
           Date().timeIntervalSince(lastDate) < minimumInterval {
            print("[Notification] Too soon since last notification, skipping")
            return
        }
        
        // Generate smart care content
        let care: SmartCareContent
        if isDemoMode {
            // Demo mode: always generate a notification
            care = generateDemoCare(entries: entries, habits: habits, schedules: schedules)
        } else {
            guard let c = generateSmartCare(entries: entries, habits: habits, schedules: schedules) else {
                return
            }
            care = c
        }
        
        // Send notification
        sendLocalNotification(care: care)
        lastNotificationDate = Date()
    }
    
    // MARK: - Generate Demo Care Content
    
    private func generateDemoCare(
        entries: [DiaryEntry],
        habits: [HabitEntry],
        schedules: [ScheduleItem]
    ) -> SmartCareContent {
        // Try to generate based on actual data first
        if let realCare = generateSmartCare(entries: entries, habits: habits, schedules: schedules) {
            return realCare
        }
        
        // Fallback: random demo notifications
        let demoNotifications: [SmartCareContent] = [
            SmartCareContent(
                type: .welcome,
                title: "你好呀～",
                body: "我是你的企鹅朋友，想聊聊今天发生了什么吗？",
                emoji: "sparkles"
            ),
            SmartCareContent(
                type: .morningGreeting,
                title: "欢迎回来",
                body: "见到你真开心！有什么想和我说的吗？",
                emoji: "hand.wave.fill"
            ),
            SmartCareContent(
                type: .eveningGreeting,
                title: "今天过得怎么样？",
                body: "无论好坏，我都在这里陪你～",
                emoji: "heart.fill"
            ),
            SmartCareContent(
                type: .topicFollowUp,
                title: "想你了",
                body: "来和我聊聊天吧！",
                emoji: "bubble.left.fill"
            )
        ]
        
        return demoNotifications.randomElement()!
    }
    
    // MARK: - Generate Smart Care Content
    
    private func generateSmartCare(
        entries: [DiaryEntry],
        habits: [HabitEntry],
        schedules: [ScheduleItem]
    ) -> SmartCareContent? {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Priority 1: Low mood care (recent 3 entries avg mood <= 2)
        let recentMoods = entries.prefix(3).compactMap(\.moodScore)
        if recentMoods.count >= 2 {
            let avg = Double(recentMoods.reduce(0, +)) / Double(recentMoods.count)
            if avg <= 2.0 {
                return SmartCareContent(
                    type: .lowMood,
                    title: "在吗？",
                    body: "最近似乎不太容易，随时可以和我聊聊呀～",
                    emoji: "heart.fill"
                )
            }
        }
        
        // Priority 2: Haven't journaled for 2+ days (lowered for demo)
        if let lastEntry = entries.first {
            let daysSinceLastEntry = calendar.dateComponents([.day], from: lastEntry.createdAt, to: now).day ?? 0
            if daysSinceLastEntry >= 2 {
                return SmartCareContent(
                    type: .missYou,
                    title: "好久不见",
                    body: "已经\(daysSinceLastEntry)天没聊了，最近过得怎么样？",
                    emoji: "hand.wave.fill"
                )
            }
        }
        
        // Priority 3: Habit streak celebration (2+ days this week for demo)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let thisWeekHabits = habits.filter { $0.date >= weekStart }
        var habitDays: [String: Set<Int>] = [:]
        for h in thisWeekHabits {
            let dayOfWeek = calendar.component(.weekday, from: h.date)
            habitDays[h.name, default: []].insert(dayOfWeek)
        }
        if let (name, days) = habitDays.first(where: { $0.value.count >= 2 }) {
            return SmartCareContent(
                type: .habitStreak,
                title: "太棒了！",
                body: "\(name.capitalized) 这周已经坚持\(days.count)天了！",
                emoji: "flame.fill"
            )
        }
        
        // Priority 4: Yesterday's topic follow-up
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let yesterdayEntries = entries.filter { calendar.isDate($0.createdAt, inSameDayAs: yesterday) }
        if let lastEntry = yesterdayEntries.first, !lastEntry.topics.isEmpty {
            let topic = lastEntry.topics.first ?? ""
            return SmartCareContent(
                type: .topicFollowUp,
                title: "想起你说的",
                body: "昨天提到了\(topic)，今天怎么样了？",
                emoji: "bubble.left.fill"
            )
        }
        
        // Priority 5: Today's schedule reminder
        let todaySchedules = schedules.filter { !$0.isCompleted && calendar.isDate($0.date, inSameDayAs: today) }
        if let schedule = todaySchedules.first {
            let timeStr = schedule.date.formatted(date: .omitted, time: .shortened)
            return SmartCareContent(
                type: .scheduleReminder,
                title: "今日日程提醒",
                body: "\(timeStr) - \(schedule.title)",
                emoji: "calendar"
            )
        }
        
        // Priority 6: Time-based greeting
        let hour = calendar.component(.hour, from: now)
        if hour >= 6 && hour < 11 {
            return SmartCareContent(
                type: .morningGreeting,
                title: "早上好",
                body: "新的一天开始了，今天有什么计划吗？",
                emoji: "sun.max.fill"
            )
        } else if hour >= 11 && hour < 14 {
            return SmartCareContent(
                type: .afternoonGreeting,
                title: "中午好",
                body: "别忘了吃午饭哦～",
                emoji: "fork.knife"
            )
        } else if hour >= 18 && hour < 23 {
            return SmartCareContent(
                type: .eveningGreeting,
                title: "晚上好",
                body: "今天过得怎么样？想聊聊吗？",
                emoji: "moon.stars.fill"
            )
        }
        
        return nil
    }
    
    // MARK: - Send Local Notification
    
    private func sendLocalNotification(care: SmartCareContent) {
        let content = UNMutableNotificationContent()
        content.title = care.title
        content.body = care.body
        content.sound = .default
        content.categoryIdentifier = "SMART_CARE"
        content.userInfo = ["type": "\(care.type)"]
        
        // Trigger after 1 second (gives time for app to fully launch)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "smart-care-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notification] Failed to send: \(error)")
            } else {
                print("[Notification] Sent: \(care.type) - \(care.title): \(care.body)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Show notification even when app is in foreground (like WeChat)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even in foreground
        completionHandler([.banner, .sound])
    }
    
    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // User tapped the notification - app is already open
        print("[Notification] User tapped notification")
        completionHandler()
    }
}

// MARK: - Smart Care Content

struct SmartCareContent {
    let type: SmartCareType
    let title: String
    let body: String
    let emoji: String
    
    enum SmartCareType {
        case lowMood
        case missYou
        case welcome
        case habitStreak
        case topicFollowUp
        case morningGreeting
        case afternoonGreeting
        case eveningGreeting
        case scheduleReminder
    }
}
