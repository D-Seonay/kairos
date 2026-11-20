import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'écran du mois et de la série (spec M6 §5, §6) : la grille d'un mois, du mois de la première activité au mois suivant
/// le mois courant, et le pilier de série.
@MainActor
@Observable
public final class MonthModel {
    public private(set) var month: Date
    public private(set) var grid: MonthGrid?
    public private(set) var errorMessage: String?
    public let streak: StreakSummary?

    @ObservationIgnored private let environment: PlanningEnvironment
    @ObservationIgnored private let earliest: Date
    @ObservationIgnored private let latest: Date

    public init(environment: PlanningEnvironment, streak: StreakSummary?, historyStart: Date?) {
        self.environment = environment
        self.streak = streak
        let calendar = environment.calendar
        let current = MonthCalendar.monthStart(of: environment.now(), calendar: calendar)
        month = current
        earliest = historyStart.map { min(MonthCalendar.monthStart(of: $0, calendar: calendar), current) } ?? current
        latest = calendar.date(byAdding: .month, value: 1, to: current) ?? current
    }

    public var canGoBack: Bool { month > earliest }

    public var canGoForward: Bool { month < latest }

    public func load() async {
        do {
            grid = try await environment.service.month(month)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire ce mois.", bundle: .module)
        }
    }

    /// Passe au mois précédent (`-1`) ou suivant (`1`), dans les bornes, puis le lit.
    public func show(offset: Int) async {
        guard let target = environment.calendar.date(byAdding: .month, value: offset, to: month),
              target >= earliest, target <= latest else { return }
        month = target
        await load()
    }

    /// « novembre 2026 ».
    public var title: String {
        environment.text(of: month) { $0.month(.wide).year() }
    }

    /// « L M M J V S D ».
    public var weekdaySymbols: [String] {
        [String(localized: "L", bundle: .module), String(localized: "M", bundle: .module), String(localized: "M", bundle: .module),
         String(localized: "J", bundle: .module), String(localized: "V", bundle: .module), String(localized: "S", bundle: .module),
         String(localized: "D", bundle: .module)]
    }

    /// « 18 ».
    public func number(of day: MonthDay) -> String {
        environment.text(of: day.date) { $0.day() }
    }

    /// « mercredi 18 novembre, musculation faite, record ».
    public func accessibilityText(of day: MonthDay) -> String {
        var parts = [environment.text(of: day.date) { $0.weekday(.wide).day().month(.wide) }]
        if day.isToday { parts.append(String(localized: "aujourd'hui", bundle: .module)) }
        for kind in day.done {
            switch kind {
            case .strength: parts.append(String(localized: "musculation faite", bundle: .module))
            case .run: parts.append(String(localized: "course faite", bundle: .module))
            case .ride: parts.append(String(localized: "vélo fait", bundle: .module))
            }
        }
        switch day.planned {
        case .strength: parts.append(String(localized: "musculation prévue", bundle: .module))
        case .run: parts.append(String(localized: "course prévue", bundle: .module))
        case nil: break
        }
        if day.hasMark { parts.append(String(localized: "deux séances ou record", bundle: .module)) }
        return parts.joined(separator: ", ")
    }

    /// « 3 sur 5 cette semaine ».
    public var currentWeekText: String {
        guard let week = streak?.currentWeek else { return "" }
        return String(localized: "\(week.count) sur \(week.target) cette semaine", bundle: .module)
    }
}
