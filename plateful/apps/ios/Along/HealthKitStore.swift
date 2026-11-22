import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

/// Reads Apple Health samples for the Health tab. Never writes clinical claims —
/// only aggregates what the person already tracks on device / wearables.
@MainActor @Observable final class HealthKitStore {
    var snapshot = HealthSnapshot()
    var isLoading = false
    var message: String?

    private let arguments: [String]
    #if canImport(HealthKit)
    private let store: HKHealthStore?
    #endif

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.arguments = arguments
        #if canImport(HealthKit)
        self.store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
        #endif
        if arguments.contains("--ui-testing") || arguments.contains("--sample-journey") {
            snapshot = HealthAnalytics.previewSnapshot()
            message = nil
        }
    }

    var canRequestAccess: Bool {
        #if canImport(HealthKit)
        store != nil && snapshot.authorization != .unavailable
        #else
        false
        #endif
    }

    func refresh(days: Int = 30) async {
        if arguments.contains("--ui-testing") || arguments.contains("--sample-journey") {
            snapshot = HealthAnalytics.previewSnapshot()
            return
        }
        #if canImport(HealthKit)
        guard let store else {
            snapshot = HealthSnapshot(authorization: .unavailable, source: .preview,
                                      days: HealthAnalytics.previewSnapshot().days, fetchedAt: .now)
            message = "Apple Health isn’t available on this device. Showing a local preview."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let types = Self.readTypes
            if !types.isEmpty {
                try await store.requestAuthorization(toShare: [], read: types)
            }
            let auth = authorizationStatus(using: store)
            let days = try await fetchDays(store: store, count: days)
            if days.contains(where: hasMetric) {
                snapshot = HealthSnapshot(authorization: auth, source: .healthKit, days: days, fetchedAt: .now)
                message = nil
            } else {
                snapshot = HealthSnapshot(authorization: auth, source: .preview,
                                          days: HealthAnalytics.previewSnapshot().days, fetchedAt: .now)
                message = auth == .denied
                    ? "Health access is off. Enable it in Settings → Health → Data Access to replace this preview."
                    : "No recent Health samples yet. Preview stays until your wearables or phone log a few days."
            }
        } catch {
            snapshot = HealthSnapshot(authorization: .denied, source: .preview,
                                      days: HealthAnalytics.previewSnapshot().days, fetchedAt: .now)
            message = "Apple Health couldn’t be opened. Showing a local preview instead."
        }
        #else
        snapshot = HealthAnalytics.previewSnapshot()
        message = "HealthKit isn’t linked in this build."
        #endif
    }

    #if canImport(HealthKit)
    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let quantities: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .appleExerciseTime,
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .bodyMass, .oxygenSaturation, .respiratoryRate
        ]
        for id in quantities {
            if let type = HKObjectType.quantityType(forIdentifier: id) { types.insert(type) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        return types
    }

    private func authorizationStatus(using store: HKHealthStore) -> HealthAuthorization {
        guard let steps = HKObjectType.quantityType(forIdentifier: .stepCount) else { return .unavailable }
        switch store.authorizationStatus(for: steps) {
        case .sharingAuthorized, .sharingDenied:
            // Read auth isn’t fully exposed; treat any determined state as sharing attempt.
            return .sharing
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func fetchDays(store: HKHealthStore, count: Int) async throws -> [HealthDay] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(count - 1), to: end) else { return [] }

        async let steps = sumByDay(store, .stepCount, unit: .count(), start: start, end: end.addingTimeInterval(86_400))
        async let energy = sumByDay(store, .activeEnergyBurned, unit: .kilocalorie(), start: start, end: end.addingTimeInterval(86_400))
        async let exercise = sumByDay(store, .appleExerciseTime, unit: .minute(), start: start, end: end.addingTimeInterval(86_400))
        async let resting = averageByDay(store, .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end.addingTimeInterval(86_400))
        async let hrv = averageByDay(store, .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: end.addingTimeInterval(86_400))
        async let weight = averageByDay(store, .bodyMass, unit: .gramUnit(with: .kilo), start: start, end: end.addingTimeInterval(86_400))
        async let sleep = sleepHoursByDay(store, start: start, end: end.addingTimeInterval(86_400))

        let stepMap = try await steps
        let energyMap = try await energy
        let exerciseMap = try await exercise
        let restingMap = try await resting
        let hrvMap = try await hrv
        let weightMap = try await weight
        let sleepMap = try await sleep

        var days: [HealthDay] = []
        for offset in 0..<count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let key = DayIdentity.key(for: date) ?? ""
            days.append(HealthDay(
                dayKey: key,
                steps: stepMap[key],
                activeEnergyKcal: energyMap[key],
                exerciseMinutes: exerciseMap[key],
                restingHeartRate: restingMap[key],
                hrvSDNN: hrvMap[key],
                sleepHours: sleepMap[key],
                weightKg: weightMap[key]
            ))
        }
        return days
    }

    private func sumByDay(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, unit: HKUnit,
                          start: Date, end: Date) async throws -> [String: Double] {
        try await statisticsByDay(store, id, unit: unit, start: start, end: end, options: .cumulativeSum) { $0.sumQuantity() }
    }

    private func averageByDay(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, unit: HKUnit,
                              start: Date, end: Date) async throws -> [String: Double] {
        try await statisticsByDay(store, id, unit: unit, start: start, end: end, options: .discreteAverage) { $0.averageQuantity() }
    }

    private func statisticsByDay(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, unit: HKUnit,
                                 start: Date, end: Date, options: HKStatisticsOptions,
                                 pick: @escaping (HKStatistics) -> HKQuantity?) async throws -> [String: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [:] }
        let calendar = Calendar.current
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                options: options,
                anchorDate: calendar.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var map: [String: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end.addingTimeInterval(-1)) { stats, _ in
                    if let quantity = pick(stats), let key = DayIdentity.key(for: stats.startDate) {
                        map[key] = quantity.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: map)
            }
            store.execute(query)
        }
    }

    private func sleepHoursByDay(_ store: HKHealthStore, start: Date, end: Date) async throws -> [String: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var map: [String: Double] = [:]
                for sample in samples as? [HKCategorySample] ?? [] {
                    // Asleep stages (Core / Deep / REM / Unspecified). In-bed alone is ignored.
                    let asleep: Set<Int> = [
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    ]
                    guard asleep.contains(sample.value) else { continue }
                    let key = DayIdentity.key(for: sample.endDate) ?? ""
                    map[key, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
                }
                continuation.resume(returning: map)
            }
            store.execute(query)
        }
    }
    #endif

    private func hasMetric(_ day: HealthDay) -> Bool {
        day.steps != nil || day.activeEnergyKcal != nil || day.exerciseMinutes != nil
            || day.restingHeartRate != nil || day.hrvSDNN != nil || day.sleepHours != nil || day.weightKg != nil
    }
}
