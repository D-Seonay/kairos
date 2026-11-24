import PhotosFeature
import PulseDesignSystem
import PulseDomain
import RunFeature
import SwiftUI

/// Le détail d'une course ou d'un vélo lu d'Apple Santé (spec M6 §7) : mesures, RPE et note modifiables. Une course Pulse
/// ajoute la section « Tracé » : la carte du parcours et les temps par kilomètre. Tant qu'une correction n'est pas enregistrée,
/// le retour cède la place à « Annuler », qui demande confirmation avant d'abandonner.
struct ActivityDetailView: View {
    @State private var model: ActivityDetailModel
    @State private var confirmsDiscard = false
    @Environment(\.dismiss) private var dismiss
    private static let rpeValues: [Double] = stride(from: 1.0, through: 10.0, by: 0.5).map { $0 }

    init(model: ActivityDetailModel) {
        _model = State(initialValue: model)
    }

    /// La carte du tracé, puis les temps par kilomètre ; chacun n'apparaît que s'il y a de quoi le montrer.
    private func routeSection(_ track: RunTrack) -> some View {
        Section {
            if !track.points.isEmpty {
                RunRouteMap(points: track.points, distanceMeters: model.session?.distanceMeters)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
                    .listRowInsets(EdgeInsets())
            }
            if !track.splits.isEmpty {
                RunSplitsList(splits: track.splits)
            }
        } header: {
            Text(String(localized: "Tracé", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    var body: some View {
        @Bindable var model = model
        List {
            if let message = model.errorMessage {
                Section {
                    Text(message).font(.footnote).foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
            if model.session != nil {
                Section {
                    Text(model.dateText)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                    ForEach(model.metrics, id: \.label) { metric in
                        LabeledContent(metric.label, value: metric.value)
                            .foregroundStyle(PulsePalette.text)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(metric.label)
                            .accessibilityValue(metric.spokenValue)
                    }
                }
                .listRowBackground(PulsePalette.surface)
                if let track = model.routeTrack {
                    routeSection(track)
                }
                Section {
                    Picker(String(localized: "RPE ressenti", bundle: .module), selection: $model.rpe) {
                        Text(String(localized: "—", bundle: .module))
                            .accessibilityLabel(String(localized: "Non renseigné", bundle: .module))
                            .tag(Double?.none)
                        ForEach(Self.rpeValues, id: \.self) { rpe in
                            Text(PulseFormat.decimal(rpe, maxFractionDigits: 1)).tag(Double?.some(rpe))
                        }
                    }
                    TextField(String(localized: "Note", bundle: .module), text: $model.note, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text(String(localized: "Ressenti", bundle: .module))
                } footer: {
                    Text(String(localized: "Le RPE ressenti remplace le RPE estimé dans ta charge d'entraînement.", bundle: .module))
                }
                .listRowBackground(PulsePalette.surface)
                if let photos = model.photos {
                    Section {
                        SessionPhotosSection(model: photos)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text(model.session?.source == .pulse
                        ? String(localized: "Cette course a été enregistrée avec Pulse.", bundle: .module)
                        : String(localized: "Cet entraînement vient d'Apple Santé. Pour le supprimer, supprime-le dans l'app Santé.",
                                 bundle: .module))
                }
            } else if model.hasLoaded {
                Text(String(localized: "Cet entraînement est introuvable. Il a peut-être été supprimé d'Apple Santé.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                    .listRowBackground(PulsePalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulsePalette.background)
        .navigationTitle(model.session?.title ?? String(localized: "Course", bundle: .module))
        .pulseInlineTitle()
        .pulseAnnounceError(model.errorMessage)
        // Le retour, et son geste, abandonneraient le RPE et la note sans rien dire.
        .navigationBarBackButtonHidden(model.hasChanges)
        .toolbar {
            if model.hasChanges {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Annuler", bundle: .module)) { confirmsDiscard = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Enregistrer", bundle: .module)) { Task { await model.save() } }
                }
            }
        }
        .confirmationDialog(String(localized: "Abandonner les modifications ?", bundle: .module), isPresented: $confirmsDiscard,
                            titleVisibility: .visible) {
            Button(String(localized: "Abandonner", bundle: .module), role: .destructive) { dismiss() }
            Button(String(localized: "Continuer à modifier", bundle: .module), role: .cancel) {}
        }
        .task { await model.load() }
    }
}
