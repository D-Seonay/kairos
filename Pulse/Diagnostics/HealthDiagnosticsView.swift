import PulseDomain
import PulseHealth
import PulseRecoveryEngine
import SwiftUI

/// Écran de diagnostic M1, ouvert depuis le profil : sources Apple Santé, 14 dernières nuits et score provisoire. Sans style.
struct HealthDiagnosticsView: View {
    @State private var model: HealthDiagnosticsModel

    init(model: HealthDiagnosticsModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        List {
            statusSection
            sourcesSection
            nightsSection
            scoreSection
        }
        .navigationTitle(String(localized: "Diagnostic Apple Santé"))
        .task { await model.refresh() }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section(String(localized: "État")) {
            if model.isLoading {
                Label(String(localized: "Lecture en cours…"), systemImage: "arrow.triangle.2.circlepath")
            } else if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
            } else {
                Label(String(localized: "Lecture terminée"), systemImage: "checkmark.circle")
            }
            Button(String(localized: "Relire Apple Santé")) {
                Task { await model.refresh() }
            }
            .disabled(model.isLoading)
        }
    }

    private var sourcesSection: some View {
        Section(String(localized: "Sources")) {
            ForEach(model.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.type.title).font(.headline)
                        Spacer()
                        Text(String(localized: "\(row.countLast60Days) sur 60 j")).foregroundStyle(.secondary)
                    }
                    if let latest = row.latest {
                        Text(latest.valueText)
                        HStack {
                            Text(latest.date, format: .relative(presentation: .named))
                            Text("·")
                            Text(latest.sourceName)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(String(localized: "Aucune donnée")).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var nightsSection: some View {
        Section(String(localized: "14 dernières nuits")) {
            ForEach(model.nights.suffix(14).reversed(), id: \.day) { night in
                HStack {
                    Text(night.day, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .frame(width: 96, alignment: .leading)
                    Text(Self.text(night.sdnnMs, unit: "ms"))
                    Spacer()
                    Text(Self.text(night.restingHeartRate, unit: "bpm"))
                    Spacer()
                    Text(Self.sleepText(night.sleep))
                }
                .font(.footnote.monospacedDigit())
            }
        }
    }

    @ViewBuilder
    private var scoreSection: some View {
        Section(String(localized: "Score provisoire")) {
            switch model.outcome {
            case .measured(let result)?:
                Text("\(Int(result.score.rounded()))").font(.largeTitle.bold())
                Text(Self.categoryName(result.category))
                Text(Self.calibrationText(result.calibration)).foregroundStyle(.secondary)
                if !result.missing.isEmpty {
                    Text(String(localized: "Facteurs manquants : \(result.missing.map(Self.factorName).joined(separator: ", "))"))
                        .foregroundStyle(.secondary)
                }
            case .needsCheckIn(let missing)?:
                Text(String(localized: "Check-in nécessaire : \(missing.map(Self.factorName).joined(separator: ", "))"))
            case nil:
                Text(String(localized: "Pas encore calculé")).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Formats

    private static func text(_ value: Double?, unit: String) -> String {
        guard let value else { return "–" }
        return "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit)"
    }

    private static func sleepText(_ sleep: SleepSummary?) -> String {
        guard let sleep else { return "–" }
        let total = "\(sleep.asleepMinutes / 60) h \(String(format: "%02d", sleep.asleepMinutes % 60))"
        guard let deep = sleep.deepMinutes else { return total }
        return "\(total) · \(deep) min"
    }

    static func categoryName(_ category: RecoveryCategory) -> String {
        switch category {
        case .optimal: String(localized: "Optimal")
        case .normal: String(localized: "Normal")
        case .moderateFatigue: String(localized: "Fatigue modérée")
        case .overreached: String(localized: "Surmenage")
        }
    }

    static func calibrationText(_ state: CalibrationState) -> String {
        switch state {
        case .ready: String(localized: "Ligne de base complète (14 nuits)")
        case .calibrating(let nights): String(localized: "En calibration : \(nights) nuit(s) sur 14")
        }
    }

    static func factorName(_ factor: Factor) -> String {
        switch factor {
        case .hrv: String(localized: "VFC")
        case .restingHeartRate: String(localized: "FC au repos")
        case .sleep: String(localized: "Sommeil")
        }
    }
}

#Preview {
    NavigationStack {
        HealthDiagnosticsView(model: HealthDiagnosticsModel(dependencies: .preview()))
    }
}
