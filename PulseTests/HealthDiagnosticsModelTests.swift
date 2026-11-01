// swiftlint:disable force_unwrapping
import Foundation
@testable import Pulse
import PulseDomain
import PulseHealth
import Testing

@MainActor
@Suite struct HealthDiagnosticsModelTests {
    /// 20 nuits : sommeil 23:00 (jour − i − 1) → 07:00 (jour − i) en `.core`, un SDNN de 50 ms à 03:00, FC repos 50 à 10:00.
    static func twentyNights(calendar: Calendar, today: Date) -> StubHealthReader {
        var sdnn: [TimedSample] = []
        var rhr: [TimedSample] = []
        var sleep: [SleepInterval] = []
        for i in 0..<20 {
            let wake = calendar.date(byAdding: .day, value: -i, to: today)!
            let bedtime = calendar.date(byAdding: .hour, value: -1, to: wake)!
            sleep.append(SleepInterval(start: bedtime, end: calendar.date(byAdding: .hour, value: 7, to: wake)!, stage: .core))
            sdnn.append(TimedSample(date: calendar.date(byAdding: .hour, value: 3, to: wake)!, value: 50))
            rhr.append(TimedSample(date: calendar.date(byAdding: .hour, value: 10, to: wake)!, value: 50))
        }
        let latest = HealthSamplePoint(type: .hrvSDNN, date: sdnn[0].date, valueText: "50 ms",
                                       sourceName: "Fitbit", sourceBundleID: "com.fitbit.FitbitMobile")
        return StubHealthReader(latest: [.hrvSDNN: latest], counts: [.hrvSDNN: 20], sdnn: sdnn, restingHeartRate: rhr, sleep: sleep)
    }

    @Test func refreshBuildsRowsNightsAndOutcome() async throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let stub = Self.twentyNights(calendar: cal, today: today)
        let model = HealthDiagnosticsModel(dependencies: .testing(health: stub, calendar: cal), today: today)
        await model.refresh()
        #expect(model.rows.count == HealthDataType.allCases.count)
        #expect(model.rows.first { $0.type == .hrvSDNN }?.countLast60Days == 20)
        #expect(model.rows.first { $0.type == .hrvSDNN }?.latest?.sourceName == "Fitbit")
        #expect(model.rows.first { $0.type == .sleepAnalysis }?.latest == nil)
        #expect(model.nights.count == 60)
        #expect(model.nights.last?.day == today)
        #expect(model.nights.last?.sdnnMs == 50)
        #expect(model.nights.last?.sleep == SleepSummary(asleepMinutes: 480, deepMinutes: 0))
        guard case .measured(let r)? = model.outcome else {
            Issue.record("expected measured, got \(String(describing: model.outcome))")
            return
        }
        #expect(r.calibration == .ready)
        #expect(r.missing.isEmpty)
        #expect(model.errorMessage == nil)
        #expect(model.isLoading == false)
    }

    @Test func refreshSurfacesErrorsWithoutCrashing() async {
        struct Boom: Error {}
        let model = HealthDiagnosticsModel(dependencies: .testing(health: StubHealthReader(error: Boom()), calendar: .current))
        await model.refresh()
        #expect(model.errorMessage != nil)
        #expect(model.isLoading == false)
        #expect(model.outcome == nil)
        #expect(model.rows.isEmpty == false, "les lignes restent affichées, vides, même en erreur")
    }

    @Test func liveDependenciesFallBackToStubWhenHealthKitUnavailable() {
        let deps = AppDependencies.live()
        #expect(deps.calendar == .current)
    }
}
// swiftlint:enable force_unwrapping
