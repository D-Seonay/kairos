import PulseDesignSystem
import PulseServices
import SwiftUI

/// Ce que contient le fichier : séances nouvelles, période, exercices, cardio détecté, séances déjà présentes, et ce qui n'est
/// pas importé.
struct HevySummaryView: View {
    let model: HevyImportModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                Text(String(localized: "Voilà ce que contient ton export", bundle: .module))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityAddTraits(.isHeader)
                if let preview = model.preview {
                    ObsidianCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SummaryLine(title: String(localized: "Séances à importer", bundle: .module),
                                        value: String(preview.newWorkouts.count))
                            if let period = model.periodText {
                                SummaryLine(title: String(localized: "Période", bundle: .module), value: period)
                            }
                            SummaryLine(title: String(localized: "Exercices", bundle: .module), value: String(preview.names.count))
                            SummaryLine(title: String(localized: "Lignes de cardio détectées", bundle: .module),
                                        value: String(preview.cardioSetCount))
                            SummaryLine(title: String(localized: "Séances déjà présentes", bundle: .module),
                                        value: String(preview.duplicateCount))
                        }
                    }
                    ForEach(model.summaryNotes, id: \.self) { note in
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text2)
                    }
                }
                Button(String(localized: "Vérifier les correspondances", bundle: .module)) { model.showMapping() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!model.canImport)
                    .accessibilityIdentifier(TrainIdentifiers.hevyImportReview)
                Button(String(localized: "Choisir un autre fichier", bundle: .module)) { model.restart() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(PulseMetrics.spacing)
        }
    }
}

/// Un intitulé et sa valeur, lus ensemble.
private struct SummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
            Spacer(minLength: 8)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(PulsePalette.text)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
