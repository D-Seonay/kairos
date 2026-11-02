import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La bibliothèque d'exercices (spec M4 §10.1) : recherche, pilules de groupe et de matériel, « Récents » puis le reste.
/// En consultation, toucher une ligne ouvre la fiche (l'écran doit être dans une pile de navigation) ; en choix, `onPick` reçoit
/// les exercices dans l'ordre des touches.
public struct LibraryView: View {
    @State private var model: LibraryModel
    private let onPick: ([ExerciseReference]) -> Void
    @State private var opened: ExerciseReference?
    @State private var isCreating = false

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: LibraryModel, onPick: @escaping ([ExerciseReference]) -> Void = { _ in }) {
        _model = State(initialValue: model)
        self.onPick = onPick
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                filters
                Button(String(localized: "Créer un exercice", bundle: .module)) { isCreating = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier(TrainIdentifiers.libraryCreate)
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                list
            }
            .padding(PulseMetrics.spacing)
        }
        .background(PulsePalette.background)
        .navigationTitle(String(localized: "Exercices", bundle: .module))
        .pulseInlineTitle()
        .searchable(text: $model.query, prompt: String(localized: "Rechercher (ex. developpe)", bundle: .module))
        .safeAreaInset(edge: .bottom) { confirmBar }
        .navigationDestination(item: $opened) { reference in
            ExerciseSheetView(model: model.sheet(for: reference))
        }
        .sheet(isPresented: $isCreating) {
            NavigationStack {
                CustomExerciseForm(model: model.creator(), onSaved: { _ in Task { await model.load() } })
            }
        }
        .task { await model.load() }
    }

    // MARK: - Filtres

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChoicePills(options: groupOptions, selection: groupSelection)
            ChoicePills(options: equipmentOptions, selection: equipmentSelection)
        }
    }

    private var groupOptions: [(value: GroupChoice, label: String)] {
        [(GroupChoice.all, String(localized: "Tous", bundle: .module))]
            + MuscleGroup.allCases.map { (GroupChoice.group($0), $0.localizedName) }
    }

    private var equipmentOptions: [(value: EquipmentChoice, label: String)] {
        [(EquipmentChoice.all, String(localized: "Tout matériel", bundle: .module))]
            + Equipment.allCases.map { (EquipmentChoice.equipment($0), $0.localizedName) }
    }

    private var groupSelection: Binding<GroupChoice?> {
        Binding(get: { model.group.map(GroupChoice.group) ?? .all },
                set: { choice in
                    if case .group(let group)? = choice { model.group = group } else { model.group = nil }
                })
    }

    private var equipmentSelection: Binding<EquipmentChoice?> {
        Binding(get: { model.equipment.map(EquipmentChoice.equipment) ?? .all },
                set: { choice in
                    if case .equipment(let equipment)? = choice { model.equipment = equipment } else { model.equipment = nil }
                })
    }

    // MARK: - Liste

    @ViewBuilder
    private var list: some View {
        let results = model.results
        let recents = results.filter { model.isRecent($0.reference) }
        let others = results.filter { !model.isRecent($0.reference) }
        if results.isEmpty {
            Text(String(localized: "Aucun exercice ne correspond à ta recherche.", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .padding(.top, 8)
        }
        section(String(localized: "Récents", bundle: .module), recents)
        section(recents.isEmpty ? String(localized: "Tous les exercices", bundle: .module)
                    : String(localized: "Autres exercices", bundle: .module), others)
    }

    @ViewBuilder
    private func section(_ title: String, _ exercises: [ExerciseInfo]) -> some View {
        if !exercises.isEmpty {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(PulsePalette.text)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            ForEach(exercises) { exercise in
                ExerciseRow(info: exercise, oneRepMax: model.oneRepMax(for: exercise.reference), mode: model.mode,
                            isSelected: model.selection.contains(exercise.reference)) {
                    touch(exercise.reference)
                }
            }
        }
    }

    private func touch(_ reference: ExerciseReference) {
        switch model.mode {
        case .browse:
            opened = reference
        case .pick(multiple: true):
            model.toggle(reference)
        case .pick(multiple: false):
            model.toggle(reference)
            onPick(model.confirm())
        }
    }

    // MARK: - Choix

    /// Le bouton d'ajout, en choix multiple seulement.
    @ViewBuilder
    private var confirmBar: some View {
        if model.mode == .pick(multiple: true) {
            let count = model.selection.count
            Button(count == 0 ? String(localized: "Ajouter", bundle: .module)
                    : String(localized: "Ajouter (\(count))", bundle: .module)) {
                onPick(model.confirm())
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(count == 0)
            .padding(PulseMetrics.spacing)
            .background(.bar)
        }
    }
}

private enum GroupChoice: Hashable {
    case all
    case group(MuscleGroup)
}

private enum EquipmentChoice: Hashable {
    case all
    case equipment(Equipment)
}

/// Une ligne : nom, « groupe · matériel · 1RM », puis un chevron (consultation) ou une coche (choix).
private struct ExerciseRow: View {
    let info: ExerciseInfo
    let oneRepMax: Double?
    let mode: LibraryMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                TileIcon(systemName: icon, foreground: PulsePalette.text2, background: PulsePalette.surface2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(PulsePalette.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? PulsePalette.text2 : PulsePalette.line))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(info.name), \(subtitle)", bundle: .module))
        .accessibilityHint(hint)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(TrainIdentifiers.exerciseRowPrefix + info.id.identifier)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous)
    }

    @ViewBuilder
    private var trailing: some View {
        if mode == .browse {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PulsePalette.muted)
                .accessibilityHidden(true)
        } else {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? PulsePalette.text : PulsePalette.muted)
                .accessibilityHidden(true)
        }
    }

    private var icon: String {
        switch info.equipment {
        case .dumbbell, .kettlebell: "dumbbell.fill"
        case .bodyweight: "figure.strengthtraining.functional"
        default: "figure.strengthtraining.traditional"
        }
    }

    /// « Pectoraux · barre · 1RM 65 kg ».
    private var subtitle: String {
        var parts = [info.group.localizedName, info.equipment.localizedName.lowercased()]
        if let oneRepMax {
            parts.append(String(localized: "1RM \(PulseFormat.decimal(oneRepMax, maxFractionDigits: 1)) kg", bundle: .module))
        }
        return parts.joined(separator: " · ")
    }

    private var hint: String {
        mode == .browse
            ? String(localized: "Ouvre la fiche de l'exercice", bundle: .module)
            : String(localized: "Ajoute l'exercice au choix ou l'en retire", bundle: .module)
    }
}

private extension ExerciseReference {
    var identifier: String {
        switch self {
        case .content(let id): id
        case .user(let id): id.uuidString
        }
    }
}
