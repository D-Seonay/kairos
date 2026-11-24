import Foundation
import Observation
import PulseDesignSystem
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
    /// L'erreur du formulaire ouvert (un enregistrement raté), affichée dans le formulaire plutôt que derrière lui.
    public private(set) var editorError: String?
    public private(set) var isSaving = false
    /// Vrai après la première lecture : avant, la carte de l'accueil ne montre pas d'état vide.
    public private(set) var hasLoaded = false
    public var editor: Editor?

    @ObservationIgnored let environment: SupplementsEnvironment
    /// Dit une phrase à VoiceOver (une prise, un archivage, une erreur) ; les tests la remplacent. Le modèle est partagé par l'écran,
    /// la carte de l'accueil et le récap : l'annonce part une seule fois, d'ici.
    @ObservationIgnored var announce: @MainActor (_ text: String, _ isError: Bool) -> Void = { text, isError in
        PulseAnnouncement.post(text, isError: isError)
    }
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
    /// `announcesFailure` dit l'erreur à VoiceOver : seul l'écran Compléments, qui l'affiche, le demande. La carte de l'accueil et les
    /// relectures qui suivent une écriture restent muettes (l'écriture dit déjà son erreur).
    public func load(announcesFailure: Bool = false) async {
        do {
            overview = try await environment.service.overview()
            errorMessage = nil
        } catch {
            fail(String(localized: "Pulse n'a pas pu lire tes compléments.", bundle: .module), announces: announcesFailure)
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
            fail(String(localized: "Pulse n'a pas pu enregistrer ta prise.", bundle: .module))
            await load()
            return
        }
        await load()
        // L'élément du jour, à jour : le bouton qu'on vient de toucher a peut-être disparu (la prochaine prise le remplace).
        if let updated = self.item(for: id), updated.isTaken != item.isTaken {
            announce(Self.takenAnnouncement(item: updated, taken: overview.takenCount, due: overview.dueCount), false)
        }
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
        editorError = nil
        editor = Editor(supplement: nil)
    }

    public func edit(_ supplement: Supplement) {
        editorError = nil
        editor = Editor(supplement: supplement)
    }

    /// Enregistre le formulaire. La première fois, demande l'autorisation des notifications pour un rappel, et l'accès à Apple
    /// Santé pour un type. Vrai quand le complément est enregistré ; un échec garde le formulaire ouvert avec `editorError`.
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
            let message = String(localized: "Pulse n'a pas pu enregistrer le complément.", bundle: .module)
            editorError = message
            announce(message, true)
            return false
        }
        editorError = nil
        editor = nil
        await load()
        return true
    }

    /// Archive le complément : il quitte la liste et ses rappels, ses prises restent dans l'export.
    public func archive(_ supplement: Supplement) async {
        do {
            try await environment.service.archive(id: supplement.id)
            errorMessage = nil
            announce(Self.archivedAnnouncement(supplement.name), false)
        } catch {
            fail(String(localized: "Pulse n'a pas pu archiver le complément.", bundle: .module))
        }
        editor = nil
        await load()
    }

    /// Affiche l'erreur et l'annonce, chaque fois : la même erreur deux fois de suite est dite deux fois.
    private func fail(_ message: String, announces: Bool = true) {
        errorMessage = message
        if announces { announce(message, true) }
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

    /// « 1 000 unités internationales, à 8 heures » : la dose et l'heure prévue, dites.
    public static func detailSpoken(_ item: SupplementDueItem) -> String {
        let dose = SupplementLabels.doseSpoken(item.supplement.dose, unit: item.supplement.unit)
        return "\(dose), \(SupplementLabels.plannedSpoken(item))"
    }

    /// « Vitamine D3, 1 000 unités internationales, Jours d'entraînement » : la ligne d'un complément pas prévu aujourd'hui.
    static func notDueRowSpoken(_ supplement: Supplement, days: String) -> String {
        "\(supplement.name), \(notDueSpoken(supplement, days: days))"
    }

    /// « Prochaine prise, Vitamine D3, 1 000 unités internationales, à 8 heures ».
    static func nextIntakeSpoken(_ item: SupplementDueItem) -> String {
        String(localized: "Prochaine prise, \(item.supplement.name), \(detailSpoken(item))", bundle: .module)
    }

    /// « 1 000 unités internationales, Jours d'entraînement » : un complément pas prévu aujourd'hui.
    public static func notDueSpoken(_ supplement: Supplement, days: String) -> String {
        "\(SupplementLabels.doseSpoken(supplement.dose, unit: supplement.unit)), \(days)"
    }

    /// « Pris » ou « Pas pris » : la valeur de la coche d'un complément.
    static func takenValue(_ isTaken: Bool) -> String {
        isTaken ? String(localized: "Pris", bundle: .module) : String(localized: "Pas pris", bundle: .module)
    }

    /// « Vitamine D3, 1 000 unités internationales, à 8 heures, pris » : la ligne d'un complément, son état avec.
    static func rowSpoken(_ item: SupplementDueItem) -> String {
        var parts = [item.supplement.name, detailSpoken(item), takenValue(item.isTaken).lowercased()]
        if item.supplement.isLowOnStock { parts.append(String(localized: "stock bas", bundle: .module)) }
        return parts.joined(separator: ", ")
    }

    /// « 2 sur 5 pris ».
    static func summarySpoken(taken: Int, due: Int) -> String {
        String(localized: "\(PulseSpoken.outOf(taken, due)) pris", bundle: .module)
    }

    /// « Vitamine D3 pris. 3 sur 5 pris. » ; décochée, « Vitamine D3, pas pris. 2 sur 5 pris. ». `item` est l'élément après la
    /// touche, `taken` et `due` les comptes du jour après elle.
    static func takenAnnouncement(item: SupplementDueItem, taken: Int, due: Int) -> String {
        let name = item.supplement.name
        let count = summarySpoken(taken: taken, due: due)
        guard item.isTaken else { return String(localized: "\(name), pas pris. \(count).", bundle: .module) }
        let sentence = String(localized: "\(name) pris. \(count).", bundle: .module)
        guard due > 0, taken == due else { return sentence }
        return "\(sentence) \(String(localized: "Tout est pris pour aujourd'hui.", bundle: .module))"
    }

    /// « Whey archivé. »
    static func archivedAnnouncement(_ name: String) -> String {
        String(localized: "\(name) archivé.", bundle: .module)
    }

    /// « 85 pour cent », ou « pas encore de jour prévu » : la régularité dite.
    static func rateSpoken(_ regularity: SupplementRegularity?) -> String {
        guard let rate = regularity?.rate else { return String(localized: "pas encore de jour prévu", bundle: .module) }
        return String(localized: "\(Int((rate * 100).rounded())) pour cent", bundle: .module)
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
