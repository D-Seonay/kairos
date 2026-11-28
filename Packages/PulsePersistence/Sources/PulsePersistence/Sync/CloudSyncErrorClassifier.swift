import CloudKit
import Foundation
import PulseDomain

/// Ramène une erreur de synchronisation (CloudKit, Core Data, réseau) à un cas qu'on sait expliquer. Les erreurs enveloppées
/// (`NSUnderlyingErrorKey`) et les échecs partiels (`CKPartialErrorsByItemIDKey`) sont lus jusqu'au bout : un échec partiel dû au
/// quota est un quota.
public enum CloudSyncErrorClassifier {
    /// Le magasin miroir n'a pas pu démarrer faute de compte iCloud (`NSCloudKitMirroringDelegate`).
    static let missingAccountCoreDataCode = 134_400

    public static func classify(_ error: (any Error)?) -> CloudSyncProblem {
        guard let error else { return .other }
        return classify(error as NSError, depth: 0) ?? .other
    }

    private static func classify(_ error: NSError, depth: Int) -> CloudSyncProblem? {
        guard depth < 8 else { return nil }
        if let problem = direct(error) {
            if problem == .partialFailure, let inner = partialProblem(error, depth: depth) { return inner }
            return problem
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return classify(underlying, depth: depth + 1)
        }
        return nil
    }

    private static func direct(_ error: NSError) -> CloudSyncProblem? {
        switch error.domain {
        case CKErrorDomain:
            return cloudKit(CKError.Code(rawValue: error.code))
        case NSURLErrorDomain:
            return .network
        case NSCocoaErrorDomain where error.code == missingAccountCoreDataCode:
            return .noAccount
        default:
            return nil
        }
    }

    private static func cloudKit(_ code: CKError.Code?) -> CloudSyncProblem? {
        switch code {
        case .quotaExceeded?: .quotaExceeded
        case .notAuthenticated?, .accountTemporarilyUnavailable?: .noAccount
        case .networkUnavailable?, .networkFailure?: .network
        case .serviceUnavailable?, .requestRateLimited?, .zoneBusy?: .busy
        case .partialFailure?: .partialFailure
        default: nil
        }
    }

    /// Le cas le plus parlant parmi les erreurs par enregistrement d'un échec partiel : quota, compte, réseau, iCloud occupé, puis
    /// le reste.
    private static func partialProblem(_ error: NSError, depth: Int) -> CloudSyncProblem? {
        guard let items = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: any Error] else { return nil }
        let problems = Set(items.values.compactMap { classify($0 as NSError, depth: depth + 1) })
        return [CloudSyncProblem.quotaExceeded, .noAccount, .network, .busy].first { problems.contains($0) }
    }
}
