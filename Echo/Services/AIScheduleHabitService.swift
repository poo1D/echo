import Foundation

/// AI日程和习惯提取服务
@Observable @MainActor
final class AIScheduleHabitService {
    static let shared = AIScheduleHabitService()
    
    private let apiEndpoint = APIConfig.apiEndpoint
    private var apiKey: String { APIConfig.apiKey }
    private let modelId = "moonshotai/Kimi-K2.5"
    
    var isProcessing = false
    
    // 提取结果缓存
    var extractedSchedules: [ScheduleItem] = []
    var extractedHabits: [HabitItem] = []
    var echoResponses: [EchoResponse] = []
    
    private init() {}
    
    // MARK: - 处理日记内容
    func processJournalEntry(_ content: String, entryId: UUID = UUID(), entryDate: Date = Date()) async {
        guard !content.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = """
        你是Echo，一个温暖的情感陪伴生命体。请分析以下日记内容，提取日程和习惯信息。

        日记内容：
        \(content)

        请返回严格的JSON格式（不要有其他文字）：
        {
            "schedules": [
                {
                    "title": "事件名称，如'早会'、'约会'",
                    "datetime": "ISO8601格式时间，如'2026-02-09T09:00:00'，如果只有相对时间如'明天'请转换",
                    "reminder": "Echo的提醒语，如'明天有早会，我陪你准备！'"
                }
            ],
            "habits": [
                {
                    "name": "习惯名称，如'早睡'、'运动'、'阅读'",
                    "detected": true,
                    "streak": 3,
                    "feedback": "Echo的习惯反馈，如'你连续3天早睡，我好开心，翅膀变亮了！'"
                }
            ],
            "emotional_response": "情感陪伴回应，根据日记情绪给出温暖回应，如'今天看起来有点累呢，我陪你~'"
        }

        注意：
        1. 日程：识别任何时间+事件的组合，包括"明天早上"、"下周一"、"3点"等
        2. 习惯：识别规律性行为，特别是"连续X天"、"每天"、"坚持"等关键词
        3. 如果没有检测到日程或习惯，对应数组返回空[]
        4. 今天日期是：\(ISO8601DateFormatter().string(from: Date()))
        """
        
        do {
            let response = try await callAPI(prompt: prompt)
            parseAndStoreResults(from: response, entryId: entryId)
            print("✅ [AIScheduleHabitService] 解析完成 - 日程:\(extractedSchedules.count) 习惯:\(extractedHabits.count)")
        } catch {
            print("❌ [AIScheduleHabitService] AI处理失败: \(error)")
            // API失败时使用本地模拟分析
            await fallbackLocalAnalysis(content: content, entryId: entryId)
        }
    }
    
    // MARK: - 本地模拟分析（API失败时的备用方案）
    private func fallbackLocalAnalysis(content: String, entryId: UUID) async {
        print("🔄 [AIScheduleHabitService] 使用本地分析作为备用...")
        
        // 简单的关键词匹配
        let scheduleKeywords = ["明天", "后天", "下周", "点", "会议", "约会", "开会"]
        let habitKeywords = ["连续", "坚持", "每天", "早起", "运动", "阅读", "健身"]
        
        // 检测日程
        for keyword in scheduleKeywords {
            if content.contains(keyword) {
                let schedule = ScheduleItem(
                    id: UUID(),
                    title: "检测到日程",
                    dateTime: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                    reminder: "Echo发现了你的日程安排~记得准备哦！",
                    isCompleted: false,
                    sourceEntryId: entryId
                )
                extractedSchedules.append(schedule)
                break
            }
        }
        
        // 检测习惯
        for keyword in habitKeywords {
            if content.contains(keyword) {
                let habit = HabitItem(
                    id: UUID(),
                    name: keyword,
                    streak: 3,
                    feedback: "Echo看到你在坚持\(keyword)，真棒！继续加油~",
                    lastUpdated: Date()
                )
                extractedHabits.append(habit)
            }
        }
        
        print("📊 [本地分析] 日程:\(extractedSchedules.count) 习惯:\(extractedHabits.count)")
    }
    
