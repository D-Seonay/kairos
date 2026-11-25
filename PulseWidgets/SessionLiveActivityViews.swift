import AppIntents
import PulseDesignSystem
import PulseLiveActivity
import SwiftUI
import WidgetFeature

/// Les couleurs de la Live Activity. Les widgets suivent l'ambiance du profil (`WidgetThemeStore`), pas la Live Activity : elle
/// prend l'accent par défaut (Ivoire), dont le tirage sombre se distingue à peine de celui d'Acier.
/// La séance est toujours sombre (fond noir) : l'accent et son encre sont fixés à leurs tirages sombres. Avec le tirage dynamique,
/// l'apparence claire du système rendrait l'accent en encre noire sur le noir de l'activité (1,1:1).
enum SessionActivityStyle {
    static let accent = Color(PulsePalette.accent(for: .amber).accent.dark)
    static let accentInk = Color(PulsePalette.accent(for: .amber).accentInk.dark)
}

extension View {
    /// La Live Activity pose un fond noir quelle que soit l'apparence du système : ses vues se composent toujours en sombre.
    func sessionActivityDark() -> some View {
        environment(\.colorScheme, .dark)
    }
}

/// L'état affiché de l'activité. Une activité périmée (`staleDate` = fin du repos) compte comme hors repos : l'écran verrouillé et
/// la Dynamic Island n'attendent pas une mise à jour de l'app pour cacher le repos fini et ses boutons.
struct SessionActivityModel {
    let content: PulseSessionAttributes.ContentState
    let isStale: Bool

    var title: String { content.title }
    var startedAt: Date { content.startedAt }
    var nextSet: String? { content.nextSet }
    var plannedSets: Int { max(content.plannedSets ?? 0, 0) }
    var doneSets: Int { min(max(content.doneSets ?? 0, 0), plannedSets) }

    /// Une séance sans série prévue (séance libre vide) n'affiche pas de progression.
    var showsProgress: Bool { plannedSets > 0 }

    /// L'intervalle du repos en cours ; `nil` hors repos. Les comptes à rebours partent des dates, jamais d'un compteur.
    var restInterval: ClosedRange<Date>? {
        guard !isStale, let restEndsAt = content.restEndsAt else { return nil }
        return min(content.restStartedAt ?? restEndsAt, restEndsAt)...restEndsAt
    }

    /// Ce que VoiceOver lit pour le titre, la progression et la série suivante ; le minuteur système lit lui-même le temps.
    var spokenLabel: String {
        SessionActivityText.accessibilityLabel(title: title, isResting: restInterval != nil, nextSet: nextSet,
                                               doneSets: doneSets, plannedSets: plannedSets)
    }
}

/// L'anneau du repos : un minuteur système qui se vide jusqu'à `restEndsAt`.
struct SessionRestRing: View {
    let interval: ClosedRange<Date>

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(SessionActivityStyle.accent)
        .accessibilityHidden(true)
    }
}

/// L'anneau des séries de travail validées, comme la barre en haut de l'écran de séance. Un haltère au centre quand il y a la place.
struct SessionSetsRing: View {
    let state: SessionActivityModel
    var showsIcon = true

    var body: some View {
        ProgressView(value: Double(state.doneSets), total: Double(max(state.plannedSets, 1))) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(SessionActivityStyle.accent)
        .overlay {
            if showsIcon {
                Image(systemName: "dumbbell.fill")
                    .font(.caption2)
                    .imageScale(.small)
                    .foregroundStyle(SessionActivityStyle.accent)
            }
        }
        .accessibilityHidden(true)
    }
}

/// La barre des séries de travail validées, sous l'en-tête de l'écran verrouillé.
struct SessionProgressBar: View {
    let state: SessionActivityModel

    var body: some View {
        ProgressView(value: Double(state.doneSets), total: Double(max(state.plannedSets, 1)))
            .progressViewStyle(.linear)
            .tint(SessionActivityStyle.accent)
            .accessibilityHidden(true)
    }
}

/// À gauche de l'en-tête : l'anneau du repos pendant un repos, sinon l'anneau des séries, ou l'haltère sans série prévue.
struct SessionLeadingGlyph: View {
    let state: SessionActivityModel
    let iconFont: Font

