import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'état de l'écran Nuit (spec sommeil §6.3) : les nuits du cache et celle affichée. ‹ et › passent à la nuit voisine qui a
/// des données ; les nuits sans sommeil ne sont jamais dans la liste.
@MainActor
@Observable
public final class NightModel {
    private(set) var details: [NightDetail] = []
    private(set) var index: Int?
    private(set) var hasLoaded = false
    /// L'objectif de sommeil du profil, lu à chaque `load()` ; l'objectif par défaut avant.
    private(set) var goalMinutes = SleepGoal.defaultMinutes

    @ObservationIgnored private let service: NightDetailService
    @ObservationIgnored private let initialDay: Date?
    @ObservationIgnored let calendar: Calendar

    /// `initialDay` : un instant du jour de réveil à ouvrir ; sans nuit ce jour-là (ou sans jour), la plus récente.
    public init(service: NightDetailService, initialDay: Date?, calendar: Calendar) {
        self.service = service
        self.initialDay = initialDay
        self.calendar = calendar
    }

    var current: NightDetail? {
        index.map { details[$0] }
    }

    var canGoBack: Bool {
        index.map { $0 > 0 } ?? false
    }

    var canGoForward: Bool {
        index.map { $0 < details.count - 1 } ?? false
    }

    /// La nuit que ‹ ouvrirait, pour le libellé VoiceOver du bouton.
    var previous: NightDetail? {
        guard let index, index > 0 else { return nil }
        return details[index - 1]
    }

    /// La nuit que › ouvrirait.
    var next: NightDetail? {
        guard let index, index < details.count - 1 else { return nil }
        return details[index + 1]
    }

    public func load() async {
        details = await service.nights()
        goalMinutes = await service.sleepGoalMinutes()
        let wanted = initialDay.map { calendar.startOfDay(for: $0) }
        index = details.firstIndex { $0.night.day == wanted } ?? (details.isEmpty ? nil : details.count - 1)
        hasLoaded = true
    }

    func goBack() {
        guard canGoBack, let index else { return }
        self.index = index - 1
    }

    func goForward() {
        guard canGoForward, let index else { return }
        self.index = index + 1
    }
}
