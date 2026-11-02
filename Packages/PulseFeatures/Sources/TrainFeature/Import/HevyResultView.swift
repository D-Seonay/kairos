import PulseDesignSystem
import PulseServices
import SwiftUI

/// Le bilan de l'import : séances importées, exercices créés, records, séances non importées, et le lien vers l'historique.
struct HevyResultView: View {
    let result: HevyImportResult
    let onShowHistory: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(PulsePalette.ok)
                    .accessibilityHidden(true)
                Text(String(localized: "Import terminé", bundle: .module))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityAddTraits(.isHeader)
                ObsidianCard {
                    VStack(alignment: .leading, spacing: 12) {
                        line(String(localized: "Séances importées", bundle: .module), result.importedSessions)
                        line(String(localized: "Exercices créés", bundle: .module), result.createdExercises)
                        line(String(localized: "Records établis", bundle: .module), result.records)
                    }
                }
                ForEach(HevyImportModel.resultNotes(for: result), id: \.self) { note in
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
                Button(String(localized: "Voir l'historique", bundle: .module), action: onShowHistory)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier(TrainIdentifiers.hevyImportHistory)
                Button(String(localized: "Terminer", bundle: .module), action: onFinish)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(PulseMetrics.spacing)
        }
    }

    private func line(_ title: String, _ value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
            Spacer(minLength: 8)
            Text(String(value))
                .font(.headline.monospacedDigit())
                .foregroundStyle(PulsePalette.text)
        }
        .accessibilityElement(children: .combine)
    }
}
