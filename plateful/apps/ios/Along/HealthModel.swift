import Foundation

/// One civil day of HealthKit (or preview) samples. Missing values stay nil so
/// cheaper devices without wearables still render what they have.
struct HealthDay: Identifiable, Equatable {
    var dayKey: String
    var steps: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var restingHeartRate: Double?
    var hrvSDNN: Double?
    var sleepHours: Double?
    var weightKg: Double?
    var id: String { dayKey }
}

enum HealthAuthorization: Equatable {
    case unavailable
    case notDetermined
    case denied
    case sharing
}

enum HealthDataSource: Equatable {
    case healthKit
    case preview
}

struct HealthSnapshot: Equatable {
    var authorization: HealthAuthorization = .notDetermined
    var source: HealthDataSource = .preview
    var days: [HealthDay] = []
    var fetchedAt: Date = .distantPast

    var latest: HealthDay? { days.last }
    var hasAnyMetric: Bool {
        days.contains {
            $0.steps != nil || $0.activeEnergyKcal != nil || $0.exerciseMinutes != nil
                || $0.restingHeartRate != nil || $0.hrvSDNN != nil || $0.sleepHours != nil || $0.weightKg != nil
        }
    }
}

/// Derived signals built from primary HealthKit samples. Tracking context only —
/// never diagnoses or medical advice.
struct HealthInsight: Equatable {
    var recoveryScore: Double?
    var activityScore: Double?
    var overallScore: Double?
    var headline: String
    var detail: String
    var currentLabel: String
    var projectedLabel: String
    var series: [HealthChartPoint]
    var projection: [HealthChartPoint]
}

struct HealthChartPoint: Identifiable, Equatable {
    enum Series: String, Equatable { case activity, recovery, sleep, projection }
    var dayKey: String
    var series: Series
    var value: Double
    var id: String { "\(series.rawValue)|\(dayKey)" }
}

enum HealthAnalytics {
    /// Build a goal-aware insight from the last `window` days of a snapshot.
    static func insight(from snapshot: HealthSnapshot, goals: Set<SetupGoal>,
                        window: Int = 30, todayKey: String) -> HealthInsight {
        let windowDays = Array(snapshot.days.suffix(max(7, window)))
        let recovery = windowDays.compactMap { day -> (String, Double)? in
            guard let score = recoveryScore(sleep: day.sleepHours, hrv: day.hrvSDNN, resting: day.restingHeartRate) else { return nil }
            return (day.dayKey, score)
        }
        let activity = windowDays.compactMap { day -> (String, Double)? in
            guard let score = activityScore(steps: day.steps, energy: day.activeEnergyKcal, exercise: day.exerciseMinutes) else { return nil }
            return (day.dayKey, score)
        }
        let sleep = windowDays.compactMap { day -> (String, Double)? in
            guard let hours = day.sleepHours else { return nil }
            return (day.dayKey, min(100, (hours / 8.0) * 100))
        }

        let recoveryNow = recovery.last?.1
        let activityNow = activity.last?.1
        let overall: Double? = {
            let parts = [recoveryNow, activityNow].compactMap { $0 }
            guard !parts.isEmpty else { return nil }
            return parts.reduce(0, +) / Double(parts.count)
        }()

        var series: [HealthChartPoint] = []
        series += activity.map { HealthChartPoint(dayKey: $0.0, series: .activity, value: $0.1) }
        series += recovery.map { HealthChartPoint(dayKey: $0.0, series: .recovery, value: $0.1) }
        series += sleep.map { HealthChartPoint(dayKey: $0.0, series: .sleep, value: $0.1) }

        let focus = focusSeries(goals: goals, activity: activity, recovery: recovery)
        let projected = project(focus.map(\.1), startKey: focus.last?.0 ?? todayKey, days: min(7, window / 4))
        let projectionPoints = projected.points.map { HealthChartPoint(dayKey: $0.0, series: .projection, value: $0.1) }

        let headline = statusHeadline(score: overall, goals: goals)
        let detail = statusDetail(score: overall, projected: projected.end, goals: goals, source: snapshot.source)
        let current = overall.map { "Now · \(Int($0.rounded()))" } ?? "Now · waiting on Health"
        let future = projected.end.map { "+\(projected.horizon)d · \(Int($0.rounded()))" } ?? "+\(projected.horizon)d · need more days"

        return HealthInsight(
            recoveryScore: recoveryNow,
            activityScore: activityNow,
            overallScore: overall,
            headline: headline,
            detail: detail,
            currentLabel: current,
            projectedLabel: future,
            series: series,
            projection: projectionPoints
        )
    }

