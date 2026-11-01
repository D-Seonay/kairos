import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le check-in sans montre : trois questions, l'estimation en direct, puis la validation.
@MainActor
public struct CheckInView: View {
    private let form: CheckInForm
    private let onSubmit: (CheckInAnswers) -> Void

    public init(form: CheckInForm, onSubmit: @escaping (CheckInAnswers) -> Void) {
        self.form = form
        self.onSubmit = onSubmit
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                banner
                ForEach(CheckInQuestion.allCases, id: \.self) { question in
                    questionBlock(question)
                }
                estimationCard
                submitButton
                Text(String(localized: "Un score estimé n'autorise jamais de surcharge progressive.", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(PulseMetrics.spacing)
        }
        .background(PulsePalette.background)
    }

    private var banner: some View {
        ObsidianCard {
            HStack(spacing: 12) {
                Image(systemName: "applewatch.slash")
                    .font(.title2)
                    .foregroundStyle(PulsePalette.warn)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Pas de données de nuit", bundle: .module))
                        .font(.subheadline.weight(.bold))
                    Text(String(
                        localized: "Montre déchargée ou non portée ? Trois questions suffisent pour estimer ta récupération.",
                        bundle: .module
                    ))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                }
            }
        }
    }

    private func questionBlock(_ question: CheckInQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            ChoicePills(
                options: question.options.map { (value: $0.value, label: $0.label) },
                selection: binding(for: question)
            )
        }
    }

    private func binding(for question: CheckInQuestion) -> Binding<Int?> {
        Binding(
            get: { form.selection[question] },
            set: { form.selection[question] = $0 }
        )
    }

    private var estimationCard: some View {
        OpalCard {
            VStack(spacing: 4) {
                Text(String(localized: "Estimation", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.opalMuted)
                Text(scoreText)
                    .font(.system(size: 48, weight: .heavy).monospacedDigit())
                    .contentTransition(.numericText())
                categoryLine
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(estimationAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var categoryLine: some View {
        if let category {
            CategoryBadge(category: category, onOpal: true)
        } else {
            Text(String(localized: "Réponds aux trois questions", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.opalMuted)
        }
    }

    private var submitButton: some View {
        Button(String(localized: "Utiliser ce score aujourd'hui", bundle: .module)) {
            if let answers = form.answers { onSubmit(answers) }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(form.answers == nil)
    }

    private var category: RecoveryCategory? {
        form.estimatedScore.map { RecoveryCategory(score: $0) }
    }

    private var scoreText: String {
        form.estimatedScore.map { String(Int($0.rounded())) } ?? "–"
    }

    private var estimationAccessibilityLabel: String {
        let title = String(localized: "Estimation", bundle: .module)
        guard let score = form.estimatedScore, let category else {
            return "\(title), \(String(localized: "Réponds aux trois questions", bundle: .module))"
        }
        return "\(title), \(Int(score.rounded())), \(category.localizedName)"
    }
}

#Preview("Vide") {
    CheckInView(form: CheckInForm(), onSubmit: { _ in })
}

#Preview("Rempli") {
    let form = CheckInForm()
    form.selection = [.sleep: 3, .pain: 3, .motivation: 3]
    return CheckInView(form: form, onSubmit: { _ in })
}
