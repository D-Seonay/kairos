import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La carte « Séance du jour » : musculation (ajustée, planifiée ou rétablie), mobilité ou repos au choix, course, repos
/// ou aucun programme ; ou, une fois la séance lancée, son bilan ou « Reprendre la séance ».
struct SessionCard: View {
    let model: TodayModel
    /// Ouvre l'écran « Pourquoi ».
    let onWhy: () -> Void
    /// Lance la séance affichée.
    let onStart: () -> Void
    /// Rouvre la séance en cours.
    let onResume: () -> Void

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                switch model.card {
                case .strength(let card):
                    StrengthSessionCard(
                        card: card, onWhy: onWhy,
                        onOrigin: { choose(original: card.badge == .adjusted) },
                        onStart: onStart)
                case .mobilityOrRest(let dayName): mobilityOrRest(dayName)
                case .run(let card): run(card)
                case .rest(let next, let suggestsMobility): rest(next, suggestsMobility: suggestsMobility)
                case .noProgram: noProgram
                case .done(let card): DoneSessionCard(card: card)
                case .inProgress(let title): ResumeSessionCard(title: title, onResume: onResume)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func choose(original: Bool) {
        Task { await model.chooseOriginalSession(original) }
    }

    // MARK: - Mobilité ou repos

    /// Choisir le repos, c'est ne rien faire : aucun bouton, rien n'est enregistré.
    @ViewBuilder
    private func mobilityOrRest(_ dayName: String) -> some View {
        SessionCardHeader(title: dayName, badge: .adjusted)
        detail(String(localized: "Ton corps a besoin de récupérer : 20 min de mobilité ou repos complet, au choix.", bundle: .module))
        Button(String(localized: "20 min de mobilité", bundle: .module), action: model.startMobility)
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(TodayIdentifiers.sessionStart)
        Button(String(localized: "Séance d'origine", bundle: .module)) { choose(original: true) }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier(TodayIdentifiers.sessionOrigin)
    }

    // MARK: - Course

    @ViewBuilder
    private func run(_ card: RunCard) -> some View {
        SessionCardHeader(title: card.title, runIcon: true)
        if let target = card.target {
            detail(target)
        }
        if let suggestion = card.suggestion {
            Text(suggestion)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
        }
    }

    // MARK: - Repos

    @ViewBuilder
    private func rest(_ next: NextSession?, suggestsMobility: Bool) -> some View {
        SessionCardHeader(title: String(localized: "Repos", bundle: .module))
        detail(next.map(Self.nextSessionText) ?? String(localized: "Aucune autre séance prévue cette semaine.", bundle: .module))
        if suggestsMobility {
            detail(String(localized: "Score sous 65 : 20 min de mobilité t'aideront à récupérer.", bundle: .module))
            Button(String(localized: "20 min de mobilité", bundle: .module), action: model.startMobility)
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier(TodayIdentifiers.sessionStart)
        }
    }

    /// « Prochaine séance : Pull, mercredi ».
    static func nextSessionText(_ next: NextSession) -> String {
        String(localized: "Prochaine séance : \(next.day.name), \(next.weekday.todayName)", bundle: .module)
    }

    // MARK: - Sans programme

    @ViewBuilder
    private var noProgram: some View {
        SessionCardHeader(title: String(localized: "Aucune séance prévue.", bundle: .module))
        detail(String(localized: "L'éditeur de routines arrive avec la séance en direct.", bundle: .module))
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text2)
    }
}

extension Weekday {
    /// Le jour en toutes lettres et en minuscules, pour une phrase : « mercredi ».
    var todayName: String {
        switch self {
        case .monday: String(localized: "lundi", bundle: .module)
        case .tuesday: String(localized: "mardi", bundle: .module)
        case .wednesday: String(localized: "mercredi", bundle: .module)
        case .thursday: String(localized: "jeudi", bundle: .module)
        case .friday: String(localized: "vendredi", bundle: .module)
        case .saturday: String(localized: "samedi", bundle: .module)
        case .sunday: String(localized: "dimanche", bundle: .module)
        }
    }
}
