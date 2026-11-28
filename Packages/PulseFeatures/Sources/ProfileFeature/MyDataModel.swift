import Foundation
import Observation
import PulseDesignSystem
import PulseDomain

/// L'état de l'écran Mes données (spec M7 §16) : ce que le téléphone stocke, l'état d'iCloud et les exports. La suppression
/// totale, elle, reste dans l'écran de confirmation de l'app.
@MainActor
@Observable
public final class MyDataModel {
    /// Enregistrements par table ; une table absente n'a pas pu être comptée.
    public private(set) var counts: [StoreTable: Int] = [:]
    public private(set) var cloudStatus: CloudAccountStatus?
    /// La dernière synchronisation iCloud réussie et la dernière erreur ; `nil` sans iCloud sur cet appareil.
    public private(set) var syncStatus: CloudSyncStatus?
    /// Le dernier export réussi, prêt pour la feuille de partage.
    public private(set) var shareURL: URL?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    /// Une lecture ou un export raté de plus : la même erreur revue est annoncée à nouveau.
    public private(set) var failureCount = 0
    /// Faux jusqu'à la première lecture : les comptes affichent « Pas encore lu » plutôt qu'un zéro.
    public private(set) var hasRefreshed = false

    @ObservationIgnored private let environment: ProfileEnvironment

    public init(environment: ProfileEnvironment) {
        self.environment = environment
    }

    /// Relit les comptes, l'état du compte iCloud et celui de la synchronisation. Une lecture qui échoue le dit et laisse les
    /// comptes tels quels.
    public func refresh() async {
        do {
            counts = try await environment.inspector.counts()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire tes données.", bundle: .module)
            failureCount += 1
        }
        cloudStatus = await environment.inspector.cloudAccountStatus()
        syncStatus = await environment.cloudSync.status()
        hasRefreshed = true
    }

    /// La phrase de la synchronisation sous celle du compte ; `nil` quand il n'y a rien à dire.
    public func syncText(now: Date) -> String? {
        CloudSyncText.status(syncStatus, account: cloudStatus, now: now)
    }

    /// Tout en JSON.
    public func exportJSON() async {
        await export { try await $0.exportJSON() }
    }

    /// Tout en CSV, un fichier par table, zippé.
    public func exportCSV() async {
        await export { try await $0.exportCSVArchive() }
    }

    /// Un export à la fois : un appel pendant un export est ignoré. Un export qui échoue ne laisse pas l'ancien fichier à partager.
    private func export(_ work: (any DataExporter) async throws -> URL) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        shareURL = nil
        errorMessage = nil
        do {
            shareURL = try await work(environment.exporter)
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu exporter tes données.", bundle: .module)
            failureCount += 1
        }
    }

    /// Le compte d'une table : « Pas encore lu » avant la première lecture, « — » pour une table qui n'a pas pu être comptée,
    /// jamais un zéro inventé.
    public static func countText(_ count: Int?, hasRefreshed: Bool) -> String {
        guard hasRefreshed else { return String(localized: "Pas encore lu", bundle: .module) }
        return count.map { PulseFormat.integer(Double($0), unit: nil) } ?? "\u{2014}"
    }

    /// Ce que VoiceOver lit du compte : « indisponible » à la place du tiret.
    public static func countSpoken(_ count: Int?, hasRefreshed: Bool) -> String {
        guard hasRefreshed, count == nil else { return countText(count, hasRefreshed: hasRefreshed) }
        return String(localized: "indisponible", bundle: .module)
    }

    /// La phrase qui accompagne l'état du compte iCloud ; « Pas encore lu » avant la première lecture.
    public static func cloudText(_ status: CloudAccountStatus?) -> String {
        switch status {
        case .available?: String(localized: """
            Tes séances, compléments et scores se synchronisent avec ton compte iCloud. \
            Les données d'Apple Santé restent sur ce téléphone.
            """, bundle: .module)
        case .noAccount?: String(localized: "Aucun compte iCloud : tes données restent sur ce téléphone.", bundle: .module)
        case .restricted?: String(localized: "Le compte iCloud est restreint : la synchronisation est coupée.", bundle: .module)
        case .unknown?: String(localized: "État iCloud inconnu.", bundle: .module)
        case nil: String(localized: "Pas encore lu", bundle: .module)
        }
    }
}
