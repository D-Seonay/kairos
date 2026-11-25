import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// L'écran de départ (spec V2a §4.2) : l'objectif ou « Course libre », l'état du GPS, l'interrupteur des annonces vocales et un
/// gros bouton « Partir ». On peut partir sans signal prêt. Le suivi du signal démarre à l'apparition et s'arrête à la sortie.
struct RunStartView: View {
    let model: RunModel
    let launch: RunLaunch
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                goalCard
                gpsCard
                if let notice = model.locationNotice { RunNoticeLine(text: notice, systemImage: "location.slash") }
                if let notice = model.approximateNotice { RunApproximateLocationNotice(text: notice) }
                RunAnnouncesToggle(model: model)
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.signal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(PulseMetrics.spacing)
        }
        .navigationTitle(String(localized: "Course", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module)) { Task { await model.cancel() } }
                    .accessibilityIdentifier(RunIdentifiers.cancelButton)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { startButton }
        .pulseScreenBackground(aura: 0.5)
        .pulseAnnounceError(model.errorMessage)
        .pulseAnnounce(model.gps == .ready ? Self.readySpoken : nil)
        .task { await model.watchGPS() }
        .onDisappear { Task { await model.cancelPreview() } }
    }

    // MARK: Objectif

    private var goalCard: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Objectif", bundle: .module))
                    .pulseEyebrow()
                Text(launch.title)
                    .font(PulseFont.title(.title2))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let goal = RunText.goal(launch) {
                    Text(goal)
                        .font(PulseFont.value(.title3))
                        .foregroundStyle(PulsePalette.text2)
                        .accessibilityLabel(RunText.goalSpoken(launch) ?? goal)
                }
                if let note = launch.adjustmentNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: GPS

    private var gpsCard: some View {
        let quality = model.gps ?? .searching
        return ObsidianCard {
            HStack(spacing: 14) {
                IconChip(systemName: model.locationDenied ? "location.slash" : "location.fill",
                         tone: quality == .ready && !model.locationDenied ? .inverted : .neutral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "GPS", bundle: .module))
                        .pulseEyebrow()
                    Text(gpsStatus(quality))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Sans position exacte, le signal ne deviendra jamais prêt : pas d'attente affichée.
                if !model.locationDenied, model.approximateNotice == nil, quality != .ready, !typeSize.isAccessibilitySize {
                    ProgressView().accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Signal GPS", bundle: .module))
            .accessibilityValue(gpsStatus(quality))
            .accessibilityIdentifier(RunIdentifiers.gpsStatus)
        }
    }

    /// « Indisponible » sans localisation, « Position approximative » sans position exacte, sinon l'état du signal.
    private func gpsStatus(_ quality: RunGPSQuality) -> String {
        if model.locationDenied { return String(localized: "Indisponible", bundle: .module) }
        if model.approximateNotice != nil, quality != .ready { return RunText.approximateStatus }
        return RunText.gpsStatus(quality)
    }

    private static var readySpoken: String {
        String(localized: "Signal GPS prêt", bundle: .module)
    }

    // MARK: Partir

    private var startButton: some View {
        Button {
            Task { await model.start() }
        } label: {
            Text(String(localized: "Partir", bundle: .module))
                .font(PulseFont.title(.title3, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(model.isBusy)
        .accessibilityHint(model.gps == .ready || model.locationDenied ? ""
                           : String(localized: "La distance comptera dès le premier signal précis", bundle: .module))
        .accessibilityIdentifier(RunIdentifiers.startButton)
        .padding(.horizontal, PulseMetrics.spacing)
        .padding(.vertical, 8)
    }
}

/// Une ligne d'avertissement, en une phrase, avec son icône : la localisation refusée, la distance comptée en retard.
struct RunNoticeLine: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage).accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(PulsePalette.text2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La position exacte est coupée pour Pulse : la phrase qui l'explique, et un bouton vers les réglages de Pulse dans iOS.
struct RunApproximateLocationNotice: View {
    let text: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RunNoticeLine(text: text, systemImage: "location.slash")
            #if canImport(UIKit)
            Button(String(localized: "Ouvrir les réglages", bundle: .module)) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PillButtonStyle())
            .accessibilityHint(String(localized: "Ouvre les réglages de Pulse dans iOS, où activer la position exacte",
                                      bundle: .module))
            .accessibilityIdentifier(RunIdentifiers.locationSettingsButton)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// L'interrupteur des annonces vocales à chaque kilomètre, mémorisé par appareil.
struct RunAnnouncesToggle: View {
    @Bindable var model: RunModel

    var body: some View {
        Toggle(isOn: $model.announcesKilometres) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Annonces vocales", bundle: .module))
                    .font(.headline)
                Text(String(localized: "Distance, temps et allure à chaque kilomètre", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(PulsePalette.run)
        .padding(PulseMetrics.spacing)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
        .accessibilityIdentifier(RunIdentifiers.announcesToggle)
    }
}

#if DEBUG
#Preview("Départ") {
    @Previewable @State var coordinator = RunPreviewSupport.startCoordinator()
    RunFlowView(model: coordinator.model())
}

#Preview("Départ, accessibilité 3") {
    @Previewable @State var coordinator = RunPreviewSupport.startCoordinator()
    RunFlowView(model: coordinator.model())
        .dynamicTypeSize(.accessibility3)
}
#endif
