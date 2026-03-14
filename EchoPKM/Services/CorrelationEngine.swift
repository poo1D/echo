import Foundation
import Accelerate

/// vDSP-accelerated Pearson correlation engine for cross-modal health-mood analysis.
struct CorrelationEngine {

    // MARK: - Correlation Result

    struct Correlation {
        let type: CorrelationType
        let coefficient: Double     // Pearson r
        let description: String
        let sampleCount: Int

        enum CorrelationType: String {
            case sleepMood = "睡眠-心情"
            case exerciseMood = "运动-心情"
            case stepsMood = "步数-心情"
        }
    }

    // MARK: - Analyze

    /// Compute correlations between health metrics and mood scores.
    /// Only returns results with |r| > 0.3 and sample count >= 5.
    static func analyze(
        entries: [EntryMoodData],
        healthData: HealthSnapshot
    ) -> [Correlation] {
        var correlations: [Correlation] = []

        // Sleep ↔ Mood
        if let sleepCorr = computeSleepMoodCorrelation(entries: entries, weeklySleep: healthData.weeklySleep) {
            correlations.append(sleepCorr)
        }

        // Steps ↔ Mood
        if let stepCorr = computeStepsMoodCorrelation(entries: entries, weeklySteps: healthData.weeklySteps) {
            correlations.append(stepCorr)
        }

        return correlations
    }

    // MARK: - Entry Mood Data (lightweight projection)

    struct EntryMoodData {
        let date: Date
        let moodScore: Int
    }

    // MARK: - Sleep ↔ Mood Correlation

    private static func computeSleepMoodCorrelation(
        entries: [EntryMoodData],
        weeklySleep: [(date: Date, hours: Double)]
    ) -> Correlation? {
        let calendar = Calendar.current
        var sleepValues: [Double] = []
        var moodValues: [Double] = []

        for sleepDay in weeklySleep {
            let dayStart = calendar.startOfDay(for: sleepDay.date)
            let dayEntries = entries.filter { calendar.startOfDay(for: $0.date) == dayStart }
            if let avgMood = averageMood(dayEntries), sleepDay.hours > 0 {
                sleepValues.append(sleepDay.hours)
                moodValues.append(avgMood)
            }
        }

        guard sleepValues.count >= 5 else { return nil }

        let r = pearsonCorrelation(x: sleepValues, y: moodValues)
        guard abs(r) > 0.3 else { return nil }

        // Compute group averages for description
        let goodSleepMoods = zip(sleepValues, moodValues).filter { $0.0 >= 7 }.map(\.1)
        let poorSleepMoods = zip(sleepValues, moodValues).filter { $0.0 < 6 }.map(\.1)

        let goodAvg = goodSleepMoods.isEmpty ? 0 : goodSleepMoods.reduce(0, +) / Double(goodSleepMoods.count)
        let poorAvg = poorSleepMoods.isEmpty ? 0 : poorSleepMoods.reduce(0, +) / Double(poorSleepMoods.count)

        let description: String
        if !goodSleepMoods.isEmpty && !poorSleepMoods.isEmpty {
            description = "睡眠>7h天: 心情均值\(String(format: "%.1f", goodAvg)); 睡眠<6h天: 心情均值\(String(format: "%.1f", poorAvg)) (r=\(String(format: "%.2f", r)))"
        } else {
            description = "睡眠时长与心情关联系数 r=\(String(format: "%.2f", r))"
        }

        return Correlation(
            type: .sleepMood,
            coefficient: r,
            description: description,
            sampleCount: sleepValues.count
        )
    }

    // MARK: - Steps ↔ Mood Correlation

    private static func computeStepsMoodCorrelation(
        entries: [EntryMoodData],
        weeklySteps: [(date: Date, steps: Int)]
    ) -> Correlation? {
        let calendar = Calendar.current
        var stepValues: [Double] = []
        var moodValues: [Double] = []

        for stepDay in weeklySteps {
            let dayStart = calendar.startOfDay(for: stepDay.date)
            let dayEntries = entries.filter { calendar.startOfDay(for: $0.date) == dayStart }
            if let avgMood = averageMood(dayEntries), stepDay.steps > 0 {
                stepValues.append(Double(stepDay.steps))
                moodValues.append(avgMood)
            }
        }

        guard stepValues.count >= 5 else { return nil }

        let r = pearsonCorrelation(x: stepValues, y: moodValues)
        guard abs(r) > 0.3 else { return nil }

        // Active vs inactive comparison
        let activeThreshold = 8000.0
        let activeMoods = zip(stepValues, moodValues).filter { $0.0 >= activeThreshold }.map(\.1)
        let inactiveMoods = zip(stepValues, moodValues).filter { $0.0 < activeThreshold }.map(\.1)

        let activeAvg = activeMoods.isEmpty ? 0 : activeMoods.reduce(0, +) / Double(activeMoods.count)
        let inactiveAvg = inactiveMoods.isEmpty ? 0 : inactiveMoods.reduce(0, +) / Double(inactiveMoods.count)

        let description: String
        if !activeMoods.isEmpty && !inactiveMoods.isEmpty {
            let diff = activeAvg - inactiveAvg
            description = "运动日心情平均\(String(format: "%.1f", activeAvg))分，非运动日\(String(format: "%.1f", inactiveAvg))分，高\(String(format: "%.1f", diff))分 (r=\(String(format: "%.2f", r)))"
        } else {
            description = "步数与心情关联系数 r=\(String(format: "%.2f", r))"
        }

        return Correlation(
            type: .stepsMood,
            coefficient: r,
            description: description,
            sampleCount: stepValues.count
        )
    }

    // MARK: - vDSP-accelerated Pearson Correlation

    /// Computes Pearson correlation coefficient using vDSP for SIMD acceleration.
    static func pearsonCorrelation(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count >= 2 else { return 0 }

        let n = x.count
        let nd = Double(n)

        // Mean
        var meanX: Double = 0, meanY: Double = 0
        vDSP_meanvD(x, 1, &meanX, vDSP_Length(n))
        vDSP_meanvD(y, 1, &meanY, vDSP_Length(n))

        // Deviations from mean
        var devX = [Double](repeating: 0, count: n)
        var devY = [Double](repeating: 0, count: n)
        var negMeanX = -meanX
        var negMeanY = -meanY
        vDSP_vsaddD(x, 1, &negMeanX, &devX, 1, vDSP_Length(n))
        vDSP_vsaddD(y, 1, &negMeanY, &devY, 1, vDSP_Length(n))

        // Dot products
        var dotXY: Double = 0
        var dotXX: Double = 0
        var dotYY: Double = 0
        vDSP_dotprD(devX, 1, devY, 1, &dotXY, vDSP_Length(n))
        vDSP_dotprD(devX, 1, devX, 1, &dotXX, vDSP_Length(n))
        vDSP_dotprD(devY, 1, devY, 1, &dotYY, vDSP_Length(n))

        let denominator = sqrt(dotXX * dotYY)
        guard denominator > 0 else { return 0 }

        return dotXY / denominator
    }

    // MARK: - Helpers

    private static func averageMood(_ entries: [EntryMoodData]) -> Double? {
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0) { $0 + $1.moodScore }
        return Double(total) / Double(entries.count)
    }
}
