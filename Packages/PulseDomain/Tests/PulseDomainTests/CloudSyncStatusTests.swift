import Foundation
import PulseDomain
import Testing

private let t0 = Date(timeIntervalSince1970: 1_794_700_000)

@Test func aSuccessClearsTheError() {
    var status = CloudSyncStatus()
    status.record(CloudSyncEvent(endDate: t0, problem: .network))
    #expect(status.lastError == .network && status.failingSince == t0 && status.lastSuccess == nil)
    status.record(CloudSyncEvent(endDate: t0.addingTimeInterval(60), problem: nil))
    #expect(status.lastSuccess == t0.addingTimeInterval(60))
    #expect(status.lastError == nil && status.lastErrorAt == nil && status.failingSince == nil)
}

/// Une série d'échecs garde la date du premier : l'erreur devient durable après 24 h sans succès.
@Test func anErrorBecomesDurableAfterADayWithoutSuccess() {
    var status = CloudSyncStatus(lastSuccess: t0.addingTimeInterval(-3_600))
    status.record(CloudSyncEvent(endDate: t0, problem: .quotaExceeded))
    status.record(CloudSyncEvent(endDate: t0.addingTimeInterval(3_600), problem: .partialFailure))
    #expect(status.failingSince == t0 && status.lastError == .partialFailure)
    #expect(!status.isDurableError(at: t0.addingTimeInterval(23 * 3_600)))
    #expect(status.isDurableError(at: t0.addingTimeInterval(24 * 3_600)))
    #expect(!CloudSyncStatus(lastSuccess: t0).isDurableError(at: t0.addingTimeInterval(100 * 3_600)))
}

/// Un événement plus ancien que le dernier connu (notifications reçues dans le désordre) ne fait pas reculer l'état.
@Test func anOlderEventDoesNotRewindTheStatus() {
    var status = CloudSyncStatus()
    status.record(CloudSyncEvent(endDate: t0, problem: nil))
    status.record(CloudSyncEvent(endDate: t0.addingTimeInterval(-60), problem: .network))
    #expect(status.lastSuccess == t0 && status.lastError == nil)
}

@Test func theStatusRoundTripsThroughJSON() throws {
    var status = CloudSyncStatus(lastSuccess: t0)
    status.record(CloudSyncEvent(endDate: t0.addingTimeInterval(10), problem: .noAccount))
    let decoded = try JSONDecoder().decode(CloudSyncStatus.self, from: JSONEncoder().encode(status))
    #expect(decoded == status)
}
