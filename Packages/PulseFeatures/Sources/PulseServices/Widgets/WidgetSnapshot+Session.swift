import Foundation
import PulseDomain

extension WidgetSnapshot {
    /// L'instantané du jour : score arrondi, catégorie, titre de la séance et allègement, rien d'autre.
    public init(recovery: DailyRecovery, session: TodaySession) {
        self.init(day: recovery.day, score: Int(recovery.score.rounded()), category: recovery.category,
                  isEstimated: recovery.isEstimated, sessionTitle: session.title, isLightened: session.isLightened)
    }
}

extension RecoveryCategory {
    /// La catégorie en milieu de phrase, en minuscules.
    public var sentenceName: String {
        switch self {
        case .optimal: String(localized: "forme optimale", bundle: .module)
        case .normal: String(localized: "forme normale", bundle: .module)
        case .moderateFatigue: String(localized: "fatigue modérée", bundle: .module)
        case .overreached: String(localized: "surmenage", bundle: .module)
        }
    }
}