    /// Recovery index 0…100 from sleep hours, HRV (ms) and resting HR (bpm).
    static func recoveryScore(sleep: Double?, hrv: Double?, resting: Double?) -> Double? {
        var parts: [Double] = []
        if let sleep { parts.append(clamp((sleep / 8.0) * 100)) }
        if let hrv { parts.append(clamp((hrv / 80.0) * 100)) }
        if let resting {
            // Lower resting HR within a common adult band reads as better recovery.
            parts.append(clamp((1.0 - ((resting - 50) / 40.0)) * 100))
        }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +) / Double(parts.count)
    }

    /// Activity index 0…100 from steps, active kcal and exercise minutes.
    static func activityScore(steps: Double?, energy: Double?, exercise: Double?) -> Double? {
        var parts: [Double] = []
        if let steps { parts.append(clamp((steps / 10_000.0) * 100)) }
        if let energy { parts.append(clamp((energy / 500.0) * 100)) }
        if let exercise { parts.append(clamp((exercise / 30.0) * 100)) }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +) / Double(parts.count)
    }

    /// Simple least-squares projection of the focus series. Returns future day keys.
    static func project(_ values: [Double], startKey: String, days: Int) -> (points: [(String, Double)], end: Double?, horizon: Int) {
        let horizon = max(1, days)
        guard values.count >= 3 else { return ([], nil, horizon) }
        let n = Double(values.count)
        let xs = values.indices.map(Double.init)
        let sumX = xs.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(xs, values).map(*).reduce(0, +)
        let sumXX = xs.map { $0 * $0 }.reduce(0, +)
        let denom = n * sumXX - sumX * sumX
        guard denom != 0 else { return ([], values.last, horizon) }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        var points: [(String, Double)] = []
        for offset in 1...horizon {
            let x = n - 1 + Double(offset)
            let y = clamp(intercept + slope * x)
            if let key = dayKey(startKey, adding: offset) {
                points.append((key, y))
            }
        }
        return (points, points.last?.1, horizon)
    }

    static func previewSnapshot(todayKey: String = DayIdentity.key(for: .now) ?? "2026-11-22", days: Int = 30) -> HealthSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let today = dayDate(todayKey) else {
            return HealthSnapshot(authorization: .sharing, source: .preview, days: [], fetchedAt: .now)
        }
        var result: [HealthDay] = []
        for offset in (1 - days)...0 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let key = dayKey(date) ?? todayKey
            let wave = sin(Double(offset) / 4.5)
            let weekend = calendar.isDateInWeekend(date)
            result.append(HealthDay(
                dayKey: key,
                steps: 7_200 + wave * 2_400 + (weekend ? -900 : 600),
                activeEnergyKcal: 380 + wave * 90 + (weekend ? -40 : 50),
                exerciseMinutes: 18 + wave * 10 + (weekend ? -6 : 8),
                restingHeartRate: 58 - wave * 3,
                hrvSDNN: 48 + wave * 12,
                sleepHours: 6.8 + wave * 0.9 + (weekend ? 0.6 : 0),
                weightKg: 78.4 - Double(offset + days) * 0.03 + wave * 0.15
            ))
        }
        return HealthSnapshot(authorization: .sharing, source: .preview, days: result, fetchedAt: .now)
    }

    // MARK: - Internals

    private static func focusSeries(goals: Set<SetupGoal>, activity: [(String, Double)], recovery: [(String, Double)])
        -> [(String, Double)] {
        if goals.contains(.weightLoss) || goals.contains(.muscle) || goals.contains(.energy) {
            return activity.isEmpty ? recovery : activity
        }
        if goals.contains(.recovery) || goals.contains(.longevity) || goals.contains(.skin) {
            return recovery.isEmpty ? activity : recovery
        }
        return activity.isEmpty ? recovery : activity
    }

    private static func statusHeadline(score: Double?, goals: Set<SetupGoal>) -> String {
        guard let score else { return "Waiting on Apple Health" }
        let focus: String
        if goals.contains(.weightLoss) { focus = "toward your weight goal" }
        else if goals.contains(.recovery) { focus = "on recovery" }
        else if goals.contains(.muscle) { focus = "on training load" }
        else if goals.contains(.energy) { focus = "on energy" }
        else if goals.contains(.longevity) { focus = "on longevity signals" }
        else if goals.contains(.skin) { focus = "on recovery & sleep" }
        else { focus = "across activity and recovery" }
        if score >= 75 { return "Strong \(focus)" }
        if score >= 55 { return "Steady \(focus)" }
        if score >= 35 { return "Soft \(focus)" }
        return "Quiet \(focus)"
    }

    private static func statusDetail(score: Double?, projected: Double?, goals: Set<SetupGoal>, source: HealthDataSource) -> String {
        if source == .preview {
            return "Showing a local preview until Apple Health is connected. Along never diagnoses — this is a read of your own samples."
        }
        guard let score else {
            return "Connect the metrics you already track. Wearables fill this in automatically; phones alone still contribute steps and energy."
        }
        if let projected {
            let delta = projected - score
            if abs(delta) < 3 {
                return "If the last \(goals.isEmpty ? "weeks" : "days") hold, your blended score stays roughly where it is now."
            }
            if delta > 0 {
                return "Trend from the recent window projects a lift of about \(Int(delta.rounded())) points if the pattern continues."
            }
            return "Trend from the recent window softens by about \(Int(abs(delta).rounded())) points if the pattern continues."
        }
        return "Log a few more days in Apple Health to project where this is heading."
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }

    private static func dayDate(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func dayKey(_ date: Date) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func dayKey(_ key: String, adding days: Int) -> String? {
        guard let date = dayDate(key) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let shifted = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
        return dayKey(shifted)
    }
}
