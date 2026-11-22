import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La feuille « Modifier » du détail d'une séance (spec M6 §8) : RPE global et note, puis pour chaque exercice ses séries hors
/// échauffement (charge, répétitions ou durée tenue, RPE). Un balayage retire une série.
struct SessionCorrectionView: View {
    let blocks: [(name: String, setIDs: [UUID])]
    let onSave: (SessionCorrection) async -> Bool
    @State private var correction: SessionCorrection
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(correction: SessionCorrection, blocks: [(name: String, setIDs: [UUID])], onSave: @escaping (SessionCorrection) async -> Bool) {
        _correction = State(initialValue: correction)
        self.blocks = blocks
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                RPEPicker(title: String(localized: "RPE de la séance", bundle: .module), value: $correction.overallRPE)
                TextField(String(localized: "Note", bundle: .module), text: $correction.note, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text(String(localized: "Ressenti", bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
            ForEach(blocks, id: \.name) { block in
                let indices = block.setIDs.compactMap { id in visibleIndex(of: id) }
                if !indices.isEmpty {
                    Section {
                        ForEach(Array(indices.enumerated()), id: \.element) { position, index in
                            SetCorrectionRow(number: position + 1, correction: $correction.sets[index])
                                .swipeActions {
                                    Button(role: .destructive) {
                                        correction.removedSetIDs.insert(correction.sets[index].id)
                                    } label: {
                                        Label(String(localized: "Retirer", bundle: .module), systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(block.name)
                    }
                    .listRowBackground(PulsePalette.surface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulsePalette.background)
        .navigationTitle(String(localized: "Modifier la séance", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module)) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer", bundle: .module)) {
                    Task {
                        isSaving = true
                        if await onSave(correction) { dismiss() }
                        isSaving = false
                    }
                }
                .disabled(isSaving)
                .accessibilityIdentifier(TrainIdentifiers.sessionCorrectionSave)
            }
        }
    }

    private func visibleIndex(of id: UUID) -> Int? {
        guard !correction.removedSetIDs.contains(id) else { return nil }
        return correction.sets.firstIndex { $0.id == id }
    }
}

/// Une série corrigée : charge et répétitions, ou durée tenue pour une série minutée ; son RPE. Les champs côte à côte passent
/// l'un sous l'autre aux tailles d'accessibilité.
private struct SetCorrectionRow: View {
    let number: Int
    @Binding var correction: SetCorrection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Série \(number)", bundle: .module))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            layout {
                field(String(localized: "kg", bundle: .module), spoken: TrainText.correctionFieldLabel(.weight, setNumber: number),
                      value: $correction.weightKg, format: .number.precision(.fractionLength(0...2)))
                    .pulseNumericKeyboard()
                if correction.durationSeconds != nil && correction.reps == nil {
                    field(String(localized: "s", bundle: .module),
                          spoken: TrainText.correctionFieldLabel(.duration, setNumber: number),
                          value: $correction.durationSeconds, format: .number)
                        .pulseNumericKeyboard()
                } else {
                    field(String(localized: "reps", bundle: .module),
                          spoken: TrainText.correctionFieldLabel(.reps, setNumber: number),
                          value: $correction.reps, format: .number)
                        .pulseNumericKeyboard()
                }
            }
            RPEPicker(title: String(localized: "RPE de la série \(number)", bundle: .module),
                      shortTitle: String(localized: "RPE", bundle: .module), value: $correction.rpe)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    /// Un champ numérique : l'unité visible reste à l'écran, VoiceOver lit le nom parlé du champ (« Charge de la série 2, en kilos »).
    private func field<Value, Format: ParseableFormatStyle>(_ unit: String, spoken: String, value: Binding<Value?>, format: Format)
        -> some View where Format.FormatInput == Value, Format.FormatOutput == String {
        HStack(spacing: 4) {
            TextField(unit, value: value, format: format)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .accessibilityLabel(spoken)
            Text(unit)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(PulsePalette.surface2, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny))
    }
}

/// Un RPE de 5 à 10 par demi-point, ou aucun. `shortTitle` est l'intitulé visible quand `title` est plus long que la place
/// n'en laisse (« RPE » pour « RPE de la série 2 »).
struct RPEPicker: View {
    let title: String
    var shortTitle: String?
    @Binding var value: Double?

    private static let values: [Double] = stride(from: 5.0, through: 10.0, by: 0.5).map { $0 }

    var body: some View {
        Picker(selection: $value) {
            Text(String(localized: "—", bundle: .module))
                .accessibilityLabel(String(localized: "Aucun", bundle: .module))
                .tag(Double?.none)
            ForEach(Self.values, id: \.self) { rpe in
                Text(PulseFormat.decimal(rpe, maxFractionDigits: 1)).tag(Double?.some(rpe))
            }
        } label: {
            Text(shortTitle ?? title)
        }
        .accessibilityLabel(title)
    }
}
