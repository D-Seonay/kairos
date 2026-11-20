import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'état des compléments du jour (spec M5 §10), partagé par l'écran Compléments, la carte de l'accueil et celle du récap :
/// cocher d'un côté se voit de l'autre. Toutes les écritures passent par `SupplementService`.
@MainActor
@Observable
public final class SupplementsModel {
    /// Le formulaire ouvert : un nouveau complément, ou celui à modifier.
    public struct Editor: Identifiable, Equatable {
        public let id = UUID()
        public var supplement: Supplement?
    }

    public private(set) var overview: SupplementOverview
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false
    /// Vrai après la première lecture : avant, la carte de l'accueil ne montre pas d'état vide.
    public private(set) var hasLoaded = false
    public var editor: Editor?

    @ObservationIgnored let environment: SupplementsEnvironment
    /// Les compléments en cours d'écriture : une deuxième touche sur la même coche attend la première.
    @ObservationIgnored private var toggling: Set<UUID> = []

    public init(environment: SupplementsEnvironment) {
        self.environment = environment
        overview = .empty(day: environment.calendar.startOfDay(for: environment.now()))
    }

    /// « vendredi 20 novembre ».
    public var dateText: String {
        overview.day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
    }

    /// Relit les compléments du jour. Une lecture qui échoue garde l'affichage précédent et le dit.
    public func load() async {
        do {
            overview = try await environment.service.overview()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire tes compléments.", bundle: .module)
        }
        hasLoaded = true
    }

    /// Coche ou décoche le complément pour aujourd'hui.
    public func toggle(_ item: SupplementDueItem) async {
        let id = item.supplement.id
        guard toggling.insert(id).inserted else { return }
        defer { toggling.remove(id) }
        do {
            if item.isTaken {
                try await environment.service.untake(supplementID: id)
            } else {
                try await environment.service.take(supplementID: id)
            }
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer ta prise.", bundle: .module)
        }
        await load()
    }

    /// L'élément du jour d'un complément, à jour.
    public func item(for id: UUID) -> SupplementDueItem? {
        overview.items.first { $0.supplement.id == id }
    }

    /// Les compléments qui existent mais ne sont pas dus aujourd'hui.
    public var notDueToday: [Supplement] {
        let due = Set(overview.items.map(\.supplement.id))
        return overview.supplements.filter { !due.contains($0.id) }
    }

    /// Les moments du jour qui ont au moins un complément, dans l'ordre.
    public var moments: [(moment: SupplementMoment, items: [SupplementDueItem])] {
        SupplementMoment.allCases.compactMap { moment in
            let items = overview.items.filter { $0.moment == moment }
            return items.isEmpty ? nil : (moment, items)
        }
    }

    // MARK: - Formulaire

    public func startNew() {
        editor = Editor(supplement: nil)
    }

    public func edit(_ supplement: Supplement) {
        editor = Editor(supplement: supplement)
    }

    /// Enregistre le formulaire. La première fois, demande l'autorisation des notifications pour un rappel, et l'accès à Apple
    /// Santé pour un type. Vrai quand le complément est enregistré.
    public func save(_ draft: SupplementDraft, editing existing: Supplement?) async -> Bool {
        guard draft.problem == nil, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let order = existing == nil ? try await environment.service.nextOrder() : 0
            let supplement = draft.supplement(existing: existing, order: order, now: environment.now())
            if supplement.reminderEnabled {
                _ = await environment.notifications.requestAuthorization()
            }
            if supplement.healthType != nil, await environment.service.healthAccess() == .notDetermined {
                _ = await environment.service.requestHealthAccess()
            }
            try await environment.service.save(supplement)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer le complément.", bundle: .module)
            return false
        }
        editor = nil
        await load()
        return true
    }

    /// Archive le complément : il quitte la liste et ses rappels, ses prises restent dans l'export.
    public func archive(_ supplement: Supplement) async {
        do {
            try await environment.service.archive(id: supplement.id)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu archiver le complément.", bundle: .module)
        }
        editor = nil
        await load()
    }

    // MARK: - Textes

    /// « 2 sur 5 ».
    public var countText: String {
        String(localized: "\(overview.takenCount) sur \(overview.dueCount)", bundle: .module)
    }

    /// « 1 000 UI · 8:00 », la dose et l'heure prévue.
    public static func detail(_ item: SupplementDueItem) -> String {
        "\(SupplementText.dose(of: item.supplement)) · \(SupplementText.planned(item))"
    }

    /// « 85 % », ou « — » sans jour dû.
    public static func rateText(_ regularity: SupplementRegularity?) -> String {
        guard let rate = regularity?.rate else { return "—" }
        return (rate).formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: "fr_FR")))
    }

    /// « 38 doses ».
    public static func stockText(_ stock: Double) -> String {
        let value = SupplementText.number(stock)
        return stock == 1 ? String(localized: "1 dose", bundle: .module) : String(localized: "\(value) doses", bundle: .module)
    }
}
