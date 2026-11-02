import Foundation
import PulseDomain
import PulseServices

/// Les hausses de charge du jour, dites sur l'écran « Pourquoi » avant que la séance démarre : le planificateur de la séance en
/// direct est lu sans rien écrire, sur le jour à faire et l'historique relu par l'accueil.
enum LoadPreview {
    // swiftlint:disable function_parameter_count
    /// Les ajustements de charge du jour ; vide si aucune série n'a atteint le haut de sa fourchette. `nil` quand l'écran ne dit
    /// rien des hausses : un autre jour qu'optimal ou normal, une journée sans musculation, ou une hausse bloquée (score estimé,
    /// calibration en cours).
    static func adjustments(session: TodaySession, recovery: DailyRecovery, profile: UserProfile?, reading: LiveReading,
                            directory: ExerciseDirectory, now: Date) -> [SessionAdjustment]? {
        guard recovery.category == .optimal || recovery.category == .normal, case .strength(let day) = session.plannedDay else {
            return nil
        }
        let launch = SessionLaunch.routine(day, programID: nil, recovery: recovery, originalChosen: false, profile: profile)
        guard launch.policy.allowsIncrease else { return nil }
        let planned = LiveSessionPlanner.session(for: launch, directory: directory, history: reading.history,
                                                 settings: reading.settings, profile: profile, now: now)
        return planned.appliedAdjustments.filter { $0.kind == .load }
    }
    // swiftlint:enable function_parameter_count
}
