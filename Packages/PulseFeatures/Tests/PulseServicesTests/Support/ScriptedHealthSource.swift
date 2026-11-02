import Foundation
import PulseDomain

/// Une source Apple Santé dont les réponses sont écrites d'avance, signal par signal, et qui garde les ancres qu'on lui a envoyées.
actor ScriptedHealthSource: HealthSampleSource {
    struct NothingQueued: Error {}

    private var queued: [NightSignal: [Result<HealthSampleChanges, any Error>]] = [:]
    private var anchors: [NightSignal: [Data?]] = [:]

    func enqueue(_ result: Result<HealthSampleChanges, any Error>, for signal: NightSignal) {
        queued[signal, default: []].append(result)
    }

    /// Les ancres reçues par `changes`, dans l'ordre des appels (`nil` : lecture sans ancre).
    func receivedAnchors(for signal: NightSignal) -> [Data?] {
        anchors[signal] ?? []
    }

    func requestAuthorization() async throws {}

    func profileHints() async throws -> HealthProfileHints {
        HealthProfileHints()
    }

    func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        anchors[signal, default: []].append(anchor)
        guard var queue = queued[signal], !queue.isEmpty else { throw NothingQueued() }
        let next = queue.removeFirst()
        queued[signal] = queue
        return try next.get()
    }
}
