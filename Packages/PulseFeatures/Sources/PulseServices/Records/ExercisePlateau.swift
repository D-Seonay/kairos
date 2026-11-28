import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Un plateau sur un exercice : le meilleur 1RM estimé (Brzycki) n'a pas été dépassé depuis au moins quatre séances comptées et
/// trois semaines. Ce n'est pas un verdict : le texte dit le calcul, et les pistes restent des propositions.
public struct ExercisePlateau: Sendable, Equatable {
    public var exercise: ExerciseReference
    /// Le meilleur 1RM estimé avant les dernières séances comptées : la dernière progression.
    public var bestKg: Double
    /// La date de la séance de ce meilleur 1RM.
    public var bestDate: Date
    /// Le meilleur 1RM estimé des séances comptées depuis : au plus `bestKg`.
    public var recentBestKg: Double
    /// Les séances comptées depuis le meilleur 1RM, toutes sans progrès : au moins `PlateauDetector.sessionCount`.
    public var sessionCount: Int
    /// La date de la dernière séance comptée.
    public var lastDate: Date
    /// Les séances faites entre-temps en fatigue ou en décharge, écartées du calcul.
    public var excludedCount: Int

    public init(exercise: ExerciseReference, bestKg: Double, bestDate: Date, recentBestKg: Double, sessionCount: Int,
                lastDate: Date, excludedCount: Int) {
        self.exercise = exercise
        self.bestKg = bestKg
        self.bestDate = bestDate
        self.recentBestKg = recentBestKg
        self.sessionCount = sessionCount
        self.lastDate = lastDate
        self.excludedCount = excludedCount
    }
}

/// Le calcul du plateau. Pur : les séances sont lues avant l'appel.
///
/// Pour chaque séance terminée ou abandonnée (comme la courbe et les records de la fiche), la meilleure série de l'exercice
/// donne un 1RM estimé (Brzycki, charge externe, 1 à 12 répétitions). Les séances faites en fatigue modérée, en surmenage ou
/// pendant une décharge ne comptent pas : une séance ne garde pas sa catégorie de récupération, mais elle garde les ajustements
/// du jour, appliqués ou refusés, qui la trahissent (voir `counts(_:)`). Il y a plateau quand les quatre dernières séances
/// comptées ne dépassent pas le meilleur 1RM des séances comptées des 90 jours d'avant, que la plus récente ne bat pas les trois
/// autres (une remontée en cours n'est pas un plateau), et qu'au moins 21 jours séparent la première fois où ce meilleur 1RM a
/// été atteint de la dernière séance comptée.
public enum PlateauDetector {
    /// Le nombre de séances comptées sans progrès.
    public static let sessionCount = 4
    /// Le nombre de jours, au moins, entre la dernière progression et la dernière séance comptée.
    public static let minimumDays = 21
    /// La dernière progression se cherche dans les 90 jours qui précèdent les séances comptées : un meilleur 1RM d'avant une
    /// longue pause ne fait pas un plateau pendant la reprise.
    public static let lookbackDays = 90
    /// Sans séance comptée depuis 28 jours, l'exercice n'est plus travaillé : rien à signaler.
    public static let staleDays = 28
    /// Un écart plus petit que celui-ci n'est pas une progression (arrondis du calcul).
    static let tolerance = 0.01

    /// Une séance d'un exercice : sa date, son meilleur 1RM estimé et si elle compte.
    private struct Point {
        var date: Date
        var estimate: Double
        var counts: Bool
    }

    /// Le plateau de `exercise` dans `sessions`, ou `nil` : pas de plateau, pas assez de séances, un exercice sans charge
    /// externe, ou plus travaillé depuis `staleDays`.
    public static func plateau(for exercise: ExerciseReference, in sessions: [WorkoutSession], loadKind: LoadKind, now: Date,
                               calendar: Calendar) -> ExercisePlateau? {
        guard loadKind == .external else { return nil }
        let points = sessions
            .filter { $0.status == .completed || $0.status == .abandoned }
            .compactMap { session in
                bestEstimate(of: exercise, in: session).map { Point(date: session.startedAt, estimate: $0, counts: counts(session)) }
            }
            .sorted { $0.date < $1.date }
        let counted = points.filter(\.counts)
        guard counted.count > sessionCount, let last = counted.last, let windowStart = counted.suffix(sessionCount).first?.date,
              let staleLimit = calendar.date(byAdding: .day, value: -staleDays, to: now), last.date >= staleLimit,
              let lookbackStart = calendar.date(byAdding: .day, value: -lookbackDays, to: windowStart) else { return nil }
        // Le meilleur 1RM d'avant les séances comptées ; à égalité, la première fois où il a été atteint : refaire le même
        // niveau n'est pas une progression et ne remet pas les 21 jours à zéro.
        let candidates = counted.dropLast(sessionCount).filter { $0.date >= lookbackStart }
        guard let best = candidates.max(by: { ($0.estimate, $1.date) < ($1.estimate, $0.date) }),
              !isRising(Array(counted.suffix(sessionCount))) else { return nil }
        let since = counted.filter { $0.date > best.date }
        guard let recentBest = since.map(\.estimate).max(), recentBest <= best.estimate + tolerance,
              days(from: best.date, to: last.date, calendar: calendar) >= minimumDays else { return nil }
        let excluded = points.filter { !$0.counts && $0.date > best.date && $0.date <= last.date }.count
        return ExercisePlateau(exercise: exercise, bestKg: best.estimate, bestDate: best.date, recentBestKg: recentBest,
                               sessionCount: since.count, lastDate: last.date, excludedCount: excluded)
    }

