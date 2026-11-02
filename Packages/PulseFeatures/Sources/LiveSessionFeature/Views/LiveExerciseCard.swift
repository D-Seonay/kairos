import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Un exercice : son en-tête (nom qui ouvre la fiche, « Dernière fois », ce que le jour a changé, RPE plafond, menu), ses séries
/// et « + Ajouter une série ». Une section de la liste, pour que le balayage supprime une série.
struct LiveExerciseCard: View {
    static let incrementChoices: [Double] = [1, 1.25, 2, 2.5, 5, 10]

    let model: LiveSessionModel
    let exercise: LiveExercise
    let index: Int
    let isLast: Bool
    @Binding var rpeSet: UUID?
    @State private var isShowingSheet = false
    @State private var isRemoving = false
    @State private var isEditingNote = false
    @State private var noteDraft = ""
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Section {
            header
                .listRowBackground(Self.background(top: true))
            if !typeSize.isAccessibilitySize {
                LiveColumnsHeader(loadKind: exercise.loadKind, tracksDuration: exercise.tracksDuration)
                    .listRowBackground(Self.background())
            }
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { position, set in
                LiveSetRow(model: model, exercise: exercise, exerciseIndex: index, set: set, index: position, rpeSet: $rpeSet)
                    .listRowBackground(Self.background())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await model.deleteSet(set.id) }
                        } label: {
                            Label(String(localized: "Supprimer la série", bundle: .module), systemImage: "trash")
                        }
                    }
            }
            addSetButton
                .listRowBackground(Self.background(bottom: true))
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    isShowingSheet = true
                } label: {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: LiveSetRow.targetHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(String(localized: "Ouvre la fiche de l'exercice", bundle: .module))
                details
            }
            menu
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .sheet(isPresented: $isShowingSheet) { exerciseSheet }
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

    @ViewBuilder
    private var details: some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        if let group = exercise.supersetGroup {
            Text(Self.supersetText(group: group))
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
        }
        if let lastTime = exercise.lastTimeText {
            Text(lastTime).font(.footnote).foregroundStyle(PulsePalette.text2)
        }
        if let dayNote = exercise.dayNote {
            Label(dayNote, systemImage: "sparkles").font(.footnote).foregroundStyle(accent)
        }
        if let cap = exercise.rpeCap {
            Text(Self.rpeCapText(cap)).font(.footnote.weight(.semibold)).foregroundStyle(PulsePalette.warn)
        }
        if let note = exercise.note {
            Text(note).font(.footnote.italic()).foregroundStyle(PulsePalette.text2)
        }
    }

    private var menu: some View {
        Menu {
            Button {
                noteDraft = exercise.note ?? ""
                isEditingNote = true
            } label: {
                Label(String(localized: "Note", bundle: .module), systemImage: "note.text")
            }
            Picker(String(localized: "Incrément", bundle: .module), selection: incrementBinding) {
                ForEach(Self.incrementChoices, id: \.self) { Text(Self.incrementText($0)).tag($0) }
            }
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
            Text(String(localized: "+ Ajouter une série", bundle: .module))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(PulsePalette.accent(for: theme).accent))
                .frame(maxWidth: .infinity, minHeight: LiveSetRow.targetHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    /// « 2,5 kg » : un incrément de charge.
    nonisolated static func incrementText(_ incrementKg: Double) -> String {
        String(localized: "\(PulseFormat.decimal(incrementKg, maxFractionDigits: 2)) kg", bundle: .module)
    }
}

/// Les titres des colonnes d'une carte, alignés sur les cellules de `LiveSetRow`.
private struct LiveColumnsHeader: View {
    let loadKind: LoadKind
    let tracksDuration: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(String(localized: "Série", bundle: .module)).frame(width: LiveSetRow.badgeWidth)
            Text(String(localized: "Précédent", bundle: .module)).frame(maxWidth: .infinity)
            Text(LiveSetRow.weightColumnTitle(for: loadKind)).frame(width: LiveSetRow.weightWidth)
            Text(tracksDuration ? String(localized: "Sec", bundle: .module) : String(localized: "Reps", bundle: .module))
                .frame(width: LiveSetRow.valueWidth)
            Text(String(localized: "RPE", bundle: .module)).frame(width: LiveSetRow.rpeWidth)
            Color.clear.frame(width: LiveSetRow.targetHeight, height: 1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(PulsePalette.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .accessibilityHidden(true)
    }
}