    // MARK: - 批量处理示例日记
    func processSampleJournals() async {
        let sampleJournals = SampleJournals.entries
        
        for (index, journal) in sampleJournals.enumerated() {
            print("处理日记 \(index + 1)/\(sampleJournals.count): \(journal.title)")
            await processJournalEntry(journal.content, entryId: journal.id, entryDate: journal.date)
            
            // 添加延迟避免请求过快
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
    }
    
    // MARK: - API调用
    private func callAPI(prompt: String) async throws -> String {
        guard let url = URL(string: apiEndpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15 // 15秒超时
        
        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🔄 [AIScheduleHabitService] 开始调用API...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 [AIScheduleHabitService] HTTP状态码: \(httpResponse.statusCode)")
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            print("✅ [AIScheduleHabitService] API返回成功，内容长度: \(content.count)")
            return content
        }
        
        // 打印原始响应帮助调试
        if let rawString = String(data: data, encoding: .utf8) {
            print("❌ [AIScheduleHabitService] 解析失败，原始响应: \(rawString.prefix(500))")
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    // MARK: - 解析结果
    private func parseAndStoreResults(from response: String, entryId: UUID) {
        var jsonString = response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            jsonString = String(response[startIndex...endIndex])
        }
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("JSON解析失败: \(response)")
            return
        }
        
        // 解析日程
        if let schedules = json["schedules"] as? [[String: Any]] {
            for schedule in schedules {
                if let title = schedule["title"] as? String,
                   let datetimeStr = schedule["datetime"] as? String,
                   let reminder = schedule["reminder"] as? String {
                    
                    let formatter = ISO8601DateFormatter()
                    let datetime = formatter.date(from: datetimeStr) ?? Date()
                    
                    let item = ScheduleItem(
                        id: UUID(),
                        title: title,
                        dateTime: datetime,
                        reminder: reminder,
                        isCompleted: false,
                        sourceEntryId: entryId
                    )
                    extractedSchedules.append(item)
                }
            }
        }
        
        // 解析习惯
        if let habits = json["habits"] as? [[String: Any]] {
            for habit in habits {
                if let name = habit["name"] as? String,
                   let feedback = habit["feedback"] as? String {
                    let streak = habit["streak"] as? Int ?? 1
                    
                    let item = HabitItem(
                        id: UUID(),
                        name: name,
                        streak: streak,
                        feedback: feedback,
                        lastUpdated: Date()
                    )
                    extractedHabits.append(item)
                }
            }
        }
        
        // 解析情感回应
        if let emotionalResponse = json["emotional_response"] as? String {
            let response = EchoResponse(
                id: UUID(),
                content: emotionalResponse,
                type: .emotional,
                createdAt: Date()
            )
            echoResponses.append(response)
        }
    }
    
    // MARK: - 清空缓存
    func clearCache() {
        extractedSchedules.removeAll()
        extractedHabits.removeAll()
        echoResponses.removeAll()
    }
}

// MARK: - 数据模型

struct ScheduleItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let dateTime: Date
    let reminder: String
    var isCompleted: Bool
    let sourceEntryId: UUID
    
    var isUpcoming: Bool {
        dateTime > Date()
    }
    
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: dateTime)
    }
}

struct HabitItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let streak: Int
    let feedback: String
    let lastUpdated: Date
    
    var streakEmoji: String {
        switch streak {
        case 1...3: return "🌱"
        case 4...6: return "🌿"
        case 7...13: return "🌳"
        case 14...: return "🌟"
        default: return "🌱"
        }
    }
}

struct EchoResponse: Identifiable, Codable {
    let id: UUID
    let content: String
    let type: ResponseType
    let createdAt: Date
    
    enum ResponseType: String, Codable {
        case emotional = "emotional"
        case schedule = "schedule"
        case habit = "habit"
    }
}
