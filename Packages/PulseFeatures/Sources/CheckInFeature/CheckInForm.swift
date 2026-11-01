import Observation
import PulseDomain
import PulseRecoveryEngine

/// L'état du formulaire : les réponses choisies et le score estimé, `nil` tant qu'une question reste sans réponse.
@MainActor
@Observable
public final class CheckInForm {
    public var selection: [CheckInQuestion: Int] = [:]

    public init() {}

    public var answers: CheckInAnswers? {
        guard let sleep = selection[.sleep], let pain = selection[.pain], let motivation = selection[.motivation] else {
            return nil
        }
        return CheckInAnswers(sleep: sleep, pain: pain, motivation: motivation)
    }

    public var estimatedScore: Double? {
        answers.map(CheckInScorer.score)
    }
}
