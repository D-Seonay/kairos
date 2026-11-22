import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Un exercice de la routine : un en-tête qui résume ses réglages et, déplié, les commandes de chacun (spec M4 §11.2) : séries,
/// fourchette de répétitions (ou de secondes) commune ou par série, RPE, repos, super set, incrément, retrait.
struct RoutineExerciseEditor: View {
    let model: RoutineEditorModel
    let index: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    @State private var confirmsRemoval = false

    var body: some View {
        if model.day.exercises.indices.contains(index) {
            let exercise = model.day.exercises[index]
            VStack(alignment: .leading, spacing: 12) {
                header(exercise)
                if isExpanded {
                    controls(exercise)
                }
            }
            .padding(.vertical, 4)
            .confirmationDialog(String(localized: "Retirer \(model.name(of: exercise.exercise)) de la routine ?", bundle: .module),
                                isPresented: $confirmsRemoval, titleVisibility: .visible) {
                Button(String(localized: "Retirer", bundle: .module), role: .destructive) {
                    onToggle()
                    model.remove(at: index)
                }
                Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
            }
        }
    }

    // MARK: - En-tête

    private func header(_ exercise: RoutineExercise) -> some View {
        let name = model.name(of: exercise.exercise)
        let tracksDuration = model.tracksDuration(exercise.exercise)
        let summary = TrainText.routineExerciseSummary(exercise, tracksDuration: tracksDuration)
        let hasIssue = model.issues[index] != nil
        return Button(action: onToggle) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                    // Une erreur ne tient pas qu'à la couleur : une icône précède le résumé tant que la ligne est repliée.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if hasIssue {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .accessibilityHidden(true)
                        }
                        Text(summary)
                    }
                    .font(.footnote)
                    .foregroundStyle(hasIssue ? PulsePalette.bad : PulsePalette.text2)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if model.isSuperset(at: index) || (index > 0 && model.isSuperset(at: index - 1)) {
                    Image(systemName: "link")
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.muted)
                        .accessibilityHidden(true)
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        // Un style explicite : seul l'en-tête répond à l'appui, pas les commandes de la ligne.
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TrainText.routineExerciseLabel(name: name, exercise: exercise, tracksDuration: tracksDuration,
                                                           hasIssue: hasIssue))
        .accessibilityHint(isExpanded ? String(localized: "Replie les réglages", bundle: .module)
                            : String(localized: "Déplie les réglages", bundle: .module))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Commandes

    @ViewBuilder
    private func controls(_ exercise: RoutineExercise) -> some View {
        Stepper(value: Binding(get: { exercise.sets }, set: { model.setSets($0, at: index) }), in: RoutineRules.sets) {
            label(String(localized: "Séries : \(exercise.sets)", bundle: .module))
        }
        .accessibilityLabel(String(localized: "Séries", bundle: .module))
        .accessibilityValue(TrainText.sets(exercise.sets))
        .frame(minHeight: 44)
        Toggle(isOn: Binding(get: { exercise.setTargets != nil }, set: { model.setPerSetTargets($0, at: index) })) {
            label(String(localized: "Par série", bundle: .module))
        }
        .frame(minHeight: 44)
        repetitions(exercise)
        pacing(exercise)
        options(exercise)
    }

    /// Le RPE cible et le repos.
    @ViewBuilder
    private func pacing(_ exercise: RoutineExercise) -> some View {
        Stepper(value: Binding(get: { exercise.targetRPE }, set: { model.setRPE($0, at: index) }), in: RoutineRules.rpe,
                step: RoutineRules.rpeStep) {
            label(String(localized: "RPE cible : \(PulseFormat.decimal(exercise.targetRPE, maxFractionDigits: 1))", bundle: .module))
        }
        .accessibilityLabel(String(localized: "RPE cible", bundle: .module))
        .accessibilityValue(PulseFormat.decimal(exercise.targetRPE, maxFractionDigits: 1))
        .frame(minHeight: 44)
        Stepper(value: Binding(get: { exercise.restSeconds }, set: { model.setRest($0, at: index) }), in: RoutineRules.rest,
                step: RoutineRules.restStep) {
            label(String(localized: "Repos : \(PulseFormat.restDuration(seconds: exercise.restSeconds))", bundle: .module))
        }
        .accessibilityLabel(String(localized: "Repos", bundle: .module))
        .accessibilityValue(PulseSpoken.duration(seconds: exercise.restSeconds))
        .frame(minHeight: 44)
    }

    /// Le super set, l'incrément, les erreurs et le retrait.
    @ViewBuilder
    private func options(_ exercise: RoutineExercise) -> some View {
        Toggle(isOn: Binding(get: { model.isSuperset(at: index) }, set: { _ in model.toggleSuperset(at: index) })) {
            label(String(localized: "Super set avec l'exercice suivant", bundle: .module))
        }
        .disabled(!model.canToggleSuperset(at: index))
        .frame(minHeight: 44)
        Stepper(value: Binding(get: { model.increment(for: exercise.exercise) },
                               set: { kg in Task { await model.setIncrement(kg, for: exercise.exercise) } }),
                in: IncrementStore.range, step: IncrementStore.step) {
            label(String(localized: "Incrément : \(PulseFormat.decimal(model.increment(for: exercise.exercise), maxFractionDigits: 2)) kg",
                         bundle: .module))
        }
        .accessibilityLabel(String(localized: "Incrément de charge", bundle: .module))
        .accessibilityValue(PulseSpoken.kilos(model.increment(for: exercise.exercise)))
        .frame(minHeight: 44)
        ForEach(model.issues[index] ?? [], id: \.self) { issue in
            Text(issue.message(tracksDuration: model.tracksDuration(exercise.exercise)))
                .font(.footnote)
                .foregroundStyle(PulsePalette.bad)
        }
        // Sans style sans bordure, un bouton dans une ligne de liste prend toute la ligne : un appui sur un pas à pas le déclencherait.
        Button(role: .destructive) {
            confirmsRemoval = true
        } label: {
            Label(String(localized: "Retirer de la routine", bundle: .module), systemImage: "trash")
        }
        .buttonStyle(.borderless)
        .frame(minHeight: 44)
    }

    /// La fourchette commune, ou une fourchette par série.
    @ViewBuilder
    private func repetitions(_ exercise: RoutineExercise) -> some View {
        let held = model.tracksDuration(exercise.exercise)
        if let targets = exercise.setTargets {
            ForEach(Array(targets.enumerated()), id: \.offset) { position, target in
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(localized: "Série \(position + 1)", bundle: .module))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PulsePalette.text2)
                    RangeSteppers(target: target, held: held, setNumber: position + 1) {
                        model.updateSetTarget($0, set: position, at: index)
                    }
                }
            }
        } else {
            RangeSteppers(target: SetTarget(repsMin: exercise.repsMin, repsMax: exercise.repsMax), held: held) {
                model.setRange($0, at: index)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(PulsePalette.text)
    }
}

