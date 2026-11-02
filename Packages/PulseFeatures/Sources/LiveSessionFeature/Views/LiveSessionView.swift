import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// L'écran de la séance en direct (spec M4 §14, §15.1) : noir pur, l'en-tête, une carte par exercice, puis en bas le bandeau de
/// repos et le clavier intégré (ou les pilules du RPE). `onFinish` et `onAbandon` ouvrent les confirmations de l'appelant.
public struct LiveSessionView: View {
    private let model: LiveSessionModel
    private let onFinish: () -> Void
    private let onAbandon: () -> Void
    @State private var rpeSet: UUID?
    @State private var isAddingExercise = false
    @Environment(\.pulseTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: LiveSessionModel, onFinish: @escaping () -> Void, onAbandon: @escaping () -> Void) {
        self.model = model
        self.onFinish = onFinish
        self.onAbandon = onAbandon
    }

    public var body: some View {
        VStack(spacing: 0) {
            LiveHeader(session: model.session, onFinish: onFinish, onAbandon: onAbandon)
            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.bad)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            exerciseList
        }
        .background(PulsePalette.liveBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomPanel }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: model.focus)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: rpeSet)
        .sheet(isPresented: $isAddingExercise) { library }
        .preferredColorScheme(.dark)
    }

    // MARK: Liste

    private var exerciseList: some View {
        ScrollViewReader { proxy in
            List {
                let exercises = model.session.exercises
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    LiveExerciseCard(model: model, exercise: exercise, index: index, isLast: index == exercises.count - 1,
                                     rpeSet: $rpeSet)
                }
                Section {
                    addExerciseButton
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .liveSectionSpacing()
            .contentMargins(.horizontal, 12, for: .scrollContent)
            .onChange(of: model.focus) { _, focus in
                if let focus { proxy.scrollTo(focus.set, anchor: .center) }
            }
            .onChange(of: rpeSet) { _, set in
                if let set { proxy.scrollTo(set, anchor: .center) }
            }
        }
    }

    private var addExerciseButton: some View {
        Button {
            isAddingExercise = true
        } label: {
            Text(String(localized: "+ Ajouter un exercice", bundle: .module))
                .font(.headline)
                .foregroundStyle(Color(PulsePalette.accent(for: theme).accent))
                .frame(maxWidth: .infinity, minHeight: LiveSetRow.targetHeight)
                .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(LiveSessionIdentifiers.addExercise)
    }

    private var library: some View {
        NavigationStack {
            LibraryView(model: LibraryModel(environment: model.train, mode: .pick(multiple: true))) { references in
                isAddingExercise = false
                Task { await model.addExercises(references) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Annuler", bundle: .module)) { isAddingExercise = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Bas de l'écran

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            if let rest = model.session.rest {
                RestBanner(model: model, rest: rest)
            }
            if let target = rpeTarget {
                RPEPicker(title: RPEPicker.title(exercise: target.exercise.name, setIndex: target.index),
                          selection: target.set.rpe, onSelect: { rpe in
                    rpeSet = nil
                    Task { await model.setRPE(rpe, set: target.set.id) }
                }, onClose: { rpeSet = nil })
            } else if let focus = model.focus, let target = target(of: focus.set) {
                NumericKeypad(
                    title: NumericKeypad.title(exercise: target.exercise.name, setIndex: target.index, field: focus.kind,
                                               loadKind: target.exercise.loadKind),
                    field: focus.kind, increment: target.exercise.incrementKg,
                    onKey: { key in Task { await model.keypadKey(key) } }, onClose: { model.focus(nil) })
            }
        }
    }

    private struct SetTarget {
        var exercise: LiveExercise
        var set: LiveSet
        var index: Int
    }

    private var rpeTarget: SetTarget? {
        rpeSet.flatMap(target(of:))
    }

    private func target(of setID: UUID) -> SetTarget? {
        for exercise in model.session.exercises {
            if let index = exercise.sets.firstIndex(where: { $0.id == setID }) {
                return SetTarget(exercise: exercise, set: exercise.sets[index], index: index)
            }
        }
        return nil
    }
}

private extension View {
    /// L'espace entre deux cartes ; la liste du Mac, où les tests tournent, n'a pas ce réglage.
    func liveSectionSpacing() -> some View {
        #if os(iOS)
        listSectionSpacing(12)
        #else
        self
        #endif
    }
}
