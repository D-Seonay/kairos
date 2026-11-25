import AppIntents
import Foundation
import PulseDomain
import PulseServices

/// Un complément de Pulse, pour Siri et l'app Raccourcis : son nom suffit à le désigner.
struct SupplementEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Complément"
    static let defaultQuery = SupplementEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ supplement: Supplement) {
        self.init(id: supplement.id, name: supplement.name)
    }
}

/// Les compléments non archivés, ceux du jour encore à prendre en premier (`SupplementShortcut`).
struct SupplementEntityQuery: EntityStringQuery {
    @Dependency private var dependencies: AppDependencies

    func entities(for identifiers: [UUID]) async throws -> [SupplementEntity] {
        let wanted = Set(identifiers)
        return try await supplements().filter { wanted.contains($0.id) }.map(SupplementEntity.init)
    }

    func suggestedEntities() async throws -> [SupplementEntity] {
        try await supplements().map(SupplementEntity.init)
    }

    func entities(matching string: String) async throws -> [SupplementEntity] {
        SupplementShortcut.matching(string, in: try await supplements()).map(SupplementEntity.init)
    }

    private func supplements() async throws -> [Supplement] {
        SupplementShortcut.suggestions(try await dependencies.supplementService.overview())
    }
}

/// « J'ai pris ma créatine » : coche le complément pour aujourd'hui, comme l'action « Pris » d'un rappel, sans ouvrir l'app. Le
/// stock, Apple Santé et les rappels suivent par le service des compléments. Demande le déverrouillage : on ne coche rien depuis
/// un iPhone verrouillé.
struct TakeSupplementIntent: AppIntent {
    static let title: LocalizedStringResource = "Cocher un complément"
    static let description = IntentDescription("Coche la prise du jour d'un complément dans Pulse.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Complément", requestValueDialog: IntentDialog("Quel complément as-tu pris ?"))
    var supplement: SupplementEntity

    @Dependency private var dependencies: AppDependencies
    @Dependency private var router: AppRouter

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = dependencies.supplementService
        let recorded = try await service.take(supplementID: supplement.id)
        let known = recorded ? [] : try await service.overview().supplements
        let outcome = SupplementShortcut.outcome(recorded: recorded, supplementID: supplement.id, known: known)
        if recorded { await router.supplementsChanged() }
        return .result(dialog: IntentDialog("\(ShortcutText.supplement(outcome, name: supplement.name))"))
    }
}
