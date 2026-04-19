import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0
    @Published var todayRestingCalories: Double = 0
    @Published var latestWeight: Double? = nil
    @Published var isAuthorized = false

    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.bodyMass),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]

    private let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKObjectType.workoutType(),
    ]

    private init() {}

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await fetchTodayData()
        } catch {}
    }

    func fetchTodayData() async {
        async let steps = fetchSum(.stepCount, unit: .count())
        async let active = fetchSum(.activeEnergyBurned, unit: .kilocalorie())
        async let resting = fetchSum(.basalEnergyBurned, unit: .kilocalorie())
        async let weight = fetchLatest(.bodyMass, unit: .gramUnit(with: .kilo))

        let (s, a, r, w) = await (steps, active, resting, weight)
        todaySteps = Int(s)
        todayActiveCalories = a
        todayRestingCalories = r
        latestWeight = w > 0 ? w : nil
    }

    // MARK: - Private

    private func fetchSum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func fetchLatest(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let type = HKQuantityType(identifier)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
