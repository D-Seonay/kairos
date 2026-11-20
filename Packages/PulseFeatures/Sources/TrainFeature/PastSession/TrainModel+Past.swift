import Foundation
import PulseServices

/// « Saisir une séance passée » (spec M4 §19.4) : le brouillon du formulaire et la séance qu'il lance.
extension TrainModel {
    /// L'heure de l'app, qui borne la date du formulaire.
    var now: Date { environment.now() }

    func initialPastDraft() -> PastSessionDraft {
        PastSessionDraft.initial(now: environment.now(), calendar: environment.calendar)
    }

    /// Ce qui empêche de saisir la séance, ou `nil`.
    func pastProblem(_ draft: PastSessionDraft) -> String? {
        draft.problem(now: environment.now(), calendar: environment.calendar)
    }

    /// La séance à saisir : la routine choisie du programme actif, telle que prévue, ou une séance vide. `nil` tant que la
    /// séance n'est pas finie.
    public func pastLaunch(_ draft: PastSessionDraft) -> SessionLaunch? {
        guard let interval = draft.interval(now: environment.now(), calendar: environment.calendar) else { return nil }
        let day = draft.routineID.flatMap { id in program?.days.first { $0.id == id && $0.kind == .strength } }
        return SessionLaunch.past(day, programID: program?.id, interval: interval)
    }
}
