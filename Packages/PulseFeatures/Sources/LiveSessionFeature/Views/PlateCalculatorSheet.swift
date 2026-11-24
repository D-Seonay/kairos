import PulseDesignSystem
import PulseRecoveryEngine
import PulseServices
import SwiftUI

/// Le calculateur de disques (spec M4 §19.2) : la charge de la série en cours, la barre chargée et les disques par côté. Sur une
/// charge impossible, les deux charges faisables les plus proches, qu'un toucher applique. ±2,5 kg change les séries de travail
/// restantes de l'exercice. La barre et les disques disponibles se règlent en bas et s'enregistrent dans le profil.
struct PlateCalculatorSheet: View {
    static let barChoices: [Double] = [10, 15, 20]
    static let plateChoices: [Double] = [25, 20, 15, 10, 5, 2.5, 2, 1.25, 1, 0.5]
    static let step = 2.5

    let model: LiveSessionModel
    let exerciseID: UUID
    @State private var barKg: Double?
    @State private var plates: Set<Double> = []
    @State private var hasLoaded = false
    @State private var saveFailed = false
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 52
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                    if let exercise {
                        loadCard(exercise)
                    }
                    settings
                }
                .padding(PulseMetrics.spacing)
            }
            .background(PulsePalette.background)
            .navigationTitle(String(localized: "Disques", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Fermer", bundle: .module)) { dismiss() }
                }
            }
        }
        .task { await load() }
        // Comme l'écran en direct et sa bibliothèque : la séance reste noire (spec M4 §14.2).
        .preferredColorScheme(.dark)
    }

    // MARK: Charge

    private var exercise: LiveExercise? {
        model.session.exercises.first { $0.id == exerciseID }
    }

    /// La charge de la première série de travail pas encore validée ; à défaut, celle de la dernière série.
    private func currentLoad(of exercise: LiveExercise) -> Double? {
        let working = exercise.sets.filter { $0.setType != .warmup }
        let current = working.first { $0.completedAt == nil } ?? working.last
        return current.flatMap { $0.weightKg ?? $0.proposed.weightKg }
    }

    private func loadCard(_ exercise: LiveExercise) -> some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "Série en cours", bundle: .module))
                    .pulseEyebrow()
                if let load = currentLoad(of: exercise) {
                    loaded(load, exercise: exercise)
                } else {
                    Text(String(localized: "Saisis une charge pour voir les disques.", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
    }

    private func result(for load: Double) -> PlateResult {
        PlateCalculator.load(targetKg: load, barKg: barKg ?? 20, availablePlatesKg: Array(plates))
    }

    /// Applique une charge aux séries restantes, puis dit la nouvelle charge et ses disques.
    private func apply(_ load: Double, exercise: LiveExercise) async {
        await model.setRemainingLoad(load, exercise: exercise.id)
        guard let updated = self.exercise, let current = currentLoad(of: updated) else { return }
        PulseAnnouncement.post(Self.loadAnnouncement(load: current, result: result(for: current)))
    }

    @ViewBuilder
    private func loaded(_ load: Double, exercise: LiveExercise) -> some View {
        let result = result(for: load)
        if typeSize.isAccessibilitySize {
            // La charge au-dessus, les deux boutons dessous : la valeur garde toute la largeur.
            VStack(spacing: 12) {
                loadText(load)
                HStack(spacing: 12) {
                    minusButton(load, exercise: exercise)
                    Spacer()
                    plusButton(load, exercise: exercise)
                }
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                minusButton(load, exercise: exercise)
                loadText(load)
                plusButton(load, exercise: exercise)
            }
        }
        switch result {
        case .exact(let loading):
            PlateBarDiagram(perSide: loading.perSide)
                .frame(height: 120)
            Text(Self.perSideText(loading))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
                .accessibilityLabel(Self.perSideSpokenText(loading))
        case .approximate(let lower, let upper):
            PlateBarDiagram(perSide: (lower ?? upper)?.perSide ?? [])
                .frame(height: 120)
            Text(String(localized: "Pas possible exactement avec tes disques. Les charges les plus proches :", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
            HStack(spacing: 8) {
                ForEach([lower, upper].compactMap { $0 }, id: \.totalKg) { choice in
                    Button(String(localized: "\(PulseFormat.decimal(choice.totalKg, maxFractionDigits: 2)) kg", bundle: .module)) {
                        Task { await apply(choice.totalKg, exercise: exercise) }
                    }
                    .buttonStyle(PillButtonStyle())
                    .accessibilityLabel(Self.choiceSpokenText(choice))
                }
            }
        }
        Text(String(localized: "La charge s'applique aux séries restantes de l'exercice.", bundle: .module))
            .font(.caption)
            .foregroundStyle(PulsePalette.muted)
    }

    private func loadText(_ load: Double) -> some View {
        Text(verbatim: "\(PulseFormat.decimal(load, maxFractionDigits: 2)) kg")
            .font(PulseFont.score(size: scoreSize))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .pulseNumericTransition(value: load)
            .pulseAnimation(.snappy, value: load)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Self.loadSpokenText(load))
    }

    private func minusButton(_ load: Double, exercise: LiveExercise) -> some View {
        stepButton(systemImage: "minus", label: String(localized: "Moins 2,5 kilos", bundle: .module)) {
            Task { await apply(max(0, load - Self.step), exercise: exercise) }
        }
    }

    private func plusButton(_ load: Double, exercise: LiveExercise) -> some View {
        stepButton(systemImage: "plus", label: String(localized: "Plus 2,5 kilos", bundle: .module)) {
            Task { await apply(load + Self.step, exercise: exercise) }
        }
    }

    private func stepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IconChip(systemName: systemImage, size: LiveSetRow.targetHeight)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }

    /// « Par côté : 25 + 15 kg » ; « Barre seule ».
    nonisolated static func perSideText(_ loading: PlateLoading) -> String {
        guard !loading.perSide.isEmpty else { return String(localized: "Barre seule", bundle: .module) }
        let plates = loading.perSide.map { PulseFormat.decimal($0, maxFractionDigits: 2) }.joined(separator: " + ")
        return String(localized: "Par côté : \(plates) kg", bundle: .module)
    }

    /// « Par côté : 25 kilos, 15 kilos et 1,25 kilo » ; « Barre seule ».
    nonisolated static func perSideSpokenText(_ loading: PlateLoading) -> String {
        guard let plates = spokenPlates(loading) else { return String(localized: "Barre seule", bundle: .module) }
        return String(localized: "Par côté : \(plates)", bundle: .module)
    }

    /// « Appliquer 90 kilos, par côté 25 kilos et 10 kilos » : un choix de charge faisable.
    nonisolated static func choiceSpokenText(_ loading: PlateLoading) -> String {
        let total = PulseSpoken.kilos(loading.totalKg)
        guard let plates = spokenPlates(loading) else {
            return String(localized: "Appliquer \(total), barre seule", bundle: .module)
        }
        return String(localized: "Appliquer \(total), par côté \(plates)", bundle: .module)
    }

    /// « Charge 62,5 kilos ».
    nonisolated static func loadSpokenText(_ load: Double) -> String {
        String(localized: "Charge \(PulseSpoken.kilos(load))", bundle: .module)
    }

    /// Dit après ±2,5 kg ou un choix : « 70 kilos. Par côté : 20 kilos et 5 kilos » ; « 71 kilos. Pas possible exactement avec
    /// tes disques ».
    nonisolated static func loadAnnouncement(load: Double, result: PlateResult) -> String {
        let total = PulseSpoken.kilos(load)
        switch result {
        case .exact(let loading):
            return String(localized: "\(total). \(perSideSpokenText(loading))", bundle: .module)
        case .approximate:
            return String(localized: "\(total). Pas possible exactement avec tes disques", bundle: .module)
        }
    }

    /// « 2,5 kilos » : une pilule de barre ou de disque.
    nonisolated static func plateSpokenText(_ kg: Double) -> String {
        PulseSpoken.kilos(kg)
    }

    /// « 25 kilos, 15 kilos et 1,25 kilo » ; `nil` pour la barre seule.
    private nonisolated static func spokenPlates(_ loading: PlateLoading) -> String? {
        let plates = loading.perSide.map(PulseSpoken.kilos)
        guard let last = plates.last else { return nil }
        guard plates.count > 1 else { return last }
        let head = plates.dropLast().joined(separator: ", ")
        return String(localized: "\(head) et \(last)", bundle: .module)
    }

    // MARK: Barre et disques

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(String(localized: "Barre et disques", bundle: .module))
            Text(String(localized: "Barre", bundle: .module)).pulseEyebrow()
            ChoicePills(options: Self.barChoices.map { ($0, Self.kilos($0)) }, selection: $barKg,
                        groupLabel: String(localized: "Barre", bundle: .module), spokenLabel: { Self.plateSpokenText($0) })
            Text(String(localized: "Disques disponibles", bundle: .module)).pulseEyebrow()
            MultiChoicePills(options: Self.plateChoices.map { ($0, Self.kilos($0)) }, selection: $plates,
                             groupLabel: String(localized: "Disques disponibles", bundle: .module),
                             spokenLabel: { Self.plateSpokenText($0) })
            if let message = saveFailureMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.bad)
            }
        }
        .pulseAnnounceError(saveFailureMessage)
        .onChange(of: barKg) { save() }
        .onChange(of: plates) { save() }
    }

    private var saveFailureMessage: String? {
        saveFailed ? String(localized: "Pulse n'a pas pu enregistrer ta barre et tes disques.", bundle: .module) : nil
    }

    private static func kilos(_ value: Double) -> String {
        String(localized: "\(PulseFormat.decimal(value, maxFractionDigits: 2)) kg", bundle: .module)
    }

    private func load() async {
        guard !hasLoaded, let current = try? await model.environment.service.barAndPlates() else { return }
        barKg = current.barKg
        plates = Set(current.platesKg)
        hasLoaded = true
    }

    private func save() {
        guard hasLoaded, let barKg else { return }
        Task {
            do {
                try await model.environment.service.saveBarAndPlates(barKg: barKg, platesKg: Array(plates))
                saveFailed = false
            } catch {
                saveFailed = true
            }
        }
    }
}
