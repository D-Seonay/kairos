import CloudKit
import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

private func cloudKitError(_ code: CKError.Code, userInfo: [String: Any] = [:]) -> NSError {
    NSError(domain: CKErrorDomain, code: code.rawValue, userInfo: userInfo)
}

@Test func commonCloudKitErrorsAreClassified() {
    #expect(CloudSyncErrorClassifier.classify(cloudKitError(.quotaExceeded)) == .quotaExceeded)
    #expect(CloudSyncErrorClassifier.classify(cloudKitError(.notAuthenticated)) == .noAccount)
    #expect(CloudSyncErrorClassifier.classify(cloudKitError(.accountTemporarilyUnavailable)) == .noAccount)
    #expect(CloudSyncErrorClassifier.classify(cloudKitError(.networkUnavailable)) == .network)
    #expect(CloudSyncErrorClassifier.classify(cloudKitError(.networkFailure)) == .network)
    #expect(CloudSyncErrorClassifier.classify(cloudKitError(.serviceUnavailable)) == .network)
    #expect(CloudSyncErrorClassifier.classify(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) == .network)
    #expect(CloudSyncErrorClassifier.classify(cloudKitError(.serverRejectedRequest)) == .other)
    #expect(CloudSyncErrorClassifier.classify(nil) == .other)
}

/// Core Data enveloppe l'erreur CloudKit ; un échec partiel prend la cause la plus parlante de ses enregistrements.
@Test func wrappedAndPartialErrorsAreReadThrough() {
    let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134_419, userInfo: [NSUnderlyingErrorKey: cloudKitError(.quotaExceeded)])
    #expect(CloudSyncErrorClassifier.classify(wrapped) == .quotaExceeded)
    let noAccount = NSError(domain: NSCocoaErrorDomain, code: CloudSyncErrorClassifier.missingAccountCoreDataCode)
    #expect(CloudSyncErrorClassifier.classify(noAccount) == .noAccount)
    let recordID = CKRecord.ID(recordName: "a")
    let partialQuota = cloudKitError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [
        recordID: cloudKitError(.serverRecordChanged), CKRecord.ID(recordName: "b"): cloudKitError(.quotaExceeded)
    ]])
    #expect(CloudSyncErrorClassifier.classify(partialQuota) == .quotaExceeded)
    let partial = cloudKitError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: cloudKitError(.serverRecordChanged)]])
    #expect(CloudSyncErrorClassifier.classify(partial) == .partialFailure)
}

/// L'état survit à une relance : il est relu dans les préférences.
@Test func theMonitorKeepsItsStatusAcrossLaunches() async throws {
    let suite = "fr.seonay.pulse.tests.sync.\(UUID().uuidString)"
    defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    let monitor = CloudKitSyncMonitor(suiteName: suite, center: nil)
    #expect(await monitor.status() == CloudSyncStatus())
    monitor.record(CloudSyncEvent(endDate: Fixed.t0, problem: nil))
    monitor.record(CloudSyncEvent(endDate: Fixed.t1, problem: .network))
    let relaunched = CloudKitSyncMonitor(suiteName: suite, center: nil)
    let status = try #require(await relaunched.status())
    #expect(status.lastSuccess == Fixed.t0 && status.lastError == .network && status.failingSince == Fixed.t1)
}
