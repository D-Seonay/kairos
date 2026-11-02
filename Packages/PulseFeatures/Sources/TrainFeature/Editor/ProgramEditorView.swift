import PulseDesignSystem
import PulseDomain
import SwiftUI

/// L'éditeur de programme (spec M4 §11.1) : son nom, la semaine type, ses routines, puis les autres programmes et les modèles à
/// adopter. À présenter dans la pile de l'onglet « Séance », qui ouvre l'éditeur d'une routine au toucher.
public struct ProgramEditorView: View {
    @State private var model: ProgramEditorModel
    @State private var prompt: NamePrompt?
    @State private var promptText = ""
    @State private var removal: RoutineDay?
    @State private var adoption: ProgramTemplateChoice?
    @State private var isArchiving = false
    @State private var errorMessage: String?

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: ProgramEditorModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        List {
            if let message = errorMessage ?? model.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
            if let program = model.program {
                activeProgram(program)
            } else {
                Section {
                    Text(String(localized: "Aucun programme actif. Adopte un modèle ou crée un programme vide.", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
                .listRowBackground(PulsePalette.surface)
            }
            otherPrograms
            templates
        }
        .scrollContentBackground(.hidden)
        .background(PulsePalette.background)
        .navigationTitle(String(localized: "Mon programme", bundle: .module))
        .pulseInlineTitle()
        .alert(prompt?.title ?? "", isPresented: isPrompting) {
            TextField(prompt?.placeholder ?? "", text: $promptText)
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
            Button(prompt?.confirmation ?? "") { confirm(prompt, text: promptText) }
        }
        .confirmationDialog(removalTitle, isPresented: isRemoving, titleVisibility: .visible, presenting: removal) { routine in
            Button(String(localized: "Supprimer", bundle: .module), role: .destructive) { perform { try await model.remove(routine.id) } }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: { _ in
            Text(String(localized: "Elle sort aussi de la semaine. Tes anciennes séances la gardent.", bundle: .module))
        }
        .confirmationDialog(adoptionTitle, isPresented: isAdopting, titleVisibility: .visible, presenting: adoption) { choice in
            Button(String(localized: "Adopter", bundle: .module)) { perform { try await model.adopt(choice.id) } }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: { _ in
            Text(String(localized: "Le modèle devient ton programme actif ; l'actuel reste dans tes programmes.", bundle: .module))
        }
        .confirmationDialog(String(localized: "Archiver ce programme ?", bundle: .module), isPresented: $isArchiving,
                            titleVisibility: .visible) {
            Button(String(localized: "Archiver", bundle: .module), role: .destructive) {
                if let id = model.program?.id { perform { try await model.archive(id) } }
            }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: {
            Text(String(localized: "Il ne sera plus actif ni proposé, mais tes séances le gardent.", bundle: .module))
        }
        .task { await model.load() }
    }

    // MARK: - Programme actif

    @ViewBuilder
    private func activeProgram(_ program: Program) -> some View {
        Section {
            Button { ask(.rename, text: program.name) } label: {
                LabeledRow(title: program.name, detail: summary(of: program), systemImage: "pencil")
            }
            .accessibilityHint(String(localized: "Renomme le programme", bundle: .module))
        } header: {
            Text(String(localized: "Programme actif", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
        Section {
            WeekAssignmentView(program: program) { dayID, weekday in
                perform { try await model.assign(dayID, to: weekday) }
            }
        } header: {
            Text(String(localized: "Semaine", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
        routines(of: program)
        Section {
            Button(String(localized: "Archiver ce programme", bundle: .module), role: .destructive) { isArchiving = true }
                .frame(minHeight: 44)
        }
        .listRowBackground(PulsePalette.surface)
    }

    private func routines(of program: Program) -> some View {
        Section {
            ForEach(program.days.sorted { $0.order < $1.order }) { day in
                routineRow(day, in: program)
            }
            Button { ask(.newRoutine, text: "") } label: {
                Label(String(localized: "Ajouter une routine", bundle: .module), systemImage: "plus")
            }
            .frame(minHeight: 44)
            NavigationLink(value: TrainDestination.history) {
                Label(String(localized: "Depuis une séance passée", bundle: .module), systemImage: "clock.arrow.circlepath")
            }
            .frame(minHeight: 44)
            .accessibilityHint(String(localized: "Ouvre l'historique : choisis une séance à enregistrer comme routine", bundle: .module))
            .accessibilityIdentifier(TrainIdentifiers.routineFromSession)
        } header: {
            Text(String(localized: "Routines", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    @ViewBuilder
    private func routineRow(_ day: RoutineDay, in program: Program) -> some View {
        if day.kind == .run {
            LabeledRow(title: day.name, detail: String(localized: "Course · modifiable plus tard", bundle: .module),
                       systemImage: "lock.fill")
                .accessibilityElement(children: .combine)
        } else {
            NavigationLink(value: TrainDestination.routine(program: program.id, day: day.id)) {
                LabeledRow(title: day.name, detail: String(localized: "\(day.exercises.count) exercices", bundle: .module),
                           systemImage: nil)
            }
            .swipeActions(edge: .trailing) {
                Button(String(localized: "Supprimer", bundle: .module), role: .destructive) { removal = day }
                Button(String(localized: "Dupliquer", bundle: .module)) { perform { try await model.duplicate(day.id) } }
                    .tint(PulsePalette.muted)
            }
            .contextMenu {
                Button(String(localized: "Dupliquer", bundle: .module), systemImage: "plus.square.on.square") {
                    perform { try await model.duplicate(day.id) }
                }
                Button(String(localized: "Supprimer", bundle: .module), systemImage: "trash", role: .destructive) { removal = day }
            }
        }
    }

    // MARK: - Autres programmes et modèles

    private var otherPrograms: some View {
        Section {
            ForEach(model.otherPrograms) { other in
                Button { perform { try await model.activate(other.id) } } label: {
                    LabeledRow(title: other.name, detail: summary(of: other), systemImage: "arrow.triangle.swap")
                }
                .accessibilityHint(String(localized: "Rend ce programme actif", bundle: .module))
                .swipeActions(edge: .trailing) {
                    Button(String(localized: "Archiver", bundle: .module), role: .destructive) {
                        perform { try await model.archive(other.id) }
                    }
                }
            }
            Button { ask(.newProgram, text: "") } label: {
                Label(String(localized: "Créer un programme vide", bundle: .module), systemImage: "plus")
            }
            .frame(minHeight: 44)
        } header: {
            Text(String(localized: "Mes programmes", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var templates: some View {
        Section {
            ForEach(model.templates) { template in
                Button { adoption = ProgramTemplateChoice(id: template.id, name: template.name.fr) } label: {
                    LabeledRow(title: template.name.fr, detail: template.summary.fr, systemImage: "square.and.arrow.down")
                }
                .accessibilityHint(String(localized: "Adopte ce modèle comme programme actif", bundle: .module))
            }
        } header: {
            Text(String(localized: "Modèles", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    // MARK: - Actions

    private func summary(of program: Program) -> String {
        [String(localized: "\(program.days.count) routines", bundle: .module),
         String(localized: "\(program.sessionsPerWeek) séances par semaine", bundle: .module)].joined(separator: " · ")
    }

    private func ask(_ kind: NamePrompt, text: String) {
        promptText = text
        prompt = kind
    }

    private func confirm(_ kind: NamePrompt?, text: String) {
        guard let kind else { return }
        perform {
            switch kind {
            case .rename: try await model.rename(text)
            case .newRoutine: _ = try await model.addRoutine(named: routineName(text))
            case .newProgram: try await model.createEmpty(named: text)
            }
        }
    }

    private func routineName(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Nouvelle routine", bundle: .module) : trimmed
    }

    /// Lance une modification ; si elle échoue, l'écran garde son état et affiche une erreur.
    private func perform(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                errorMessage = nil
            } catch {
                errorMessage = String(localized: "Pulse n'a pas pu enregistrer cette modification.", bundle: .module)
            }
        }
    }

    // MARK: - Boîtes de dialogue

    private var isPrompting: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })
    }

    private var isRemoving: Binding<Bool> {
        Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })
    }

    private var isAdopting: Binding<Bool> {
        Binding(get: { adoption != nil }, set: { if !$0 { adoption = nil } })
    }

    private var removalTitle: String {
        let name = removal?.name ?? ""
        return String(localized: "Supprimer « \(name) » ?", bundle: .module)
    }

    private var adoptionTitle: String {
        let name = adoption?.name ?? ""
        return String(localized: "Adopter « \(name) » ?", bundle: .module)
    }
}

/// La question posée par la boîte de saisie d'un nom.
private enum NamePrompt {
    case rename
    case newRoutine
    case newProgram

    var title: String {
        switch self {
        case .rename: String(localized: "Renommer le programme", bundle: .module)
        case .newRoutine: String(localized: "Nouvelle routine", bundle: .module)
        case .newProgram: String(localized: "Nouveau programme", bundle: .module)
        }
    }

    var placeholder: String {
        switch self {
        case .rename, .newProgram: String(localized: "Nom du programme", bundle: .module)
        case .newRoutine: String(localized: "Nom de la routine (ex. Push)", bundle: .module)
        }
    }

    var confirmation: String {
        switch self {
        case .rename: String(localized: "Renommer", bundle: .module)
        case .newRoutine, .newProgram: String(localized: "Créer", bundle: .module)
        }
    }
}

private struct ProgramTemplateChoice: Identifiable {
    let id: String
    let name: String
}

/// Une ligne de liste : titre, détail et une icône facultative à droite.
private struct LabeledRow: View {
    let title: String
    let detail: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}
