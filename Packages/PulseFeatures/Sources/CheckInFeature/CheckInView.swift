import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le check-in sans montre : trois questions, l'estimation en direct, puis la validation.
@MainActor
public struct CheckInView: View {
    private let form: CheckInForm
    private let scrollable: Bool
    private let onSubmit: (CheckInAnswers) -> Void
    /// La taille de l'estimation suit Dynamic Type : un grand chiffre reste lisible au réglage du texte choisi.
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 64

    /// `scrollable: false` : le check-in s'intègre à une page qui défile déjà (l'accueil), sans défilement, marge ni fond propres.
    public init(form: CheckInForm, scrollable: Bool = true, onSubmit: @escaping (CheckInAnswers) -> Void) {
        self.form = form
        self.scrollable = scrollable
        self.onSubmit = onSubmit
    }

    @ViewBuilder
    public var body: some View {
        if scrollable {
            ScrollView {
                content.padding(PulseMetrics.spacing)
            }
            .background(PulsePalette.background)
        } else {
            content
        }
    }

    private var content: some View {
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
        // L'estimation change sous le focus à chaque réponse : on la dit dès qu'elle est disponible, puis quand elle change.
        .pulseAnnounce(CheckInText.announcement(score: form.estimatedScore, category: category))
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
                selection: binding(for: question),
                groupLabel: question.title
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
                    .font(PulseFont.score(size: scoreSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .pulseNumericTransition(value: form.estimatedScore ?? 0)
                categoryLine
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CheckInText.estimation(score: form.estimatedScore, category: category))
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
}

#Preview("Vide") {
    CheckInView(form: CheckInForm(), onSubmit: { _ in })
}

#Preview("Vide, accessibilité 3") {
    CheckInView(form: CheckInForm(), onSubmit: { _ in })
        .dynamicTypeSize(.accessibility3)
}

#Preview("Rempli, accessibilité 3") {
    let form = CheckInForm()
    form.selection = [.sleep: 3, .pain: 3, .motivation: 3]
    return CheckInView(form: form, onSubmit: { _ in })
        .dynamicTypeSize(.accessibility3)
}

#Preview("Rempli") {
    let form = CheckInForm()
    form.selection = [.sleep: 3, .pain: 3, .motivation: 3]
    return CheckInView(form: form, onSubmit: { _ in })
}
