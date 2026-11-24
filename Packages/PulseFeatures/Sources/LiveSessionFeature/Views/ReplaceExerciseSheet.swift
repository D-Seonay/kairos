import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Remplacer un exercice (spec M4 §19.3, maquette `remplacer`) : la raison, puis trois alternatives du même mouvement avec leur
/// charge proposée, ou un exercice cherché dans la bibliothèque. Les séries validées restent sur l'exercice d'origine.
struct ReplaceExerciseSheet: View {
    let model: LiveSessionModel
    let exercise: LiveExercise
    /// « Machine occupée », la raison la plus courante, est choisie d'office : les alternatives s'affichent tout de suite.
    @State private var reason: ReplacementReason? = .machineBusy
    @State private var options: [ReplacementOption] = []
    @State private var isLoading = false
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                    Text(String(localized: "Pourquoi changer ?", bundle: .module))
                        .pulseEyebrow()
                    ChoicePills(options: ReplacementReason.allCases.map { ($0, Self.label(for: $0)) }, selection: $reason)
                    if reason != nil {
                        alternatives
                    }
                    Text(String(localized: "Les séries déjà validées restent sur \(exercise.name).", bundle: .module))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.muted)
                }
                .padding(PulseMetrics.spacing)
            }
            .background(PulsePalette.background)
            .navigationTitle(String(localized: "Remplacer", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Annuler", bundle: .module)) { dismiss() }
                }
            }
        }
        .task(id: reason) { await loadOptions() }
        .sheet(isPresented: $isSearching) { library }
        // Comme l'écran en direct et sa bibliothèque : la séance reste noire (spec M4 §14.2).
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var alternatives: some View {
        PulseSectionHeader(String(localized: "Alternatives", bundle: .module))
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Self.loadingSpokenText)
        } else if options.isEmpty {
            Text(String(localized: "Pas d'alternative avec ton matériel. Cherche un autre exercice.", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
        }
        ForEach(options) { option in
            Button {
                Task {
                    await model.replace(exercise.id, with: option.exercise)
                    dismiss()
                }
            } label: {
                PulseRow(systemImage: Self.icon(for: option.info.equipment), title: option.info.name,
                         detail: Self.proposalText(option.exercise)) {
                    RowChevron()
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(Self.optionSpokenLabel(name: option.info.name, replacement: option.exercise))
            .accessibilityHint(String(localized: "Remplace \(exercise.name) pour les séries restantes", bundle: .module))
        }
        Button {
            isSearching = true
        } label: {
            Label(String(localized: "Chercher un autre exercice", bundle: .module), systemImage: "magnifyingglass")
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private var library: some View {
        NavigationStack {
            LibraryView(model: LibraryModel(environment: model.train, mode: .pick(multiple: false))) { references in
                isSearching = false
                guard let picked = references.first, let reason else { return }
                Task {
                    await model.replace(exercise.id, withPicked: picked, reason: reason)
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Annuler", bundle: .module)) { isSearching = false }
                }
            }
        }
    }

    private func loadOptions() async {
        guard let reason else { return }
        isLoading = true
        options = await model.replacementOptions(for: exercise.id, reason: reason)
        isLoading = false
    }

    // MARK: Textes

    nonisolated static func label(for reason: ReplacementReason) -> String {
        switch reason {
        case .machineBusy: String(localized: "Machine occupée", bundle: .module)
        case .pain: String(localized: "Douleur", bundle: .module)
        case .other: String(localized: "Autre", bundle: .module)
        }
    }

    /// « 2 séries · 24 kg × 10 · charge estimée » ; sans charge, les répétitions seules.
    nonisolated static func proposalText(_ replacement: LiveExercise) -> String {
        let working = replacement.sets.filter { $0.setType != .warmup }
        let count = working.count == 1 ? String(localized: "1 série", bundle: .module)
            : String(localized: "\(working.count) séries", bundle: .module)
        guard let first = working.first else { return count }
        var parts = [count]
        if let weight = first.proposed.weightKg, let reps = first.proposed.reps {
            parts.append(String(localized: "\(PulseFormat.decimal(weight, maxFractionDigits: 2)) kg × \(reps)", bundle: .module))
        } else if let reps = first.proposed.reps {
            parts.append(String(localized: "\(reps) répétitions", bundle: .module))
        }
        if replacement.lastTimeText == nil, first.proposed.weightKg != nil {
            parts.append(String(localized: "charge estimée", bundle: .module))
        }
        return parts.joined(separator: " · ")
    }

    /// « Chargement des alternatives » : ce que la roue d'attente fait.
    nonisolated static var loadingSpokenText: String {
        String(localized: "Chargement des alternatives", bundle: .module)
    }

    /// « 2 séries, 24 kilos, 10 répétitions, charge estimée » : `proposalText` dit en mots.
    nonisolated static func proposalSpokenText(_ replacement: LiveExercise) -> String {
        let working = replacement.sets.filter { $0.setType != .warmup }
        var parts = [PulseSpoken.count(working.count, singular: String(localized: "série", bundle: .module),
                                       plural: String(localized: "séries", bundle: .module))]
        guard let first = working.first else { return parts[0] }
        if let weight = first.proposed.weightKg { parts.append(LiveSetRow.kilos(weight)) }
        if let reps = first.proposed.reps { parts.append(PulseSpoken.repetitions(reps)) }
        if replacement.lastTimeText == nil, first.proposed.weightKg != nil {
            parts.append(String(localized: "charge estimée", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }

    /// « Développé haltères, 2 séries, 24 kilos, 10 répétitions, charge estimée ».
    nonisolated static func optionSpokenLabel(name: String, replacement: LiveExercise) -> String {
        String(localized: "\(name), \(proposalSpokenText(replacement))", bundle: .module)
    }

    private static func icon(for equipment: Equipment) -> String {
        switch equipment {
        case .barbell, .ezBar, .smithMachine: "figure.strengthtraining.traditional"
        case .dumbbell, .kettlebell: "dumbbell.fill"
        case .machine, .cable: "gearshape.2"
        case .band: "lasso"
        case .bodyweight: "figure.core.training"
        }
    }
}
