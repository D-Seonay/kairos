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
    @Environment(\.dismiss) private var dismiss

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

    @ViewBuilder
    private func loaded(_ load: Double, exercise: LiveExercise) -> some View {
        let result = PlateCalculator.load(targetKg: load, barKg: barKg ?? 20, availablePlatesKg: Array(plates))
        HStack(alignment: .center, spacing: 12) {
            stepButton(systemImage: "minus", label: String(localized: "Moins 2,5 kilos", bundle: .module)) {
                Task { await model.setRemainingLoad(max(0, load - Self.step), exercise: exercise.id) }
            }
            Text(verbatim: "\(PulseFormat.decimal(load, maxFractionDigits: 2)) kg")
                .font(PulseFont.score(size: 52))
                .contentTransition(.numericText(value: load))
                .animation(.snappy, value: load)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(String(localized: "Charge \(PulseFormat.decimal(load, maxFractionDigits: 2)) kilos",
                                           bundle: .module))
            stepButton(systemImage: "plus", label: String(localized: "Plus 2,5 kilos", bundle: .module)) {
                Task { await model.setRemainingLoad(load + Self.step, exercise: exercise.id) }
            }
        }
        switch result {
        case .exact(let loading):
            PlateBarDiagram(perSide: loading.perSide)
                .frame(height: 120)
            Text(Self.perSideText(loading))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
        case .approximate(let lower, let upper):
            PlateBarDiagram(perSide: (lower ?? upper)?.perSide ?? [])
                .frame(height: 120)
            Text(String(localized: "Impossible tout juste avec tes disques. Les charges les plus proches :", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
            HStack(spacing: 8) {
                ForEach([lower, upper].compactMap { $0 }, id: \.totalKg) { choice in
                    Button(String(localized: "\(PulseFormat.decimal(choice.totalKg, maxFractionDigits: 2)) kg", bundle: .module)) {
                        Task { await model.setRemainingLoad(choice.totalKg, exercise: exercise.id) }
                    }
                    .buttonStyle(PillButtonStyle())
                }
            }
        }
        Text(String(localized: "La charge s'applique aux séries restantes de l'exercice.", bundle: .module))
            .font(.caption)
            .foregroundStyle(PulsePalette.muted)
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

    // MARK: Barre et disques

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(String(localized: "Barre et disques", bundle: .module))
            Text(String(localized: "Barre", bundle: .module)).pulseEyebrow()
            ChoicePills(options: Self.barChoices.map { ($0, Self.kilos($0)) }, selection: $barKg)
            Text(String(localized: "Disques disponibles", bundle: .module)).pulseEyebrow()
            MultiChoicePills(options: Self.plateChoices.map { ($0, Self.kilos($0)) }, selection: $plates)
            if saveFailed {
                Text(String(localized: "Pulse n'a pas pu enregistrer ta barre et tes disques.", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.bad)
            }
        }
        .onChange(of: barKg) { save() }
        .onChange(of: plates) { save() }
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
