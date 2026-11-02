import CheckInFeature
import Foundation
import PulseDomain
import PulseRecoveryEngine

extension DailyRecovery {
    func subScore(of factor: Factor) -> Double? {
        switch factor {
        case .hrv: hrvScore
        case .restingHeartRate: restingHeartRateScore
        case .sleep: sleepScore
        }
    }

    /// Les facteurs que la nuit a fournis, dans l'ordre VFC, FC au repos, sommeil.
    var presentFactors: [Factor] {
        Factor.allCases.filter { !missingFactors.contains($0) && subScore(of: $0) != nil }
    }
}

/// Les signaux du score : les trois sous-scores de la nuit, ou les trois réponses du check-in, et la formule qui les pondère.
enum WhySignals {
    struct Result: Equatable {
        var signals: [WhyContent.Signal]
        var formula: String
    }

    /// Les poids du score de check-in, sommeil 40 / douleurs 35 / motivation 25 (`CheckInScorer`).
    private static let checkInWeights = [40, 35, 25]

    static func make(recovery: DailyRecovery, checkIn: CheckIn?) -> Result {
        recovery.isEstimated ? estimated(recovery, checkIn: checkIn) : measured(recovery)
    }

    // MARK: - Score mesuré

    /// Les poids nominaux 50 / 25 / 25, renormalisés sur les facteurs présents, en pourcentages entiers.
    private static func measured(_ recovery: DailyRecovery) -> Result {
        let present = recovery.presentFactors
        let total = present.reduce(0) { $0 + RecoveryCalculator.nominalWeight(for: $1) }
        let rows = present.map { factor in
            (factor: factor,
             weight: WhyContent.rounded(RecoveryCalculator.nominalWeight(for: factor) / total * 100),
             score: WhyContent.rounded(recovery.subScore(of: factor) ?? 0))
        }
        let signals = rows.map { WhyContent.Signal(title: title(of: $0.factor), score: $0.score) }
        return Result(signals: signals, formula: formula(terms: rows.map { ($0.weight, $0.score) }, result: recovery.score))
    }

    private static func title(of factor: Factor) -> String {
        switch factor {
        case .hrv: String(localized: "Variabilité", bundle: .module)
        case .restingHeartRate: String(localized: "FC au repos", bundle: .module)
        case .sleep: String(localized: "Sommeil", bundle: .module)
        }
    }

    // MARK: - Score estimé

    /// Sans les réponses (le check-in n'a pas pu être relu), le score est dit sans détail.
    private static func estimated(_ recovery: DailyRecovery, checkIn: CheckIn?) -> Result {
        guard let answers = checkIn?.answers else {
            let score = WhyContent.rounded(recovery.score)
            return Result(signals: [], formula: String(localized: "Score estimé à partir de ton check-in : \(score)", bundle: .module))
        }
        let rows = [
            Answer(title: String(localized: "Sommeil", bundle: .module), question: .sleep, value: answers.sleep),
            Answer(title: CheckInQuestion.pain.title, question: .pain, value: answers.pain),
            Answer(title: String(localized: "Motivation", bundle: .module), question: .motivation, value: answers.motivation)
        ]
        let signals = rows.map { WhyContent.Signal(title: $0.signalTitle, score: $0.score) }
        let terms = zip(checkInWeights, rows).map { (weight: $0, score: $1.score) }
        return Result(signals: signals, formula: formula(terms: terms, result: recovery.score))
    }

    /// Une réponse du check-in : la question, son titre court et la valeur de 0 à 4.
    private struct Answer {
        var title: String
        var question: CheckInQuestion
        var value: Int

        /// Une réponse vaut 25 par cran, comme dans `CheckInScorer`.
        var score: Int { min(4, max(0, value)) * 25 }

        /// « Sommeil : Bon ».
        var signalTitle: String {
            guard let label = question.options.first(where: { $0.value == value })?.label else { return title }
            return String(localized: "\(title) : \(label)", bundle: .module)
        }
    }

    // MARK: - Formule

    /// « Score = 50 % × 59 + 25 % × 58 + 25 % × 56 = 58 ».
    private static func formula(terms: [(weight: Int, score: Int)], result: Double) -> String {
        let sum = terms.map { "\($0.weight) % × \($0.score)" }.joined(separator: " + ")
        let score = WhyContent.rounded(result)
        guard !sum.isEmpty else { return String(localized: "Score = \(score)", bundle: .module) }
        return String(localized: "Score = \(sum) = \(score)", bundle: .module)
    }
}
