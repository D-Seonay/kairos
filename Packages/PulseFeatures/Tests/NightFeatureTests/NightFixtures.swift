// swiftlint:disable force_unwrapping
import Foundation
import PulseDomain

/// Calendrier de Paris et nuits toutes faites pour les tests de l'écran Nuit.
enum NightFixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Les échantillons d'une nuit qui se réveille le jour donné : 23 h → 7 h, 90 min de profond à 1 h.
    static func samples(wakingOn year: Int, _ month: Int, _ day: Int, now: Date) -> [CachedHealthSample] {
        let wake = date(year, month, day)
        let bedtime = calendar.date(byAdding: .hour, value: -1, to: wake)!
        let deepStart = calendar.date(byAdding: .hour, value: 1, to: wake)!
        let deepEnd = deepStart.addingTimeInterval(90 * 60)
        let wakeUp = calendar.date(byAdding: .hour, value: 7, to: wake)!
        return [CachedHealthSample(kind: .sleep, start: bedtime, end: deepStart, sleepStage: .core, fetchedAt: now),
                CachedHealthSample(kind: .sleep, start: deepStart, end: deepEnd, sleepStage: .deep, fetchedAt: now),
                CachedHealthSample(kind: .sleep, start: deepEnd, end: wakeUp, sleepStage: .core, fetchedAt: now)]
    }

    /// La nuit du 19 au 20 novembre : 23:10 → 06:50, 450 min dont 90 profond, 60 paradoxal, 300 léger, 10 d'éveil.
    static func typicalNight(awakenings: Int = 1, hasStages: Bool = true, unspecified: Int = 0) -> NightSleep {
        NightSleep(day: date(2026, 11, 20), fellAsleep: date(2026, 11, 19, 23, 10), wokeUp: date(2026, 11, 20, 6, 50),
                   segments: [], otherBlocks: [], asleepMinutes: 450, deepMinutes: hasStages ? 90 : 0,
                   coreMinutes: hasStages ? 300 : 0, remMinutes: hasStages ? 60 : 0,
                   unspecifiedMinutes: hasStages ? unspecified : 450, awakeMinutes: 10, awakenings: awakenings,
                   hasStages: hasStages)
    }
}
// swiftlint:enable force_unwrapping
