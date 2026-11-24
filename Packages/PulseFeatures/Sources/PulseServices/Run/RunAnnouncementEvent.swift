import Foundation
import PulseDomain

/// Ce que la course annonce à voix haute : un km passé, la moitié de l'objectif, l'objectif atteint.
public enum RunAnnouncementEvent: Sendable, Equatable {
    case kilometer(Int, movingSeconds: Int, splitSeconds: Int)
    case halfTarget
    case targetReached

    /// Les événements à dire quand la course passe de `previous` à `current` (progression d'objectif et km).
    /// Un km passé vient avant `halfTarget` et `targetReached`.
    public static func events(kilometer: Int?, splits: [RunSplit], movingSeconds: Double,
                              previousProgress: Double?, progress: Double?) -> [RunAnnouncementEvent] {
        var events: [RunAnnouncementEvent] = []
        if let kilometer, kilometer >= 1, splits.indices.contains(kilometer - 1) {
            events.append(.kilometer(
                kilometer, movingSeconds: Int(movingSeconds.rounded()), splitSeconds: Int(splits[kilometer - 1].seconds.rounded())))
        }
        if let previousProgress, let progress {
            if previousProgress < 0.5, progress >= 0.5 { events.append(.halfTarget) }
            if previousProgress < 1, progress >= 1 { events.append(.targetReached) }
        }
        return events
    }
}
