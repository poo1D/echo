import Foundation
import HealthKit

/// Reads health data from HealthKit (steps, sleep, workouts) and generates local insights.
@Observable @MainActor
final class HealthKitService {

    var isAuthorized = false
    var useMockData = false

    private let healthStore: HKHealthStore?
    private var cachedSnapshot: HealthSnapshot?
    private var cacheDate: Date?

    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    init() {
        if Self.isPreview || !HKHealthStore.isHealthDataAvailable() {
            self.healthStore = nil
            self.useMockData = true
            self.isAuthorized = true
        } else {
            self.healthStore = HKHealthStore()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard !useMockData, let healthStore else {
            useMockData = true
            isAuthorized = true
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            useMockData = true
            isAuthorized = true
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            print("HealthKit authorization failed: \(error)")
            useMockData = true
            isAuthorized = true
        }
    }

    // MARK: - Fetch Today's Steps

    func fetchTodaySteps() async -> Int {
        if useMockData { return mockTodaySteps() }
        guard let healthStore else { return mockTodaySteps() }

        let stepType = HKQuantityType(.stepCount)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let steps = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Sleep Data

    func fetchSleepData(for date: Date) async -> Double {
        if useMockData { return mockSleepHours(for: date) }
        guard let healthStore else { return mockSleepHours(for: date) }

        let sleepType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }

                var totalSeconds: Double = 0
                for sample in samples {
                    let value = sample.value
                    // Count asleepCore, asleepDeep, asleepREM
                    if value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Weekly Trends

    func fetchWeeklyTrends() async -> (steps: [(date: Date, steps: Int)], sleep: [(date: Date, hours: Double)]) {
        if useMockData { return mockWeeklyTrends() }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!

        // Steps
        let weeklySteps = await fetchDailySteps(from: weekAgo, to: today)

        // Sleep
        var weeklySleep: [(date: Date, hours: Double)] = []
        for dayOffset in -6...0 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let hours = await fetchSleepData(for: date)
            weeklySleep.append((date: date, hours: hours))
        }

        return (steps: weeklySteps, sleep: weeklySleep)
    }

    private func fetchDailySteps(from startDate: Date, to endDate: Date) async -> [(date: Date, steps: Int)] {
        guard let healthStore else { return [] }

        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let interval = DateComponents(day: 1)
        let anchorDate = calendar.startOfDay(for: startDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: calendar.date(byAdding: .day, value: 1, to: endDate), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var dailySteps: [(date: Date, steps: Int)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let steps = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    dailySteps.append((date: stats.startDate, steps: steps))
                }
                continuation.resume(returning: dailySteps)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Recent Workouts

    func fetchRecentWorkouts(limit: Int = 5) async -> [(type: String, minutes: Int, date: Date)] {
        if useMockData { return mockWorkouts() }
        guard let healthStore else { return mockWorkouts() }

        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                let results = workouts.map { workout in
                    let typeName = Self.workoutTypeName(workout.workoutActivityType)
                    let minutes = Int(workout.duration / 60)
                    return (type: typeName, minutes: minutes, date: workout.startDate)
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Build Full Snapshot

    func buildSnapshot() async -> HealthSnapshot {
        // Cache for 5 minutes
        if let cached = cachedSnapshot, let cacheDate, Date().timeIntervalSince(cacheDate) < 300 {
            return cached
        }

        let steps = await fetchTodaySteps()
        let sleepHours = await fetchSleepData(for: Date())
        let trends = await fetchWeeklyTrends()
        let workouts = await fetchRecentWorkouts()

        let todayWorkoutMinutes = workouts
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.minutes }

        let insights = analyzeHealthTrends(
            weeklySleep: trends.sleep,
            weeklySteps: trends.steps,
            workoutMinutes: todayWorkoutMinutes
        )

        let snapshot = HealthSnapshot(
            steps: steps,
            sleepHours: sleepHours,
            sleepQuality: .init(hours: sleepHours),
            workoutMinutes: todayWorkoutMinutes,
            weeklySteps: trends.steps,
            weeklySleep: trends.sleep,
            insights: insights
        )

        cachedSnapshot = snapshot
        cacheDate = Date()
        return snapshot
    }

    // MARK: - Local Health Trend Analysis (no API)

    func analyzeHealthTrends(
        weeklySleep: [(date: Date, hours: Double)],
        weeklySteps: [(date: Date, steps: Int)],
        workoutMinutes: Int
    ) -> [HealthInsight] {
        var insights: [HealthInsight] = []

        // Check for consecutive poor sleep (last 3 nights < 6h)
        let recentSleep = weeklySleep.suffix(3)
        let poorSleepNights = recentSleep.filter { $0.hours > 0 && $0.hours < 6 }
        if poorSleepNights.count >= 3 {
            insights.append(HealthInsight(
                type: .sleepWarning,
                title: "睡眠不足预警",
                detail: "连续\(poorSleepNights.count)晚睡眠不足6小时，今天悠着点~"
            ))
        }

        // Exercise streak: 3+ days with workouts this week
        let activeDays = weeklySteps.filter { $0.steps > 5000 }.count
        if activeDays >= 3 {
            insights.append(HealthInsight(
                type: .exerciseStreak,
                title: "运动连续打卡",
                detail: "本周已有\(activeDays)天运动量达标，继续保持！"
            ))
        }

        // Sleep improving trend
        if weeklySleep.count >= 4 {
            let firstHalf = weeklySleep.prefix(weeklySleep.count / 2).map(\.hours)
            let secondHalf = weeklySleep.suffix(weeklySleep.count / 2).map(\.hours)
            let firstAvg = firstHalf.isEmpty ? 0 : firstHalf.reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.isEmpty ? 0 : secondHalf.reduce(0, +) / Double(secondHalf.count)
            if secondAvg > firstAvg + 0.5 {
                insights.append(HealthInsight(
                    type: .sleepImproving,
                    title: "睡眠改善中",
                    detail: "近几天睡眠时长有所增加，平均\(String(format: "%.1f", secondAvg))小时"
                ))
            }
        }

        // Step goal
        let avgSteps = weeklySteps.isEmpty ? 0 : weeklySteps.map(\.steps).reduce(0, +) / weeklySteps.count
        if avgSteps >= 8000 {
            insights.append(HealthInsight(
                type: .stepGoal,
                title: "步数达标",
                detail: "本周日均\(avgSteps)步，保持活力！"
            ))
        }

        return insights
    }

    // MARK: - Mock Data (Simulator)

    private func mockTodaySteps() -> Int {
        Int.random(in: 5000...12000)
    }

    private func mockSleepHours(for date: Date) -> Double {
        Double.random(in: 4.5...8.5)
    }

    private func mockWeeklyTrends() -> (steps: [(date: Date, steps: Int)], sleep: [(date: Date, hours: Double)]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let steps: [(date: Date, steps: Int)] = (-6...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return (date: date, steps: Int.random(in: 5000...12000))
        }

        let sleep: [(date: Date, hours: Double)] = (-6...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return (date: date, hours: Double.random(in: 4.5...8.5))
        }

        return (steps: steps, sleep: sleep)
    }

    private func mockWorkouts() -> [(type: String, minutes: Int, date: Date)] {
        let calendar = Calendar.current
        let today = Date()
        return [
            (type: "跑步", minutes: 30, date: today),
            (type: "瑜伽", minutes: 45, date: calendar.date(byAdding: .day, value: -1, to: today)!),
            (type: "力量训练", minutes: 40, date: calendar.date(byAdding: .day, value: -3, to: today)!)
        ]
    }

    private static func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "跑步"
        case .walking: return "步行"
        case .cycling: return "骑行"
        case .swimming: return "游泳"
        case .yoga: return "瑜伽"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "力量训练"
        case .hiking: return "徒步"
        case .dance: return "舞蹈"
        default: return "运动"
        }
    }
}