/// Deux pas à pas, minimum et maximum d'une fourchette : monter le minimum au-delà du maximum pousse le maximum, et inversement.
private struct RangeSteppers: View {
    let target: SetTarget
    let held: Bool
    /// Le numéro de la série (à partir de 1) quand la fourchette est propre à une série ; `nil` pour la fourchette commune.
    var setNumber: Int?
    let onChange: (SetTarget) -> Void

    var body: some View {
        let bounds = held ? RoutineRules.seconds : RoutineRules.reps
        let step = held ? 5 : 1
        let unit = held ? String(localized: "s", bundle: .module) : String(localized: "reps", bundle: .module)
        Stepper(value: Binding(get: { target.repsMin }, set: { onChange(SetTarget(repsMin: $0, repsMax: max($0, target.repsMax))) }),
                in: bounds, step: step) {
            Text(String(localized: "Minimum : \(target.repsMin) \(unit)", bundle: .module))
                .foregroundStyle(PulsePalette.text)
        }
        .accessibilityLabel(TrainText.rangeStepperLabel(isMaximum: false, tracksDuration: held, setNumber: setNumber))
        .accessibilityValue(TrainText.rangeStepperValue(target.repsMin, tracksDuration: held))
        .frame(minHeight: 44)
        Stepper(value: Binding(get: { target.repsMax }, set: { onChange(SetTarget(repsMin: min(target.repsMin, $0), repsMax: $0)) }),
                in: bounds, step: step) {
            Text(String(localized: "Maximum : \(target.repsMax) \(unit)", bundle: .module))
                .foregroundStyle(PulsePalette.text)
        }
        .accessibilityLabel(TrainText.rangeStepperLabel(isMaximum: true, tracksDuration: held, setNumber: setNumber))
        .accessibilityValue(TrainText.rangeStepperValue(target.repsMax, tracksDuration: held))
        .frame(minHeight: 44)
    }
}

extension RoutineIssue {
    /// Ce qu'il faut corriger, en une phrase.
    func message(tracksDuration: Bool) -> String {
        switch self {
        case .sets:
            String(localized: "Entre 1 et 10 séries.", bundle: .module)
        case .reps where tracksDuration:
            String(localized: "Entre 5 et 600 secondes, le minimum sous le maximum.", bundle: .module)
        case .reps:
            String(localized: "Entre 1 et 30 répétitions, le minimum sous le maximum.", bundle: .module)
        case .rpe:
            String(localized: "RPE entre 6 et 10, par pas de 0,5.", bundle: .module)
        case .rest:
            String(localized: "Repos entre 0 et 5 min, par pas de 15 s.", bundle: .module)
        case .setTargets:
            String(localized: "Une fourchette par série, le minimum sous le maximum.", bundle: .module)
        }
    }
}