    /// Vrai quand la séance la plus récente bat toutes les autres de la liste : une remontée en cours, par exemple après une
    /// maladie, même sous l'ancien meilleur 1RM. Une séance qui ne bat que la précédente (80 × 4 puis 80 × 5, en alternance)
    /// ne fait pas une remontée : c'est le motif même d'un plateau.
    private static func isRising(_ window: [Point]) -> Bool {
        guard let last = window.last, let earlier = window.dropLast().map(\.estimate).max() else { return false }
        return last.estimate > earlier + tolerance
    }

    /// Vrai pour une séance qui compte dans le calcul. Une séance ne garde pas sa catégorie de récupération ; elle garde les
    /// ajustements du jour, qu'on lit à sa place :
    /// - une décharge appliquée l'écarte (refusée, la séance a été faite aux charges habituelles : elle compte) ;
    /// - la fatigue modérée laisse toujours un repos rallongé de 45 s, souvent un volume réduit et un RPE plafonné ; le
    ///   surmenage, une séance remplacée par de la mobilité. Ces marques l'écartent qu'elles soient appliquées ou refusées : un
    ///   jour de fatigue reste un jour de fatigue, même quand on choisit la séance d'origine.
    /// Une séance sans ajustement (sans score, adaptation coupée, importée) compte : rien ne dit qu'elle a été faite fatigué.
    public static func counts(_ session: WorkoutSession) -> Bool {
        if session.isDeloaded { return false }
        return !(session.appliedAdjustments + session.refusedAdjustments).contains(where: isFatigueMark)
    }

    private static func isFatigueMark(_ adjustment: SessionAdjustment) -> Bool {
        switch adjustment.kind {
        case .volume, .rpeCap, .replaceWithMobility, .suggestRest, .swapIntervalsForEasy:
            true
        case .rest:
            (adjustment.value ?? 0) >= Double(SessionAdjuster.fatigueExtraRestSeconds)
        case .load, .deload:
            false
        }
    }

    /// Le meilleur 1RM estimé des séries de travail réellement faites de `exercise` dans `session`.
    private static func bestEstimate(of exercise: ExerciseReference, in session: WorkoutSession) -> Double? {
        session.sets
            .filter { $0.exercise == exercise && $0.setType != .warmup }
            .compactMap { set in set.actualReps.flatMap { OneRepMax.brzycki(weightKg: set.actualWeightKg ?? 0, reps: $0) } }
            .max()
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }
}

// MARK: - Textes

extension ExercisePlateau {
    private static let french = Locale(identifier: "fr_FR")

    /// Le calcul dit en clair, dans l'esprit de l'écran Pourquoi : « Pulse estime ton 1RM avec la formule de Brzycki et garde
    /// la meilleure série de chaque séance. Ton meilleur 1RM estimé des 3 derniers mois : 100 kg le 2 novembre. Les 4 séances
    /// suivantes, sur 3 semaines, n'ont pas fait mieux (au mieux 97,5 kg). » suivi, s'il y en a, des séances écartées.
    /// `spoken` écrit « kilos » pour VoiceOver.
    public func explanation(calendar: Calendar, spoken: Bool = false) -> String {
        let best = kilos(bestKg, spoken: spoken)
        let recent = kilos(recentBestKg, spoken: spoken)
        let date = Self.dateText(bestDate, calendar: calendar)
        let weeks = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: bestDate),
                                                    to: calendar.startOfDay(for: lastDate)).day ?? 0) / 7
        let duration = weeks <= 1 ? String(localized: "1 semaine", bundle: .module)
            : String(localized: "\(weeks) semaines", bundle: .module)
        var text = String(localized: """
            Pulse estime ton 1RM avec la formule de Brzycki et garde la meilleure série de chaque séance. Ton meilleur 1RM estimé \
            des 3 derniers mois : \(best) le \(date). Les \(sessionCount) séances suivantes, sur \(duration), n'ont pas fait \
            mieux (au mieux \(recent)).
            """, bundle: .module)
        if excludedCount == 1 {
            text += " " + String(localized: "1 séance faite en fatigue ou en décharge n'est pas comptée.", bundle: .module)
        } else if excludedCount > 1 {
            text += " " + String(localized: "\(excludedCount) séances faites en fatigue ou en décharge ne sont pas comptées.",
                                 bundle: .module)
        }
        return text
    }

    /// Les trois pistes, à essayer une à la fois. `variant` : le nom d'une variante proposée par `ReplacementPlanner` (une
    /// alternative du contenu ou un exercice du même plan de mouvement), s'il y en a une.
    public static func tips(variant: String?) -> [String] {
        let variantTip = variant.map {
            String(localized: "Le remplacer quelques semaines par une variante, comme \($0).", bundle: .module)
        } ?? String(localized: "Le remplacer quelques semaines par une variante proche.", bundle: .module)
        return [
            String(localized: "Changer de schéma de séries, par exemple de 5 × 5 à 4 × 8.", bundle: .module),
            String(localized: "Décharger cet exercice seul une semaine : charges −10 % et moins de séries, puis repartir.",
                   bundle: .module),
            variantTip
        ]
    }

    private func kilos(_ value: Double, spoken: Bool) -> String {
        guard !spoken else { return LiveSessionText.kilosSpoken((value * 10).rounded() / 10) }
        let units = PulseUnits.current
        return "\(LiveSessionText.decimal((units.displayedWeight(kilograms: value) * 10).rounded() / 10)) \(units.weightSymbol)"
    }

    /// « 2 novembre ».
    private static func dateText(_ date: Date, calendar: Calendar) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: french, calendar: calendar, timeZone: calendar.timeZone)
        return date.formatted(style.day().month(.wide))
    }
}
