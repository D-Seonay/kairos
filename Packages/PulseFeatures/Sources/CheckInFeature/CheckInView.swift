import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Ce que la bannière du check-in propose quand l'accès à Apple Santé n'a jamais été demandé sur cet appareil.
public struct CheckInHealthOffer {
    /// « Connecter Apple Santé » ; `nil` : la bannière le dit sans offrir l'action (l'onboarding, dont l'étape Apple Santé
    /// vient d'être passée).
    public var connect: (() -> Void)?
    /// Vrai pendant la demande : le bouton reste inactif.
    public var isConnecting: Bool
    /// L'échec de la demande, affiché au-dessus du bouton.
    public var errorMessage: String?

    public init(connect: (() -> Void)? = nil, isConnecting: Bool = false, errorMessage: String? = nil) {
        self.connect = connect
        self.isConnecting = isConnecting
        self.errorMessage = errorMessage
    }
}

/// Le check-in sans montre : trois questions, l'estimation en direct, puis la validation.
@MainActor
public struct CheckInView: View {
    private let form: CheckInForm
    private let scrollable: Bool
    private let errorMessage: String?
    private let isSubmitting: Bool
    private let healthOffer: CheckInHealthOffer?
    private let onSubmit: (CheckInAnswers) -> Void
    /// La taille de l'estimation suit Dynamic Type : un grand chiffre reste lisible au réglage du texte choisi.
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 64

    /// `scrollable: false` : le check-in s'intègre à une page qui défile déjà (l'accueil), sans défilement, marge ni fond propres.
    /// `errorMessage` : l'échec de l'enregistrement, affiché juste au-dessus du bouton. `isSubmitting` : le bouton reste inactif
    /// pendant l'enregistrement. `healthOffer` : l'accès à Apple Santé n'a jamais été demandé, la bannière le dit (et offre de
    /// le connecter) au lieu de parler de montre ; `nil` : la bannière « Pas de données de nuit ».
    public init(form: CheckInForm, scrollable: Bool = true, errorMessage: String? = nil, isSubmitting: Bool = false,
                healthOffer: CheckInHealthOffer? = nil, onSubmit: @escaping (CheckInAnswers) -> Void) {
        self.form = form
        self.scrollable = scrollable
        self.errorMessage = errorMessage
        self.isSubmitting = isSubmitting
        self.healthOffer = healthOffer
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
            if let errorMessage {
                // Sous les yeux, juste au-dessus du bouton qui vient d'échouer.
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.bad)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
        let text = CheckInText.banner(healthRequested: healthOffer == nil)
        return ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: healthOffer == nil ? "applewatch.slash" : "heart.text.square")
                        .font(.title2)
                        .foregroundStyle(PulsePalette.warn)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text.title)
                            .font(.subheadline.weight(.bold))
                        Text(text.message)
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.text2)
                    }
                }
                if let healthOffer, let connect = healthOffer.connect {
                    connectButton(healthOffer, action: connect)
                }
            }
        }
    }

    /// « Connecter Apple Santé » : secondaire, le check-in garde son bouton principal. L'échec de la demande s'affiche juste
    /// au-dessus.
    @ViewBuilder
    private func connectButton(_ offer: CheckInHealthOffer, action: @escaping () -> Void) -> some View {
        if let message = offer.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(PulsePalette.bad)
                .fixedSize(horizontal: false, vertical: true)
        }
        Button(String(localized: "Connecter Apple Santé", bundle: .module), action: action)
            .buttonStyle(SecondaryButtonStyle())
            .disabled(offer.isConnecting)
            .accessibilityHint(String(localized: "Ouvre la demande d'accès d'Apple Santé", bundle: .module))
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
        .disabled(form.answers == nil || isSubmitting)
    }

    private var category: RecoveryCategory? {
        form.estimatedScore.map { RecoveryCategory(score: $0) }
    }

    private var scoreText: String {
        form.estimatedScore.map { String(Int($0.rounded())) } ?? PulseFormat.dash
    }
}

#Preview("Vide") {
    CheckInView(form: CheckInForm(), onSubmit: { _ in })
}

#Preview("Apple Santé jamais demandé") {
    CheckInView(form: CheckInForm(), healthOffer: CheckInHealthOffer(connect: {}), onSubmit: { _ in })
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

#Preview("Rempli, échec de l'enregistrement") {
    let form = CheckInForm()
    form.selection = [.sleep: 3, .pain: 3, .motivation: 3]
    return CheckInView(form: form, errorMessage: "Pulse n'a pas pu enregistrer ton check-in.", onSubmit: { _ in })
}
