import PulseDesignSystem
import SwiftUI

/// Le parcours d'import Hevy (spec M4 §13.3) : explication, résumé, correspondance, import avec progression puis bilan.
/// À présenter dans la pile de l'onglet « Séance » ; `onShowHistory` ouvre l'historique, `onFinish` quitte le parcours.
public struct HevyImportFlow: View {
    @State private var model: HevyImportModel
    private let onShowHistory: () -> Void
    private let onFinish: () -> Void

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: HevyImportModel, onShowHistory: @escaping () -> Void = {}, onFinish: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        self.onShowHistory = onShowHistory
        self.onFinish = onFinish
    }

    public var body: some View {
        content
            .background(PulsePalette.background)
            .navigationTitle(String(localized: "Importer depuis Hevy", bundle: .module))
            .pulseInlineTitle()
            .navigationBarBackButtonHidden(isImporting)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .intro:
            HevyIntroView(model: model)
        case .reading:
            HevyProgressView(title: String(localized: "Lecture du fichier…", bundle: .module), progress: nil)
        case .summary:
            HevySummaryView(model: model)
        case .mapping:
            HevyMappingView(model: model)
        case .importing(let progress):
            HevyProgressView(title: String(localized: "Import en cours…", bundle: .module), progress: progress)
        case .done(let result):
            HevyResultView(result: result, onShowHistory: onShowHistory, onFinish: onFinish)
        case .failed(let message):
            HevyFailureView(message: message, canReturnToMapping: model.preview != nil, model: model)
        }
    }

    private var isImporting: Bool {
        if case .importing = model.step { return true }
        return false
    }
}

/// Une attente : le fichier est lu, ou l'import tourne (avec sa part faite).
private struct HevyProgressView: View {
    let title: String
    let progress: Double?

    var body: some View {
        VStack(spacing: 16) {
            if let progress {
                ProgressView(value: progress)
                    .accessibilityLabel(title)
                    .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(PulsePalette.text)
            if progress != nil {
                Text(String(localized: "Garde l'écran ouvert jusqu'à la fin.", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
        }
        .multilineTextAlignment(.center)
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Ce qui a échoué, et comment repartir : revenir à la correspondance (échec de l'import) ou choisir un autre fichier.
private struct HevyFailureView: View {
    let message: String
    let canReturnToMapping: Bool
    let model: HevyImportModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(PulsePalette.warn)
                .accessibilityHidden(true)
            Text(message)
                .font(.headline)
                .foregroundStyle(PulsePalette.text)
                .multilineTextAlignment(.center)
            if canReturnToMapping {
                Button(String(localized: "Revenir aux correspondances", bundle: .module)) { model.showMapping() }
                    .buttonStyle(PrimaryButtonStyle())
                restartButton
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                restartButton
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var restartButton: some View {
        Button(String(localized: "Choisir un autre fichier", bundle: .module)) { model.restart() }
            .accessibilityIdentifier(TrainIdentifiers.hevyImportRestart)
    }
}
