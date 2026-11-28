import Foundation
import PulseDomain
import PulseServices
import Synchronization
import Testing

/// La FC de repos lue pendant la nuit (#118) : la fréquence cardiaque brute n'est lue que sur quelques jours, et la nuit du jour
/// prend la plus basse de son sommeil.
struct NightHistoryHeartRateTests {
    private let now = TestClock.date("2026-11-02T08:00")
    private var calendar: Calendar { TestClock.calendar }

    /// Le scénario « bonne nuit » (sommeil 23 h → 7 h, FC au repos Apple à 7 h 30), plus une fréquence cardiaque brute toutes les
    /// 10 minutes de 1 h à 5 h la nuit du jour, à 44 bpm.
    private final class HeartRateSource: HealthSampleSource, Sendable {
        let scenario: ScenarioHealthSource
        let heartRate: [CachedHealthSample]
        let starts = Mutex<[NightSignal: Date]>([:])

        init(scenario: ScenarioHealthSource, heartRate: [CachedHealthSample]) {
            self.scenario = scenario
            self.heartRate = heartRate
        }

        func requestAuthorization() async throws {}

        func profileHints() async throws -> HealthProfileHints {
            HealthProfileHints()
        }

        func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
            starts.withLock { $0[signal] = start }
            guard signal == .heartRate else { return try await scenario.changes(of: signal, since: anchor, from: start) }
            return HealthSampleChanges(kind: .heartRate, added: heartRate.filter { $0.start >= start }, deletedHealthKitUUIDs: [],
                                       anchor: Data("hr".utf8), isFullRead: true)
        }
    }

    private func source() -> HeartRateSource {
        let samples = stride(from: 60, through: 300, by: 10).map { minute in
            let date = TestClock.date("2026-11-02T00:00").addingTimeInterval(Double(minute) * 60)
            return CachedHealthSample(kind: .heartRate, start: date, end: date, value: 44, fetchedAt: date)
        }
        return HeartRateSource(scenario: ScenarioHealthSource(scenario: .goodNight, now: now, calendar: calendar), heartRate: samples)
    }

    @Test func rawHeartRateIsReadOverElevenDaysOnly() async {
        let source = source()
        _ = await NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar).refresh(now: now)
        let starts = source.starts.withLock { $0 }
        #expect(starts[.heartRate] == TestClock.date("2026-10-22T00:00"))
        #expect(starts[.sdnn] == TestClock.date("2026-09-03T00:00"))
    }

    @Test func tonightsRestingHeartRateIsTheLowestWhileAsleep() async {
        let snapshot = await NightHistory(source: source(), cache: InMemoryHealthSampleCache(), calendar: calendar).refresh(now: now)
        let tonight = snapshot.nights.last
        #expect(tonight?.restingHeartRate == 44)
        #expect(tonight?.restingHeartRateSource == .overnightLowest)
        let yesterday = snapshot.nights.dropLast().last
        #expect(yesterday?.restingHeartRateSource == .appleNearWake, "Sans fréquence cardiaque brute, l'échantillon Apple")
    }
}
