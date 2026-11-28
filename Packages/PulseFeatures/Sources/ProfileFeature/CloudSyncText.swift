import Foundation
import PulseDomain

/// Les phrases de la synchronisation iCloud dans « Mes données » et sur la page Profil : quand elle a réussi pour la dernière fois,
/// ou ce qui la bloque et quoi faire, en clair.
public enum CloudSyncText {
    /// « Synchronisé il y a 3 min. », ou l'erreur et quoi faire, suivie de la dernière réussite ; `nil` quand rien n'est à dire :
    /// pas d'iCloud sur cet appareil, ou pas de compte (la phrase du compte le dit déjà).
    public static func status(_ status: CloudSyncStatus?, account: CloudAccountStatus?, now: Date) -> String? {
        guard let status, account != .noAccount, account != .restricted else { return nil }
        guard let problem = status.lastError else {
            guard let lastSuccess = status.lastSuccess else {
                return String(localized: "Synchronisation iCloud en attente.", bundle: .module)
            }
            return String(localized: "Synchronisé \(elapsed(since: lastSuccess, now: now)).", bundle: .module)
        }
        guard let lastSuccess = status.lastSuccess else { return advice(for: problem) }
        let since = String(localized: "Dernière synchronisation réussie \(elapsed(since: lastSuccess, now: now)).", bundle: .module)
        return "\(advice(for: problem)) \(since)"
    }

    /// Sur la page Profil, sous « Mes données » : seulement quand la synchronisation échoue depuis plus de 24 h.
    public static func durableWarning(_ status: CloudSyncStatus?, now: Date) -> String? {
        guard let status, status.isDurableError(at: now) else { return nil }
        return String(localized: "La synchronisation iCloud échoue depuis plus d'un jour", bundle: .module)
    }

    /// Ce qui bloque, et quoi faire.
    public static func advice(for problem: CloudSyncProblem) -> String {
        switch problem {
        case .quotaExceeded: String(localized: """
            Stockage iCloud plein : tes dernières données ne sont plus sauvegardées. \
            Libère de l'espace dans Réglages > ton nom > iCloud.
            """, bundle: .module)
        case .noAccount: String(localized: """
            iCloud est indisponible : vérifie que tu es connecté à ton compte dans Réglages. \
            Tes données restent sur ce téléphone en attendant.
            """, bundle: .module)
        case .network: String(localized: """
            iCloud est injoignable pour l'instant : la synchronisation reprendra toute seule quand le réseau reviendra.
            """, bundle: .module)
        case .partialFailure: String(localized: """
            Une partie de tes données n'est pas passée dans iCloud. Pulse réessaie tout seul ; \
            si ça dure, vérifie l'espace libre de ton stockage iCloud.
            """, bundle: .module)
        case .other: String(localized: """
            La synchronisation iCloud a échoué. Pulse réessaie tout seul ; \
            si ça dure plus d'un jour, redémarre l'iPhone ou vérifie iCloud dans Réglages.
            """, bundle: .module)
        }
    }

    /// « à l'instant », « il y a 3 min », « il y a 2 h », « il y a 4 jours ». Une date dans le futur (horloge reculée) compte
    /// comme « à l'instant ».
    static func elapsed(since date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60:
            return String(localized: "à l'instant", bundle: .module)
        case ..<3_600:
            return String(localized: "il y a \(Int(seconds / 60)) min", bundle: .module)
        case ..<86_400:
            return String(localized: "il y a \(Int(seconds / 3_600)) h", bundle: .module)
        default:
            let days = Int(seconds / 86_400)
            return days == 1 ? String(localized: "il y a 1 jour", bundle: .module)
                : String(localized: "il y a \(days) jours", bundle: .module)
        }
    }
}
