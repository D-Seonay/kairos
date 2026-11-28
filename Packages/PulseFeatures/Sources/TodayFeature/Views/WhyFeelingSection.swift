import CheckInFeature
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// « Ton ressenti ce matin » : les trois questions du check-in, prises en compte à côté du score mesuré comme léger modificateur.
/// Proposé jusqu'au figement de midi.
struct WhyFeelingSection: View {
    let model: TodayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(String(localized: "Ton ressenti ce matin", bundle: .module))
            ObsidianCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: """
                        Il ajoute ou retire au plus 5 points au score mesuré, et ne fait jamais monter la catégorie.
                        """, bundle: .module))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(CheckInQuestion.allCases, id: \.self) { question in
                        questionBlock(question)
                    }
                    if let error = model.feelingError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.bad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(buttonTitle) {
                        Task { await model.submitFeeling() }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(model.feeling.answers == nil || model.isSubmittingFeeling)
                }
            }
        }
    }

    private var buttonTitle: String {
        model.why?.feeling == nil
            ? String(localized: "Prendre en compte mon ressenti", bundle: .module)
            : String(localized: "Mettre à jour mon ressenti", bundle: .module)
    }

    private func questionBlock(_ question: CheckInQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            ChoicePills(
                options: question.options.map { (value: $0.value, label: $0.label) },
                selection: Binding(get: { model.feeling.selection[question] }, set: { model.feeling.selection[question] = $0 }),
                groupLabel: question.title
            )
        }
    }
}
