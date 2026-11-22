import Foundation
import Observation
import PulseDomain
import PulseServices
import TrainFeature

/// L'état de l'onglet Planning (spec M6 §7) : la semaine datée, la série, les déplacements.
@MainActor
@Observable
public final class PlanningModel {
    public private(set) var overview: PlanningOverview?
    public private(set) var errorMessage: String?
    public private(set) var hasLoaded = false
    /// Le jour dont on choisit la nouvelle place (« Déplacer à… »).
    public var moving: PlanningDay?

    @ObservationIgnored let environment: PlanningEnvironment
    @ObservationIgnored private var isLoading = false

    public init(environment: PlanningEnvironment) {
        self.environment = environment
    }

    /// Relit la semaine et la série. Un appel pendant une lecture est ignoré ; si la lecture échoue, l'écran garde son dernier
    /// état et affiche une erreur.
    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            overview = try await environment.service.overview()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire ton planning.", bundle: .module)
        }
        hasLoaded = true
    }

    public var days: [PlanningDay] { overview?.days ?? [] }

    public var today: PlanningDay? { days.first(where: \.isToday) }

    public var streak: StreakSummary? { overview?.streak }

    /// Les jours où `day` peut aller : les autres jours déplaçables de la semaine, pourvu qu'un des deux ait une séance.
    public func targets(for day: PlanningDay) -> [PlanningDay] {
        guard day.isMovable else { return [] }
        return days.filter { $0.id != day.id && $0.isMovable && ($0.routine != nil || day.routine != nil) }
    }

    /// Échange les séances de deux jours, puis relit la semaine.
    public func swap(_ day: PlanningDay, with target: PlanningDay) async {
        do {
            try await environment.service.swap(day.date, target.date)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu déplacer cette séance.", bundle: .module)
        }
        moving = nil
        await load()
    }

    /// Vrai pour un jour à venir qu'une règle anti-interférence a changé : « Garder le jour prévu » le rend à la semaine type.
    public func canKeepPlanned(_ day: PlanningDay) -> Bool {
        day.isMovable && day.scheduled.map(AntiInterference.isRule) == true
    }

    /// Refuse ce qu'une règle a placé ce jour-là (spec M6 §9), puis relit la semaine.
    public func keepPlanned(_ day: PlanningDay) async {
        do {
            try await environment.service.keepPlanned(day.date)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu garder le jour prévu.", bundle: .module)
        }
        await load()
    }

    /// Le rappel de la règle « même jour » (spec M6 §9), si elle n'est pas désactivée ; `nil` sinon.
    public func spacingReminder(for day: PlanningDay) -> String? {
        let disabled = overview?.profile?.antiInterferenceRulesDisabled.contains(.sameDayOrdering) == true
        guard !disabled, AntiInterference.needsSpacing(day) else { return nil }
        return String(localized: "Au moins 6 h entre les deux, la plus technique le matin.", bundle: .module)
    }

    /// Remet la semaine type, puis relit la semaine.
    public func restoreWeek() async {
        do {
            try await environment.service.restoreWeek()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu rétablir la semaine.", bundle: .module)
        }
        await load()
    }

    /// L'écran qu'ouvre un jour : la séance de musculation faite, sinon la course ou le vélo ; `nil` sans séance faite.
    public func destination(for day: PlanningDay) -> PlanningDestination? {
        if let strength = day.sessions.last(where: { $0.kind == .strength }) { return .session(strength.id) }
        return day.sessions.last.map { .activity($0.id) }
    }

    public func sessionDetailModel(sessionID: UUID) -> SessionDetailModel {
        SessionDetailModel(environment: environment.train, sessionID: sessionID)
    }

    public func activityDetailModel(sessionID: UUID) -> ActivityDetailModel {
        ActivityDetailModel(environment: environment, sessionID: sessionID)
    }

    public func monthModel() -> MonthModel {
        MonthModel(environment: environment, streak: streak, historyStart: overview?.historyStart)
    }

    // MARK: - Textes

    /// « Semaine du 16 novembre ».
    public var weekTitle: String {
        guard let first = days.first?.date else { return "" }
        let day = environment.text(of: first) { $0.day().month(.wide) }
        return String(localized: "Semaine du \(day)", bundle: .module)
    }

    /// « lun. ».
    public func weekdayText(_ day: PlanningDay) -> String {
        environment.text(of: day.date) { $0.weekday(.abbreviated) }
    }

    /// « 16 ».
    public func dayNumber(_ day: PlanningDay) -> String {
        environment.text(of: day.date) { $0.day() }
    }

    /// La séance prévue, sinon la séance faite, sinon « Repos ».
    public func title(of day: PlanningDay) -> String {
        if let routine = day.routine { return routine.name }
        if let session = day.sessions.first { return session.title }
        return day.state == .mandatoryRest
            ? String(localized: "Repos obligatoire", bundle: .module)
            : String(localized: "Repos", bundle: .module)
    }

    /// « Validée · 11 240 kg », « Manquée », « Sortie facile · 45 min », « Déplacée de mardi », « Legs déplacée à samedi »,
    /// « Choisi à l'inscription », ou la raison d'une règle anti-interférence (« Déplacée : 36 h après les jambes »).
    public func detail(of day: PlanningDay) -> String {
        detail(of: day, spoken: false)
    }

    /// Le détail d'un jour tel que VoiceOver le lit : « Validée, 11 240 kilos », « Sortie facile, 45 minutes », sans point
    /// médian ni abréviation.
    public func spokenDetail(of day: PlanningDay) -> String {
        detail(of: day, spoken: true)
    }

    /// « mercredi 18, aujourd'hui, Legs, Prévue » : ce que VoiceOver lit d'un jour de la bande ou de la liste.
    func accessibilityText(of day: PlanningDay) -> String {
        PlanningText.dayAccessibility(
            weekday: weekdayName(day.date), number: dayNumber(day), isToday: day.isToday, title: title(of: day),
            detail: spokenDetail(of: day))
    }

    private func detail(of day: PlanningDay, spoken: Bool) -> String {
        if day.state == .planned || day.state == .rest, let line = day.scheduled, AntiInterference.isRule(line),
           let reason = line.moveReasonText {
            return reason
        }
        switch day.state {
        case .done:
            let results = day.sessions.map { PlanningText.result(of: $0, spoken: spoken) }
                .joined(separator: spoken ? String(localized: " et ", bundle: .module) : " + ")
            if spoken {
                return day.routine == nil
                    ? String(localized: "En plus, \(results)", bundle: .module)
                    : String(localized: "Validée, \(results)", bundle: .module)
            }
            return day.routine == nil
                ? String(localized: "En plus · \(results)", bundle: .module)
                : String(localized: "Validée · \(results)", bundle: .module)
        case .missed:
            return String(localized: "Manquée", bundle: .module)
        case .planned:
            if let origin = day.movedFrom {
                return String(localized: "Déplacée de \(weekdayName(origin))", bundle: .module)
            }
            guard let routine = day.routine else { return "" }
            return routine.kind == .run ? PlanningText.run(routine, spoken: spoken) : String(localized: "Prévue", bundle: .module)
        case .rest:
            if let moved = days.first(where: { $0.movedFrom.map { environment.calendar.isDate($0, inSameDayAs: day.date) } ?? false }),
               let routine = moved.routine {
                return String(localized: "\(routine.name) déplacée à \(weekdayName(moved.date))", bundle: .module)
            }
            return String(localized: "Récupération", bundle: .module)
        case .mandatoryRest:
            return String(localized: "Choisi à l'inscription", bundle: .module)
        }
    }

    /// L'icône d'un jour : la discipline faite, sinon celle prévue, sinon un repos.
    public func icon(of day: PlanningDay) -> String {
        if let session = day.sessions.first { return PlanningText.icon(of: session.kind) }
        if let routine = day.routine { return PlanningText.icon(of: routine.kind) }
        return "moon.zzz"
    }

    /// « samedi ».
    func weekdayName(_ date: Date) -> String {
        environment.text(of: date) { $0.weekday(.wide) }
    }
}
