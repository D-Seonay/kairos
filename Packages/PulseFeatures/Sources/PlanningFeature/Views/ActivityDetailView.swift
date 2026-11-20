import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le détail d'une course ou d'un vélo lu d'Apple Santé (spec M6 §7) : mesures, RPE et note modifiables.
struct ActivityDetailView: View {
    @State private var model: ActivityDetailModel
    private static let rpeValues: [Double] = stride(from: 1.0, through: 10.0, by: 0.5).map { $0 }

    init(model: ActivityDetailModel) {
        _model = State(initialValue: model)
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
                    }
                }
                .listRowBackground(PulsePalette.surface)
                Section {
                    Picker(String(localized: "RPE ressenti", bundle: .module), selection: $model.rpe) {
                        Text(String(localized: "—", bundle: .module)).tag(Double?.none)
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
                Section {
                    EmptyView()
                } footer: {
                    Text(String(localized: "Cet entraînement vient d'Apple Santé. Pour le supprimer, supprime-le dans l'app Santé.",
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
        .toolbar {
            if model.hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Enregistrer", bundle: .module)) { Task { await model.save() } }
                }
            }
        }
        .task { await model.load() }
    }
}
