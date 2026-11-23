import Foundation
import PulseDomain

/// Le temps d'une course, pauses retirées.
public enum RunClock {
    /// Secondes en mouvement entre `start` et `date`, pauses retirées (une pause ouverte court jusqu'à `date`).
    public static func movingSeconds(from start: Date, pauses: [RunPause], at date: Date) -> Double {
        var seconds = date.timeIntervalSince(start)
        for pause in pauses {
            let from = max(pause.start, start)
            let until = min(pause.end ?? date, date)
            if until > from { seconds -= until.timeIntervalSince(from) }
        }
        return max(0, seconds)
    }
}
