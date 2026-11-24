#if DEBUG
import Foundation
import PulseDomain
import PulseServices
import SwiftUI

// swiftlint:disable force_unwrapping
/// Des nuits d'aperçu, écrites dans un cache en mémoire : la typique (avec un réveil), une sans phases, une avec sieste.
@MainActor
enum NightPreviewSupport {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9))!

    enum Kind {
        case typical
        case unstaged
        case nap
    }

    private static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private static func samples(_ kind: Kind) -> [CachedHealthSample] {
        func sample(_ start: Date, _ end: Date, _ stage: SleepStage) -> CachedHealthSample {
            CachedHealthSample(kind: .sleep, start: start, end: end, sleepStage: stage, fetchedAt: now)
        }
        switch kind {
        case .unstaged:
            return [sample(at(19, 23, 5), at(20, 3, 10), .asleepUnspecified), sample(at(20, 3, 10), at(20, 3, 25), .awake),
                    sample(at(20, 3, 25), at(20, 6, 55), .asleepUnspecified)]
        case .typical, .nap:
            let nap = kind == .nap ? [sample(at(19, 18, 5), at(19, 18, 30), .core)] : []
            return nap + [
                sample(at(19, 23, 10), at(20, 1, 0), .core), sample(at(20, 1, 0), at(20, 2, 30), .deep),
                sample(at(20, 2, 30), at(20, 3, 30), .rem), sample(at(20, 3, 30), at(20, 3, 40), .awake),
                sample(at(20, 3, 40), at(20, 5, 0), .core), sample(at(20, 5, 0), at(20, 5, 50), .rem),
                sample(at(20, 5, 50), at(20, 6, 50), .core)
            ]
        }
    }

    static func model(_ kind: Kind) -> NightModel {
        let now = now
        let service = NightDetailService(cache: FixedSleepCache(stored: samples(kind)), calendar: calendar, now: { now })
        return NightModel(service: service, initialDay: now, calendar: calendar)
    }
}

/// Un cache figé, rempli dès sa création : l'aperçu n'attend aucune écriture.
private struct FixedSleepCache: HealthSampleCache {
    let stored: [CachedHealthSample]

    func samples(kind: HealthSampleKind, from: Date, to: Date) async throws -> [CachedHealthSample] {
        stored.filter { $0.kind == kind && $0.start >= from && $0.start < to }
    }

    func insert(_ samples: [CachedHealthSample]) async throws {}
    func apply(_ changes: HealthSampleChanges) async throws {}
    func anchor(for kind: HealthSampleKind) async throws -> Data? { nil }
    func saveAnchor(_ data: Data, for kind: HealthSampleKind) async throws {}
    func clear() async throws {}
}
// swiftlint:enable force_unwrapping

#Preview("Nuit typique") {
    NavigationStack { NightScreen(model: NightPreviewSupport.model(.typical)) }
}

#Preview("Nuit sans phases") {
    NavigationStack { NightScreen(model: NightPreviewSupport.model(.unstaged)) }
}

#Preview("Nuit avec sieste") {
    NavigationStack { NightScreen(model: NightPreviewSupport.model(.nap)) }
}

#Preview("Nuit, accessibilité 3") {
    NavigationStack { NightScreen(model: NightPreviewSupport.model(.typical)) }
        .dynamicTypeSize(.accessibility3)
}
#endif
