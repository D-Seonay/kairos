import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Un exercice : son en-tête (nom qui ouvre la fiche, « Dernière fois », ce que le jour a changé, RPE plafond, disques sur une
/// barre, menu), ses séries et « + Ajouter une série ». Une section de la liste, pour que le balayage supprime une série.
struct LiveExerciseCard: View {
    static let incrementChoices: [Double] = [1, 1.25, 2, 2.5, 5, 10]

    let model: LiveSessionModel
    let exercise: LiveExercise
    let index: Int
    let isLast: Bool
    /// La série à faire maintenant dans toute la séance, pour éclairer sa ligne si elle est dans cette carte.
    var upcomingSetID: UUID?
    @Binding var rpeSet: UUID?
    @State private var isShowingSheet = false
    @State private var isShowingPlates = false
    @State private var isReplacing = false
    @State private var isRemoving = false
    @State private var isEditingNote = false
    @State private var noteDraft = ""
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Section {
            header
                .listRowBackground(Self.background(top: true))
            if !LiveSetRow.usesStackedLayout(typeSize) {
                LiveColumnsHeader(loadKind: exercise.loadKind, tracksDuration: exercise.tracksDuration)
                    .listRowBackground(Self.background())
            }
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { position, set in
                LiveSetRow(model: model, exercise: exercise, exerciseIndex: index, set: set, index: position,
                           isUpcoming: set.id == upcomingSetID, rpeSet: $rpeSet)
                    .listRowBackground(Self.background())
                    .setSwipeActions(model: model, set: set)
            }
            addSetButton
                .listRowBackground(Self.background(bottom: true))
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    // MARK: En-tête

    /// Aux tailles d'accessibilité, les boutons passent sous le nom pour lui laisser toute la largeur.
    private var header: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    isShowingSheet = true
                } label: {
                    Text(exercise.name)
                        .font(.headline)
                        // Un exercice fini s'efface d'un cran : l'œil va à ceux qui restent.
                        .foregroundStyle(exercise.isDone ? PulsePalette.text2 : PulsePalette.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: LiveSetRow.targetHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Un titre : le rotor « Titres » saute d'un exercice à l'autre.
                .accessibilityAddTraits(.isHeader)
                .accessibilityHint(String(localized: "Ouvre la fiche de l'exercice", bundle: .module))
                details
            }
            HStack(spacing: 4) {
                if exercise.isBarbell && exercise.loadKind == .external {
                    platesButton
                }
                ExerciseProgressRing(done: exercise.doneSetCount, total: exercise.sets.count)
                    .frame(minWidth: 44, minHeight: LiveSetRow.targetHeight)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Self.progressSpokenText(done: exercise.doneSetCount, total: exercise.sets.count))
                menu
            }
        }
        .pulseAnimation(.snappy(duration: 0.25), value: exercise.isDone)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .sheet(isPresented: $isShowingSheet) { exerciseSheet }
        .sheet(isPresented: $isReplacing) {
            ReplaceExerciseSheet(model: model, exercise: exercise)
        }
        .sheet(isPresented: $isShowingPlates) {
            PlateCalculatorSheet(model: model, exerciseID: exercise.id)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(String(localized: "Retirer cet exercice ?", bundle: .module), isPresented: $isRemoving,
                            titleVisibility: .visible) {
            Button(String(localized: "Retirer", bundle: .module), role: .destructive) {
                Task { await model.removeExercise(exercise.id) }
            }
        } message: {
            Text(String(localized: "Ses séries sont retirées de la séance.", bundle: .module))
        }
        .alert(String(localized: "Note", bundle: .module), isPresented: $isEditingNote) {
            TextField(String(localized: "Note de l'exercice", bundle: .module), text: $noteDraft)
            Button(String(localized: "Enregistrer", bundle: .module)) {
                let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { await model.setNote(trimmed.isEmpty ? nil : trimmed, exercise: exercise.id) }
            }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        }
    }

    private var details: some View {
        LiveExerciseDetails(exercise: exercise, onEditNote: editNote) {
            Task { await model.restoreLoads(exercise: exercise.id) }
        }
    }

    private func editNote() {
        noteDraft = exercise.note ?? ""
        isEditingNote = true
    }

    /// Le calculateur de disques, sur les exercices à la barre (spec M4 §19.2).
    private var platesButton: some View {
        Button {
            isShowingPlates = true
        } label: {
            Image(systemName: "circle.circle")
                .font(.title3)
                .foregroundStyle(PulsePalette.text2)
                .frame(width: LiveSetRow.targetHeight, height: LiveSetRow.targetHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Disques à charger", bundle: .module))
    }

    private var menu: some View {
        Menu {
            Button(action: editNote) {
                Label(String(localized: "Note", bundle: .module), systemImage: "note.text")
            }
            Picker(String(localized: "Incrément", bundle: .module), selection: incrementBinding) {
                ForEach(Self.incrementChoices, id: \.self) { Text(Self.incrementText($0)).tag($0) }
            }
            if exercise.warmupPlan != nil {
                Picker(String(localized: "Échauffement", bundle: .module), selection: warmupBinding) {
                    Text(String(localized: "Automatique", bundle: .module)).tag(Int?.none)
                    Text(String(localized: "Aucun", bundle: .module)).tag(Int?.some(0))
                    Text(String(localized: "1 série", bundle: .module)).tag(Int?.some(1))
                    ForEach(2...3, id: \.self) { count in
                        Text(String(localized: "\(count) séries", bundle: .module)).tag(Int?.some(count))
                    }
                }
                .pickerStyle(.menu)
            }
            Button {
                isReplacing = true
            } label: {
                Label(String(localized: "Remplacer", bundle: .module), systemImage: "arrow.triangle.swap")
            }
            .disabled(!exercise.sets.contains { $0.setType != .warmup && $0.completedAt == nil })
            Button {
                Task { await model.moveExercise(exercise.id, by: -1) }
            } label: {
                Label(String(localized: "Monter", bundle: .module), systemImage: "arrow.up")
            }
            .disabled(index == 0)
            Button {
                Task { await model.moveExercise(exercise.id, by: 1) }
            } label: {
                Label(String(localized: "Descendre", bundle: .module), systemImage: "arrow.down")
            }
            .disabled(isLast)
            Button(role: .destructive) {
                isRemoving = true
            } label: {
                Label(String(localized: "Retirer", bundle: .module), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .foregroundStyle(PulsePalette.text2)
                .frame(width: LiveSetRow.targetHeight, height: LiveSetRow.targetHeight)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Options de \(exercise.name)", bundle: .module))
    }

    private var warmupBinding: Binding<Int?> {
        Binding(get: { exercise.warmupPlan?.maxCount },
                set: { count in Task { await model.setWarmupCount(count, exercise: exercise.id) } })
    }

    private var incrementBinding: Binding<Double> {
        Binding(get: { exercise.incrementKg },
                set: { value in Task { await model.setIncrement(value, exercise: exercise.id) } })
    }

    private var exerciseSheet: some View {
        NavigationStack {
            ExerciseSheetView(model: ExerciseSheetModel(environment: model.train, reference: exercise.exercise))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Fermer", bundle: .module)) { isShowingSheet = false }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Ajouter

    private var addSetButton: some View {
        Button {
            Task { await model.addSet(exercise: exercise.id) }
        } label: {
            let shape = RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
            Text(String(localized: "+ Ajouter une série", bundle: .module))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(PulsePalette.accent(for: theme).accent))
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(shape.strokeBorder(PulsePalette.ink.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                .contentShape(shape)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .buttonStyle(LivePressStyle(pressedScale: 0.97))
        .accessibilityLabel(Self.addSetSpokenText(exercise: exercise.name))
        .accessibilityIdentifier(LiveSessionIdentifiers.addSet)
    }

    /// Le fond d'une ligne de la carte : arrondi en haut sur la première, en bas sur la dernière.
    private static func background(top: Bool = false, bottom: Bool = false) -> some View {
        let radius = PulseMetrics.radiusSmall
        return UnevenRoundedRectangle(
            topLeadingRadius: top ? radius : 0, bottomLeadingRadius: bottom ? radius : 0,
            bottomTrailingRadius: bottom ? radius : 0, topTrailingRadius: top ? radius : 0, style: .continuous)
            .fill(PulsePalette.surface)
    }
}

// MARK: - Textes

extension LiveExerciseCard {
    /// « RPE 7,5 max » : le plafond du jour.
    nonisolated static func rpeCapText(_ cap: Double) -> String {
        String(localized: "RPE \(PulseFormat.decimal(cap, maxFractionDigits: 1)) max", bundle: .module)
    }

    /// « Super set A » : les groupes de la routine sont numérotés à partir de 1.
    nonisolated static func supersetText(group: Int) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let letter = letters[((group - 1) % letters.count + letters.count) % letters.count]
        return String(localized: "Super set \(String(letter))", bundle: .module)
    }

    /// « 2 séries faites sur 5 », « Exercice terminé » : l'anneau de la carte dit en mots.
    nonisolated static func progressSpokenText(done: Int, total: Int) -> String {
        if total > 0 && done >= total { return String(localized: "Exercice terminé", bundle: .module) }
        return done == 1 ? String(localized: "1 série faite sur \(total)", bundle: .module)
            : String(localized: "\(done) séries faites sur \(total)", bundle: .module)
    }

    /// « Ajouter une série à Développé couché » : chaque carte a son bouton, VoiceOver dit lequel.
    nonisolated static func addSetSpokenText(exercise: String) -> String {
        String(localized: "Ajouter une série à \(exercise)", bundle: .module)
    }

    /// « 2,5 kg » : un incrément de charge.
    nonisolated static func incrementText(_ incrementKg: Double) -> String {
        String(localized: "\(PulseFormat.decimal(incrementKg, maxFractionDigits: 2)) kg", bundle: .module)
    }
}

/// Les titres des colonnes d'une carte, alignés sur les cellules de `LiveSetRow` : mêmes largeurs, qui suivent le texte.
private struct LiveColumnsHeader: View {
    let loadKind: LoadKind
    let tracksDuration: Bool
    @ScaledMetric(relativeTo: .title2) private var weightWidth = LiveSetRow.weightWidth
    @ScaledMetric(relativeTo: .title2) private var valueWidth = LiveSetRow.valueWidth
    @ScaledMetric(relativeTo: .title2) private var rpeWidth = LiveSetRow.rpeWidth

    var body: some View {
        HStack(spacing: 6) {
            Text(String(localized: "Série", bundle: .module)).frame(width: LiveSetRow.badgeWidth)
            Text(String(localized: "Précédent", bundle: .module)).frame(maxWidth: .infinity)
            Text(LiveSetRow.weightColumnTitle(for: loadKind)).frame(width: weightWidth)
            Text(tracksDuration ? String(localized: "Sec", bundle: .module) : String(localized: "Reps", bundle: .module))
                .frame(width: valueWidth)
            Text(String(localized: "RPE", bundle: .module)).frame(width: rpeWidth)
            Color.clear.frame(width: LiveSetRow.targetHeight, height: 1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(PulsePalette.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, LiveSetRow.horizontalPadding)
        .padding(.vertical, 2)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// Les balayages d'une série. De gauche à droite : valide la série (ou la dévalide), comme la coche ; un balayage complet
    /// suffit. De droite à gauche : supprime, poubelle rouge sur fond sombre. Une série validée ne part pas d'un balayage
    /// complet : sa suppression ne se défait pas.
    func setSwipeActions(model: LiveSessionModel, set: LiveSet) -> some View {
        let isDone = set.completedAt != nil
        return swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await model.tap(set: set.id) }
            } label: {
                LiveSwipeIcon(isDone ? "arrow.uturn.backward" : "checkmark",
                              title: isDone ? String(localized: "Annuler la validation", bundle: .module)
                                  : String(localized: "Valider la série", bundle: .module),
                              color: isDone ? PulsePalette.text : PulsePalette.liveBackground)
            }
            .tint(isDone ? PulsePalette.surface2 : PulsePalette.ok)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: !isDone) {
            Button(role: .destructive) {
                Task { await model.deleteSet(set.id) }
            } label: {
                LiveSwipeIcon("trash", title: String(localized: "Supprimer la série", bundle: .module),
                              color: PulsePalette.signal)
            }
            .tint(PulsePalette.surface2)
        }
    }
}
