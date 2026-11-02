import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La fiche d'un exercice (spec M4 §10.2) : technique, progression, alternatives. Elle se montre dans une pile de navigation,
/// où toucher une alternative pousse sa fiche.
public struct ExerciseSheetView: View {
    @State private var model: ExerciseSheetModel
    @State private var opened: ExerciseReference?
    @State private var isEditing = false
    @State private var hasLoaded = false
    @Environment(\.dismiss) private var dismiss

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: ExerciseSheetModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                if model.info != nil {
                    Picker(String(localized: "Sections de la fiche", bundle: .module), selection: $model.tab) {
                        ForEach(ExerciseSheetTab.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if let message = model.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.bad)
                    }
                    pane
                } else if hasLoaded {
                    Text(String(localized: "Cet exercice est introuvable.", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(PulseMetrics.spacing)
        }
        .background(PulsePalette.background)
        .navigationTitle(model.info?.name ?? String(localized: "Exercice", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            if model.userExercise != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "Modifier", bundle: .module)) { isEditing = true }
                }
            }
        }
        .navigationDestination(item: $opened) { reference in
            ExerciseSheetView(model: model.sheet(for: reference))
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                if let editor = model.editor() {
                    CustomExerciseForm(model: editor, onSaved: { _ in Task { await model.load() } }, onArchived: { dismiss() })
                }
            }
        }
        .task {
            await model.load()
            hasLoaded = true
        }
    }

    @ViewBuilder
    private var pane: some View {
        switch model.tab {
        case .technique:
            TechniquePane(model: model)
        case .progression:
            ProgressionPane(model: model)
        case .alternatives:
            AlternativesPane(alternatives: model.alternatives) { opened = $0 }
        }
    }
}

private extension ExerciseSheetTab {
    var title: String {
        switch self {
        case .technique: String(localized: "Technique", bundle: .module)
        case .progression: String(localized: "Progression", bundle: .module)
        case .alternatives: String(localized: "Alternatives", bundle: .module)
        }
    }
}

// MARK: - Technique

/// La carte musculaire, le matériel et le plan de mouvement, puis les consignes, les erreurs à éviter et le rappel des douleurs.
/// Un exercice perso n'a que ce qu'il possède : ni consignes ni erreurs.
private struct TechniquePane: View {
    let model: ExerciseSheetModel
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        if let info = model.info {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                muscleCard(info)
                facts(info)
                if let content = info.content {
                    cues(content.cues.fr)
                    mistakes(content.mistakes.fr)
                }
                if let reminder = model.painReminder {
                    painCard(reminder)
                }
            }
        }
    }

    private func muscleCard(_ info: ExerciseInfo) -> some View {
        let accent = PulsePalette.accent(for: theme).accent
        let primary = names(info.primaryMuscles)
        let secondary = names(info.secondaryMuscles)
        return ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                MuscleMapView(levels: model.muscleLevels, label: muscleLabel(primary: primary, secondary: secondary), height: 280)
                    .frame(maxWidth: .infinity)
                legend(color: Color(MuscleIntensity.color(level: 4, accent: accent)),
                       text: String(localized: "Principaux : \(primary)", bundle: .module))
                if !info.secondaryMuscles.isEmpty {
                    legend(color: Color(MuscleIntensity.color(level: 2, accent: accent)),
                           text: String(localized: "Secondaires : \(secondary)", bundle: .module))
                }
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
        }
        .accessibilityElement(children: .combine)
    }

    private func muscleLabel(primary: String, secondary: String) -> String {
        secondary.isEmpty
            ? String(localized: "Muscles sollicités. Principaux : \(primary).", bundle: .module)
            : String(localized: "Muscles sollicités. Principaux : \(primary). Secondaires : \(secondary).", bundle: .module)
    }

    private func names(_ muscles: [Muscle]) -> String {
        muscles.map(\.localizedName).joined(separator: ", ")
    }

    private func facts(_ info: ExerciseInfo) -> some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 8) {
                fact(String(localized: "Matériel", bundle: .module), info.equipment.localizedName)
                fact(String(localized: "Plan de mouvement", bundle: .module), info.pattern.localizedName)
                fact(String(localized: "Charge", bundle: .module), info.loadKind.localizedName)
            }
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func cues(_ cues: [String]) -> some View {
        if !cues.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SheetSectionTitle(text: String(localized: "Consignes qui comptent", bundle: .module))
                ObsidianCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(cues.indices, id: \.self) { index in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(verbatim: "\(index + 1)")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(PulsePalette.text)
                                    .frame(width: 26, height: 26)
                                    .background(PulsePalette.surface2, in: Circle())
                                    .accessibilityHidden(true)
                                Text(cues[index])
                                    .font(.subheadline)
                                    .foregroundStyle(PulsePalette.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(String(localized: "Consigne \(index + 1) : \(cues[index])", bundle: .module))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mistakes(_ mistakes: [String]) -> some View {
        if !mistakes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SheetSectionTitle(text: String(localized: "À éviter", bundle: .module))
                ObsidianCard {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(mistakes.indices, id: \.self) { index in
                            Label {
                                Text(mistakes[index])
                                    .font(.subheadline)
                                    .foregroundStyle(PulsePalette.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulsePalette.bad)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private func painCard(_ reminder: String) -> some View {
        ObsidianCard {
            Label {
                Text(reminder)
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PulsePalette.warn)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Alternatives

/// Les alternatives du contenu ; toucher l'une d'elles ouvre sa fiche.
private struct AlternativesPane: View {
    let alternatives: [ExerciseInfo]
    let onOpen: (ExerciseReference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if alternatives.isEmpty {
                Text(String(localized: "Aucune alternative pour cet exercice.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            }
            ForEach(alternatives) { alternative in
                Button { onOpen(alternative.reference) } label: { row(alternative) }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "\(alternative.name), \(subtitle(alternative))", bundle: .module))
                    .accessibilityHint(String(localized: "Ouvre la fiche de l'exercice", bundle: .module))
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func row(_ alternative: ExerciseInfo) -> some View {
        ObsidianCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alternative.name)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                        .multilineTextAlignment(.leading)
                    Text(subtitle(alternative))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
    }

    private func subtitle(_ alternative: ExerciseInfo) -> String {
        "\(alternative.pattern.localizedName) · \(alternative.equipment.localizedName.lowercased())"
    }
}

/// Le titre d'une section de la fiche.
struct SheetSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(PulsePalette.text)
            .accessibilityAddTraits(.isHeader)
    }
}
