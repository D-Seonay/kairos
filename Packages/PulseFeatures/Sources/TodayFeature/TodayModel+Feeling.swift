import CheckInFeature
import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices

extension TodayModel {
    /// Le ressenti du matin se donne tant que le score du jour est mesuré et pas encore figé (midi).
    var canGiveFeeling: Bool {
        guard let recovery = scoredToday else { return false }
        return !recovery.isEstimated && recovery.frozenAt == nil
    }

    /// Enregistre le ressenti du matin à côté du score mesuré : un léger modificateur (± 5 points au plus), qui peut rendre la
    /// séance plus prudente mais jamais faire monter la catégorie. Sans effet hors d'un score mesuré non figé, avec des réponses
    /// incomplètes ou pendant un enregistrement en cours.
    func submitFeeling() async {
        guard !isSubmittingFeeling, canGiveFeeling, let answers = feeling.answers else { return }
        isSubmittingFeeling = true
        defer { isSubmittingFeeling = false }
        feelingError = nil
        do {
            let updated = try await environment.refresher.saveCheckIn(answers)
            feeling.selection = [:]
            todayCheckIn = CheckIn(day: updated.day, answers: answers, score: CheckInScorer.score(answers),
                                   createdAt: updated.updatedAt, updatedAt: updated.updatedAt)
            applyWritten(updated)
        } catch DailyScoreError.frozen {
            // Midi est passé entre-temps : le score figé ne bouge plus, l'accueil se relit.
            await refresh()
        } catch {
            feelingError = String(localized: "Pulse n'a pas pu enregistrer ton ressenti.", bundle: .module)
        }
    }
}
