import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'écran de la course en cours (spec V2a §4.3, croquis) : l'objectif, le temps en gros, la distance, l'allure du km en cours et
/// la moyenne, la progression de l'objectif, la FC si la séance en livre, puis « Pause » et « Terminer ». Pas de carte en direct.
/// « Terminer » demande une confirmation, accessible au clavier et à VoiceOver.
struct RunView: View {
    let model: RunModel
    @State private var confirmsFinish = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if let snapshot = model.snapshot {
                content(snapshot)
            } else {
                ProgressView()
                    .accessibilityLabel(String(localized: "Reprise de la course", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "Course", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    model.minimize()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel(String(localized: "Réduire la course", bundle: .module))
                .accessibilityHint(String(localized: "La course continue en arrière-plan", bundle: .module))
                .accessibilityIdentifier(RunIdentifiers.minimizeButton)
            }
        }
        .pulseScreenBackground(aura: 0.5)
        .pulseAnnounceError(model.errorMessage)
        .onChange(of: model.snapshot?.distanceMeters) { previous, current in
            // Le passage d'un km est dit à VoiceOver sans couper la parole en cours, seulement sans annonces vocales.
            if let text = model.kilometerAnnouncement(from: previous, to: current) { PulseAnnouncement.post(text, priority: .low) }
        }
        .confirmationDialog(String(localized: "Terminer la course ?", bundle: .module), isPresented: $confirmsFinish,
                            titleVisibility: .visible) {
            Button(String(localized: "Terminer", bundle: .module)) { Task { await model.finish() } }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        }
    }

    private func content(_ snapshot: RunSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                header(snapshot)
                RunLiveMetrics(snapshot: snapshot)
                notices(snapshot)
                RunAnnouncesToggle(model: model)
                RunErrorLine(message: model.errorMessage)
            }
            .padding(PulseMetrics.spacing)
        }
        .runActionBar { buttons(snapshot) }
    }

    // MARK: En-tête

    private func header(_ snapshot: RunSnapshot) -> some View {
        VStack(spacing: 4) {
            Text(RunText.goalLine(snapshot.launch))
                .font(.headline)
                .foregroundStyle(PulsePalette.text)
                .multilineTextAlignment(.center)
                .accessibilityLabel(Self.goalSpoken(snapshot.launch))
                .accessibilityAddTraits(.isHeader)
            if let note = snapshot.launch.adjustmentNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .multilineTextAlignment(.center)
            }
            if snapshot.isPaused {
                Text(String(localized: "En pause", bundle: .module))
                    .pulseEyebrow(PulsePalette.text)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// « Footing facile, Objectif : 30 minutes ».
    static func goalSpoken(_ launch: RunLaunch) -> String {
        guard let goal = RunText.goalSpoken(launch) else { return launch.title }
        return "\(launch.title), \(goal)"
    }

    @ViewBuilder
    private func notices(_ snapshot: RunSnapshot) -> some View {
        if let notice = model.locationNotice {
            RunNoticeLine(text: notice, systemImage: "location.slash")
        } else if snapshot.gps != .ready {
            RunNoticeLine(text: RunText.gpsStatus(snapshot.gps), systemImage: "location")
        }
    }

    // MARK: Pause et Terminer

    /// Côte à côte, l'un sous l'autre aux tailles de texte d'accessibilité.
    private func buttons(_ snapshot: RunSnapshot) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button {
                Task { snapshot.isPaused ? await model.resume() : await model.pause() }
            } label: {
                Text(snapshot.isPaused ? String(localized: "Reprendre", bundle: .module) : String(localized: "Pause", bundle: .module))
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel(snapshot.isPaused ? String(localized: "Reprendre la course", bundle: .module)
                                : String(localized: "Mettre la course en pause", bundle: .module))
            .accessibilityIdentifier(RunIdentifiers.pauseButton)
            Button {
                confirmsFinish = true
            } label: {
                Text(String(localized: "Terminer", bundle: .module))
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel(String(localized: "Terminer la course", bundle: .module))
            .accessibilityIdentifier(RunIdentifiers.finishButton)
        }
        .disabled(model.isBusy)
    }
}

#if DEBUG
#Preview("Course en cours") {
    @Previewable @State var coordinator = RunPreviewSupport.runningCoordinator()
    RunFlowView(model: coordinator.model())
}

#Preview("Course en pause") {
    @Previewable @State var coordinator = RunPreviewSupport.runningCoordinator(paused: true)
    RunFlowView(model: coordinator.model())
}

#Preview("Localisation refusée") {
    @Previewable @State var coordinator = RunPreviewSupport.runningCoordinator(locationDenied: true)
    RunFlowView(model: coordinator.model())
}

#Preview("Course, accessibilité 3") {
    @Previewable @State var coordinator = RunPreviewSupport.runningCoordinator()
    RunFlowView(model: coordinator.model())
        .dynamicTypeSize(.accessibility3)
}
#endif
