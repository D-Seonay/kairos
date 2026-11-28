import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Ce que l'écran « Pourquoi » dit du calcul du jour, relu à la volée depuis les nuits : nuits de la ligne de base VFC (et
/// celles écartées), origine de la FC de repos, dette de sommeil. Rien n'est enregistré : après le figement de midi, la lecture
/// suit les nuits du cache, pas le score figé.
public enum TodayInsight {
    public static func make(nights: [NightSample], now: Date, sleepGoalMinutes: Int, calendar: Calendar) -> RecoveryInsight {
        let day = calendar.startOfDay(for: now)
        let tonight = nights.first { calendar.isDate($0.day, inSameDayAs: day) }
            ?? NightSample(day: day, sdnnMs: nil, restingHeartRate: nil, sleep: nil)
        let history = nights.filter { !calendar.isDate($0.day, inSameDayAs: day) }
        return RecoveryCalculator(calendar: calendar)
            .insight(day: day, today: tonight, history: history, sleepGoalMinutes: sleepGoalMinutes)
    }
}