    var body: some View {
        if let interval = state.restInterval {
            SessionRestRing(interval: interval)
        } else if state.showsProgress {
            SessionSetsRing(state: state)
        } else {
            Image(systemName: "dumbbell.fill")
                .font(iconFont)
                .foregroundStyle(SessionActivityStyle.accent)
                .accessibilityHidden(true)
        }
    }
}

/// Le temps restant du repos, ou la durée écoulée depuis le début de la séance, en minuteur système.
struct SessionClockText: View {
    let state: SessionActivityModel

    var body: some View {
        Group {
            if let interval = state.restInterval {
                Text(timerInterval: interval, pauseTime: nil, countsDown: true, showsHours: false)
            } else {
                Text(timerInterval: state.startedAt...Date.distantFuture, pauseTime: nil, countsDown: false, showsHours: true)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }
}

/// Un bouton du repos : −30 s, +30 s ou Passer.
struct SessionRestButton<Intent: AppIntent>: View {
    let intent: Intent
    let title: String
    let label: String
    var isPrimary = false
    var height: CGFloat = 44

    var body: some View {
        Button(intent: intent) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(isPrimary ? SessionActivityStyle.accentInk : .white)
                .background(isPrimary ? SessionActivityStyle.accent : .white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Les trois boutons du repos. Plus bas dans la Dynamic Island, qui plafonne à 160 pt de haut.
struct SessionRestButtons: View {
    var height: CGFloat = 44

    var body: some View {
        HStack(spacing: 8) {
            SessionRestButton(intent: RestMinus30Intent(), title: SessionActivityText.minus30Title,
                              label: SessionActivityText.minus30Label, height: height)
            SessionRestButton(intent: RestPlus30Intent(), title: SessionActivityText.plus30Title,
                              label: SessionActivityText.plus30Label, height: height)
            SessionRestButton(intent: SkipRestIntent(), title: SessionActivityText.skipTitle,
                              label: SessionActivityText.skipLabel, isPrimary: true, height: height)
        }
    }
}

/// La série suivante (« Développé couché à la barre · série 3 · 12 kg × 6 »), sans intitulé : elle se lit d'elle-même, et
/// VoiceOver la dit avec le titre.
struct SessionNextSetText: View {
    let nextSet: String
    let lineLimit: Int

    var body: some View {
        Text(nextSet)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.85)
            .accessibilityHidden(true)
    }
}

/// Le titre (« Repos » pendant un repos, celui de la séance sinon), suivi de « 2 / 18 » sur la même ligne.
struct SessionTitleLine: View {
    let state: SessionActivityModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(state.restInterval == nil ? state.title : SessionActivityText.restTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            if state.showsProgress {
                Text(SessionActivityText.progressText(done: state.doneSets, planned: state.plannedSets))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText(value: Double(state.doneSets)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.spokenLabel)
    }
}

/// L'écran verrouillé, sur 160 pt au plus, rangé comme la Dynamic Island étendue : anneau, titre et « 2 / 18 », temps restant ;
/// la série suivante sur toute la largeur ; puis les boutons pendant un repos, ou la barre des séries hors repos. Hors repos, la
/// série suivante partage sa ligne avec « Valider » (44 pt) : 16 + 44 + 8 + 44 + 8 + 4 + 16, la hauteur du repos tient encore.
struct SessionLockScreenView: View {
    let state: SessionActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let setID = state.validateSetID {
                SessionValidateRow(setID: setID, nextSet: state.nextSet, lineLimit: 2, height: 44)
            } else if let nextSet = state.nextSet {
                SessionNextSetText(nextSet: nextSet, lineLimit: 1)
            }
            if state.restInterval != nil {
                SessionRestButtons()
            } else if state.showsProgress {
                SessionProgressBar(state: state)
            }
        }
        .padding(16)
        // L'écran verrouillé de la Live Activity plafonne à 160 pt de haut : au-delà, les boutons du repos seraient rognés.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .sessionActivityDark()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            SessionLeadingGlyph(state: state, iconFont: .title2)
                .frame(width: 44, height: 44)
            SessionTitleLine(state: state)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Un minuteur système ne rétrécit pas : il se coupe (« 1:… »). Sa taille est plafonnée pour que « 1:15:12 » tienne
            // dans les 124 pt réservés, calé à droite.
            SessionClockText(state: state)
                .font(PulseFont.value(.title))
                .foregroundStyle(SessionActivityStyle.accent)
                .multilineTextAlignment(.trailing)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .frame(width: 124, alignment: .trailing)
        }
    }
}

/// À gauche de la Dynamic Island étendue : l'anneau du repos, l'anneau des séries hors repos, ou l'haltère sans série prévue.
struct SessionIslandLeading: View {
    let state: SessionActivityModel

    var body: some View {
        SessionLeadingGlyph(state: state, iconFont: .title3)
            .frame(width: 36, height: 36)
            .padding(.leading, 4)
            .sessionActivityDark()
    }
}

/// À droite de la Dynamic Island étendue : le temps restant, ou la durée écoulée. Un minuteur système ne rétrécit pas, il se
/// coupe (« 1:… ») : la région a la priorité sur le titre, une largeur fixe et une taille plafonnée où « 1:15:12 » tient.
struct SessionIslandTrailing: View {
    let state: SessionActivityModel

    var body: some View {
        SessionClockText(state: state)
            .font(PulseFont.value(.title2))
            .foregroundStyle(SessionActivityStyle.accent)
            .multilineTextAlignment(.trailing)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .frame(width: 100, alignment: .trailing)
            .padding(.trailing, 4)
            .sessionActivityDark()
    }
}

/// Au centre de la Dynamic Island étendue, entre l'anneau et le temps : le titre et « 2 / 18 ».
struct SessionIslandCenter: View {
    let state: SessionActivityModel

    var body: some View {
        SessionTitleLine(state: state)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .sessionActivityDark()
    }
}

/// Sous la Dynamic Island étendue, qui plafonne à 160 pt de haut : la série suivante sur une ligne, puis les boutons du repos ;
/// hors repos, la série suivante et « Valider » (36 pt, comme les boutons du repos) sur une seule ligne.
struct SessionIslandBottom: View {
    let state: SessionActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let setID = state.validateSetID {
                SessionValidateRow(setID: setID, nextSet: state.nextSet, lineLimit: 1, height: 36)
            } else if let nextSet = state.nextSet {
                SessionNextSetText(nextSet: nextSet, lineLimit: 1)
            }
            if state.restInterval != nil {
                SessionRestButtons(height: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .sessionActivityDark()
    }
}

/// À gauche de la Dynamic Island compacte : l'anneau des séries et « 4/15 », ou l'haltère sans série prévue.
struct SessionCompactLeading: View {
    let state: SessionActivityModel

    var body: some View {
        Group {
            if state.showsProgress {
                HStack(spacing: 4) {
                    SessionSetsRing(state: state, showsIcon: false)
                        .frame(width: 16, height: 16)
                    Text("\(state.doneSets)/\(state.plannedSets)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(SessionActivityStyle.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText(value: Double(state.doneSets)))
                }
                .frame(maxWidth: 56, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(SessionActivityText.progressSpoken(done: state.doneSets, planned: state.plannedSets))
            } else {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(SessionActivityStyle.accent)
                    .accessibilityHidden(true)
            }
        }
        .sessionActivityDark()
    }
}

/// À droite de la Dynamic Island compacte : le temps restant du repos, ou la durée écoulée.
struct SessionCompactTime: View {
    let state: SessionActivityModel

    var body: some View {
        SessionClockText(state: state)
            .font(.caption.weight(.bold))
            .foregroundStyle(SessionActivityStyle.accent)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 52, alignment: .trailing)
            .sessionActivityDark()
    }
}

/// La Dynamic Island minimale : l'anneau du repos, l'anneau des séries hors repos, ou l'icône sans série prévue.
struct SessionMinimalView: View {
    let state: SessionActivityModel

    var body: some View {
        if let interval = state.restInterval {
            SessionRestRing(interval: interval)
                .padding(2)
                .accessibilityLabel(state.spokenLabel)
                .sessionActivityDark()
        } else if state.showsProgress {
            SessionSetsRing(state: state)
                .padding(2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.spokenLabel)
                .sessionActivityDark()
        } else {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(SessionActivityStyle.accent)
                .accessibilityLabel(state.spokenLabel)
                .sessionActivityDark()
        }
    }
}
