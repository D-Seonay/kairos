import Foundation

/// Le minuteur de la séance de mobilité : vingt minutes, pausable. Pur : chaque date est un paramètre, aucune horloge n'est lue ici.
struct MobilityTimer: Sendable, Equatable {
    static let duration: TimeInterval = 1200

    enum Phase: Sendable, Equatable {
        case ready
        case running(since: Date, elapsedBefore: TimeInterval)
        case paused(elapsed: TimeInterval)
        case finished
    }

    private(set) var phase: Phase

    init() {
        phase = .ready
    }

    /// Lance le minuteur, ou le reprend après une pause ; sans effet dans les autres phases.
    mutating func start(at date: Date) {
        switch phase {
        case .ready: phase = .running(since: date, elapsedBefore: 0)
        case .paused(let elapsed): phase = .running(since: date, elapsedBefore: elapsed)
        case .running, .finished: break
        }
    }

    /// Fige le temps écoulé ; sans effet hors d'un minuteur en marche.
    mutating func pause(at date: Date) {
        guard case .running = phase else { return }
        phase = .paused(elapsed: elapsed(at: date))
    }

    /// Termine tout de suite, quel que soit le temps restant.
    mutating func finish() {
        phase = .finished
    }

    /// Le temps restant, borné entre 0 et vingt minutes.
    func remaining(at date: Date) -> TimeInterval {
        phase == .finished ? 0 : max(0, Self.duration - elapsed(at: date))
    }

    func isOver(at date: Date) -> Bool {
        phase == .finished || remaining(at: date) <= 0
    }

    /// « 18:55 » : les secondes entamées comptent en entier, donc 0,4 s s'écrit « 00:01 ».
    static func clockText(_ remaining: TimeInterval) -> String {
        let seconds = Int(max(0, min(remaining, duration)).rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func elapsed(at date: Date) -> TimeInterval {
        switch phase {
        case .ready: 0
        case .running(let since, let elapsedBefore): elapsedBefore + max(0, date.timeIntervalSince(since))
        case .paused(let elapsed): elapsed
        case .finished: Self.duration
        }
    }
}
