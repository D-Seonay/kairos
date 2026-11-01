import Foundation
import Observation
import PulseContent
import PulseDomain
import PulsePersistence

/// Écran de debug M2 : contenu chargé, état du magasin, export, données d'exemple, suppression totale.
@MainActor
@Observable
final class DataDebugModel {
    let contentVersion: String
    let exerciseCount: Int
    let templateCount: Int
    let exercisesByPattern: [(pattern: MovementPattern, exercises: [Exercise])]
    let templates: [ProgramTemplate]
    let storeModeText: String
    private(set) var cloudStatus: CloudAccountStatus?
    private(set) var counts: [StoreTable: Int] = [:]
    private(set) var lastError: String?
    private(set) var isBusy = false
    private(set) var shareURL: URL?
    private(set) var didErase = false

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let content = dependencies.content
        contentVersion = content.contentVersion
        exerciseCount = content.exercises.count
        templateCount = content.programTemplates.count
        exercisesByPattern = MovementPattern.allCases.map { pattern in
            (pattern, content.exercises.filter { $0.pattern == pattern })
        }
        templates = content.programTemplates
        storeModeText = Self.text(for: dependencies.storeMode)
        lastError = dependencies.storeError
    }

    func exerciseName(for id: String) -> String? {
        dependencies.content.exercise(id: id)?.name.fr
    }

    func refresh() async {
        await run {
            counts = try await dependencies.inspector.counts()
            cloudStatus = await dependencies.inspector.cloudAccountStatus()
        }
    }

    func seedSampleData() async {
        await run {
            try await dependencies.seeder.seed(now: .now)
            counts = try await dependencies.inspector.counts()
        }
    }

    func exportJSON() async {
        await run { shareURL = try await dependencies.exporter.exportJSON() }
    }

    func exportCSV() async {
        await run { shareURL = try await dependencies.exporter.exportCSVArchive() }
    }

    func erase(includeAppleHealth: Bool) async {
        didErase = false
        shareURL = nil
        await run {
            do {
                try await dependencies.eraser.eraseEverything(options: EraseOptions(includeAppleHealth: includeAppleHealth))
            } catch {
                // Une partie a pu être effacée avant l'échec : les comptes affichés doivent le refléter.
                if let refreshed = try? await dependencies.inspector.counts() { counts = refreshed }
                throw error
            }
            counts = try await dependencies.inspector.counts()
            didErase = true
        }
    }

    /// Toute erreur devient un texte français dans `lastError` ; rien ne plante.
    private func run(_ work: () async throws -> Void) async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            lastError = String(localized: "L'opération a échoué : \(String(describing: error))")
        }
    }

    private static func text(for mode: StoreMode) -> String {
        switch mode {
        case .cloud: String(localized: "iCloud")
        case .localOnly: String(localized: "Local")
        case .inMemory: String(localized: "Mémoire")
        }
    }

    static func text(for status: CloudAccountStatus?) -> String {
        switch status {
        case .available?: String(localized: "Compte iCloud disponible")
        case .noAccount?: String(localized: "Aucun compte iCloud")
        case .restricted?: String(localized: "Compte iCloud restreint")
        case .unknown?: String(localized: "État iCloud inconnu")
        case nil: String(localized: "État iCloud non lu")
        }
    }
}
