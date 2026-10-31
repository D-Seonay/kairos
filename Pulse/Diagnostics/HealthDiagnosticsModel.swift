import Foundation
import Observation
import PulseDomain
import PulseHealth
import PulseRecoveryEngine

/// Une ligne de l'écran de diagnostic : dernier échantillon d'un type et volume sur 60 jours.
struct DiagnosticRow: Identifiable, Equatable {
    let type: HealthDataType
    var id: HealthDataType { type }
    let latest: HealthSamplePoint?
    let countLast60Days: Int
}

/// Lit 60 jours d'Apple Santé, agrège les nuits et calcule le score provisoire du jour.
@MainActor
@Observable
final class HealthDiagnosticsModel {
    static let historyDays = 60

    private(set) var rows: [DiagnosticRow]
    private(set) var nights: [NightSample] = []
    private(set) var outcome: RecoveryOutcome?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    private let dependencies: AppDependencies
    private let today: Date

    init(dependencies: AppDependencies, today: Date = .now) {
        self.dependencies = dependencies
        self.today = today
        self.rows = HealthDataType.allCases.map { DiagnosticRow(type: $0, latest: nil, countLast60Days: 0) }
    }

    /// Toute erreur est rendue dans `errorMessage` ; ce qui a déjà été chargé reste affiché.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let calendar = dependencies.calendar
        let health = dependencies.health
        let dayStart = calendar.startOfDay(for: today)
        guard let from = calendar.date(byAdding: .day, value: -Self.historyDays, to: dayStart),
              let to = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            errorMessage = String(localized: "Le calendrier n'a pas pu borner les 60 derniers jours.")
            return
        }
        let days = (0..<Self.historyDays).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: dayStart) }

        do {
            try await health.requestReadAuthorization()

            let sdnn = try await health.sdnnSamples(from: from, to: to)
            let restingHeartRate = try await health.restingHeartRateSamples(from: from, to: to)
            let sleep = try await health.sleepIntervals(from: from, to: to)
            nights = NightAggregator(calendar: calendar).nights(days: days, sdnn: sdnn, restingHeartRate: restingHeartRate, sleep: sleep)

            if let todayNight = nights.last {
                outcome = RecoveryCalculator(calendar: calendar)
                    .compute(day: dayStart, today: todayNight, history: Array(nights.dropLast()))
            }

            var rows: [DiagnosticRow] = []
            for type in HealthDataType.allCases {
                let latest = try await health.latestSample(of: type)
                let count = try await health.sampleCount(of: type, from: from, to: to)
                rows.append(DiagnosticRow(type: type, latest: latest, countLast60Days: count))
            }
            self.rows = rows
        } catch {
            errorMessage = String(localized: "Apple Santé n'a pas pu être lu. Vérifiez l'autorisation dans Réglages › Confidentialité et sécurité › Santé › Pulse.")
        }
    }
}
