import PhotosFeature
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le récap de la course (spec V2a §4.5) : le tracé, le bilan (temps en mouvement, distance, allure moyenne, dénivelé positif si
/// l'altitude est fiable, FC moyenne si disponible), les temps par km, le RPE global sans valeur présélectionnée et la note.
/// « Enregistrer » écrit le RPE et la note ; « Supprimer la course » demande une confirmation.
struct RunRecapView: View {
    @Bindable var model: RunRecapModel
    let calendar: Calendar
    @State private var confirmsDelete = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !model.points.isEmpty {
                    RunRouteMap(points: model.points, distanceMeters: model.distanceMeters)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
                }
                stats
                notices
                if !model.splits.isEmpty {
                    ObsidianCard {
                        VStack(alignment: .leading, spacing: 4) {
                            PulseSectionHeader(String(localized: "Temps par kilomètre", bundle: .module))
                            RunSplitsList(splits: model.splits)
                        }
                    }
                }
                ObsidianCard { RunEffortPicker(selection: $model.rpe) }
                noteField
                if let photos = model.photos { SessionPhotosSection(model: photos) }
                RunErrorLine(message: model.errorMessage)
            }
            .padding(PulseMetrics.spacing)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(String(localized: "Récap", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareCardButton(content: model.shareContent(calendar: calendar), photos: model.photos?.shareCardPhotos ?? [])
            }
        }
        .pulseScreenBackground(aura: 0.5)
        .pulseAnnounceError(model.errorMessage)
        .runActionBar(opaque: true) { actions }
        .confirmationDialog(String(localized: "Supprimer la course ?", bundle: .module), isPresented: $confirmsDelete,
                            titleVisibility: .visible) {
            Button(String(localized: "Supprimer", bundle: .module), role: .destructive) { Task { await model.delete() } }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: {
            Text(String(localized: "La course, son tracé et l'entraînement écrit dans Apple Santé sont supprimés.", bundle: .module))
        }
    }

    // MARK: Bilan

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Course terminée", bundle: .module))
                .font(PulseFont.title(.title2))
                .accessibilityAddTraits(.isHeader)
            Text(Self.subtitle(title: model.title, date: model.data.session.startedAt, calendar: calendar))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
        }
    }

    /// « Footing facile · mardi 24 novembre ».
    static func subtitle(title: String, date: Date, calendar: Calendar) -> String {
        let day = "\(PulseSpoken.weekday(date, calendar: calendar)) \(PulseSpoken.date(date, calendar: calendar))"
        return title.isEmpty ? day : "\(title) · \(day)"
    }

    private var stats: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            stat(RunText.elapsed(seconds: model.movingSeconds), String(localized: "En mouvement", bundle: .module),
                 spoken: RunText.elapsedSpoken(seconds: model.movingSeconds))
            stat(RunText.distance(model.distanceMeters), String(localized: "Distance", bundle: .module),
                 spoken: RunText.distanceSpoken(model.distanceMeters) ?? String(localized: "non mesurée", bundle: .module))
            if model.distanceMeters != nil {
                stat(RunText.pace(model.averagePace), String(localized: "Allure moyenne", bundle: .module),
                     spoken: RunText.paceSpoken(model.averagePace))
            }
            if let gain = model.elevationGain {
                stat(RunText.elevation(gain), String(localized: "Dénivelé", bundle: .module), spoken: RunText.elevationSpoken(gain))
            }
            if let bpm = model.averageHeartRate {
                stat(RunText.heartRate(bpm), String(localized: "FC moyenne", bundle: .module), spoken: RunText.heartRateSpoken(bpm))
            }
        }
    }

    private func stat(_ value: String, _ name: String, spoken: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PulseFont.value(.title))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(name)
                .pulseEyebrow()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(spoken)
    }

    @ViewBuilder
    private var notices: some View {
        if model.distanceMeters == nil {
            RunNoticeLine(text: RunText.locationDenied, systemImage: "location.slash")
        } else if model.startedWithoutSignal {
            RunNoticeLine(text: String(localized: "Parti avant le signal : la distance compte depuis le premier point GPS précis.",
                                       bundle: .module), systemImage: "location")
        }
    }

    // MARK: Note et actions

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Note", bundle: .module))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text2)
            TextField(String(localized: "Comment s'est passée la course ?", bundle: .module), text: $model.note, axis: .vertical)
                .lineLimit(2...6)
                .padding(12)
                .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous))
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                Task { await model.save() }
            } label: {
                Text(model.errorMessage == nil ? String(localized: "Enregistrer", bundle: .module)
                    : String(localized: "Réessayer", bundle: .module))
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(RunIdentifiers.recapSave)
            Button(role: .destructive) {
                confirmsDelete = true
            } label: {
                Text(String(localized: "Supprimer la course", bundle: .module))
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(RunIdentifiers.recapDelete)
        }
        .disabled(model.isSaving)
    }
}

#if DEBUG
#Preview("Récap") {
    @Previewable @State var coordinator = RunPreviewSupport.recapCoordinator()
    RunFlowView(model: coordinator.model())
}

#Preview("Récap, accessibilité 3") {
    @Previewable @State var coordinator = RunPreviewSupport.recapCoordinator()
    RunFlowView(model: coordinator.model())
        .dynamicTypeSize(.accessibility3)
}
#endif
