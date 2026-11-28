import Foundation
@testable import ProfileFeature
import PulseDomain
import Testing

private let now = Date(timeIntervalSince1970: 1_794_700_000)

@Test func aSuccessfulSyncSaysHowLongAgo() {
    func text(_ secondsAgo: TimeInterval) -> String? {
        CloudSyncText.status(CloudSyncStatus(lastSuccess: now.addingTimeInterval(-secondsAgo)), account: .available, now: now)
    }
    #expect(text(20) == "Synchronisé à l'instant.")
    #expect(text(3 * 60 + 10) == "Synchronisé il y a 3 min.")
    #expect(text(2 * 3_600) == "Synchronisé il y a 2 h.")
    #expect(text(30 * 3_600) == "Synchronisé il y a 1 jour.")
    #expect(text(4 * 86_400) == "Synchronisé il y a 4 jours.")
    #expect(text(-60) == "Synchronisé à l'instant.")
    #expect(CloudSyncText.status(CloudSyncStatus(), account: .available, now: now) == "Synchronisation iCloud en attente.")
}

/// Une erreur se dit en clair, avec quoi faire, puis la dernière réussite ; sans compte, la phrase du compte suffit.
@Test func anErrorSaysWhatToDo() throws {
    var status = CloudSyncStatus(lastSuccess: now.addingTimeInterval(-7_200))
    status.record(CloudSyncEvent(endDate: now.addingTimeInterval(-60), problem: .quotaExceeded))
    let text = try #require(CloudSyncText.status(status, account: .available, now: now))
    #expect(text.hasPrefix("Stockage iCloud plein"))
    #expect(text.contains("Réglages"))
    #expect(text.hasSuffix("Dernière synchronisation réussie il y a 2 h."))
    #expect(CloudSyncText.status(status, account: .noAccount, now: now) == nil)
    #expect(CloudSyncText.status(nil, account: .available, now: now) == nil)
    for problem in CloudSyncProblem.allCases {
        #expect(!CloudSyncText.advice(for: problem).isEmpty)
    }
    #expect(CloudSyncText.advice(for: .network).contains("réseau"))
}

/// La page Profil ne parle de la synchronisation qu'après plus d'un jour d'échec sans réussite.
@Test func onlyADurableErrorReachesTheProfilePage() {
    var status = CloudSyncStatus()
    status.record(CloudSyncEvent(endDate: now.addingTimeInterval(-3_600), problem: .network))
    #expect(CloudSyncText.durableWarning(status, now: now) == nil)
    #expect(CloudSyncText.durableWarning(status, now: now.addingTimeInterval(86_400)) != nil)
    #expect(CloudSyncText.durableWarning(nil, now: now) == nil)
}
