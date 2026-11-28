import Foundation
import PulseDomain
import PulseRecoveryEngine

/// La dette de sommeil des 7 nuits qui finissent un matin donné, lue sur les nuits de l'écran Nuit (`NightSleep`) : le même
/// calcul que le facteur sommeil du score (`SleepDebt`). Les nuits absentes ne comptent pas.
public enum SleepDebtWindow {
    /// `day` : minuit local du jour de réveil de la dernière nuit. `nil` quand cette nuit-là n'est pas connue.
    public static func minutes(endingAt day: Date, nights: [NightSleep], goalMinutes: Int, calendar: Calendar) -> Int? {
        let ending = calendar.startOfDay(for: day)
        guard nights.contains(where: { calendar.isDate($0.day, inSameDayAs: ending) }) else { return nil }
        let window = nights.compactMap { night -> SleepDebt.Night? in
            guard let age = calendar.dateComponents([.day], from: calendar.startOfDay(for: night.day), to: ending).day,
                  (0..<SleepDebt.windowNights).contains(age) else { return nil }
            return SleepDebt.Night(age: age, asleepMinutes: night.asleepMinutes)
        }
        return SleepDebt.minutes(nights: window, goalMinutes: goalMinutes)
    }
}
