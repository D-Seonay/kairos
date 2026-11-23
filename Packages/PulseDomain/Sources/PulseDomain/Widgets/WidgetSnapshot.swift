import Foundation

/// Ce que le widget et l'écran verrouillé savent du jour : jamais une valeur de santé brute.
public struct WidgetSnapshot: Sendable, Equatable, Codable {
    public var day: Date
    public var score: Int
    public var category: RecoveryCategory
    public var isEstimated: Bool
    public var sessionTitle: String?
    public var isLightened: Bool
    /// « 5 exercices · 12 séries », « Sortie facile · 45 min » : la séance du jour telle qu'elle est à faire.
    public var sessionDetail: String?
    /// La série et la semaine en cours (spec M6 §11) ; nulles dans un instantané d'avant M6b.
    public var streak: WidgetStreak?
    /// Les 7 jours de la semaine en cours, du lundi au dimanche.
    public var week: [WidgetDay]?
    public var nextSession: WidgetNextSession?
    /// Le ratio de charge aiguë / chronique, quand l'historique couvre 28 jours.
    public var loadRatio: Double?
    /// La silhouette des cartes musculaires des widgets ; nulle dans un instantané d'avant ce choix (silhouette de femme).
    public var muscleMapFigure: MuscleMapFigure?

    public init(day: Date, score: Int, category: RecoveryCategory, isEstimated: Bool, sessionTitle: String?, isLightened: Bool,
                sessionDetail: String? = nil, streak: WidgetStreak? = nil, week: [WidgetDay]? = nil, nextSession: WidgetNextSession? = nil,
                loadRatio: Double? = nil, muscleMapFigure: MuscleMapFigure? = nil) {
        self.day = day
        self.score = score
        self.category = category
        self.isEstimated = isEstimated
        self.sessionTitle = sessionTitle
        self.isLightened = isLightened
        self.sessionDetail = sessionDetail
        self.streak = streak
        self.week = week
        self.nextSession = nextSession
        self.loadRatio = loadRatio
        self.muscleMapFigure = muscleMapFigure
    }
}

/// La série du widget : semaines réussies d'affilée, séances de la semaine et objectif.
public struct WidgetStreak: Sendable, Equatable, Codable {
    public var weeks: Int
    public var completed: Int
    public var target: Int

    public init(weeks: Int, completed: Int, target: Int) {
        self.weeks = weeks
        self.completed = completed
        self.target = target
    }
}

/// La discipline d'un jour pour le widget.
public enum WidgetDayKind: String, Sendable, Codable {
    case strength
    case run
    case rest
}

/// Ce qu'un jour est devenu, pour le widget : le planning ne fait pas de reproche, un jour manqué n'est qu'un jour passé.
public enum WidgetDayState: String, Sendable, Codable {
    case done
    case missed
    case planned
    case rest
}

/// Un jour de la semaine en cours pour le widget.
public struct WidgetDay: Sendable, Equatable, Codable {
    public var date: Date
    public var kind: WidgetDayKind
    public var state: WidgetDayState
    public var isToday: Bool

    public init(date: Date, kind: WidgetDayKind, state: WidgetDayState, isToday: Bool) {
        self.date = date
        self.kind = kind
        self.state = state
        self.isToday = isToday
    }
}

/// La prochaine séance prévue après aujourd'hui : son titre, son jour, sa discipline et sa cible.
public struct WidgetNextSession: Sendable, Equatable, Codable {
    public var title: String
    public var date: Date
    public var kind: WidgetDayKind
    /// « 5 exercices · 16 séries », « 45 min » ; nul sans cible.
    public var detail: String?

    public init(title: String, date: Date, kind: WidgetDayKind, detail: String?) {
        self.title = title
        self.date = date
        self.kind = kind
        self.detail = detail
    }
}
