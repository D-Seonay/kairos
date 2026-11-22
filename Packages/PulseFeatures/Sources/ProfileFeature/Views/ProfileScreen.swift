import PulseDesignSystem
import PulseServices
import SupplementsFeature
import SwiftUI

/// Les écrans poussés depuis la page Profil.
enum ProfileDestination: Hashable {
    case weight
    case supplements
    case settings
    case myData
}

/// L'onglet Profil (spec M7 §13) : l'en-tête, les trois tuiles, le poids, le mur des records, la vitrine des badges, puis les
/// liens vers Statistiques, Compléments, Paramètres et Mes données.
public struct ProfileScreen: View {
    private let model: ProfileModel
    private let supplements: SupplementsModel
    /// Les écrans de l'app (diagnostic, debug, confirmation de suppression), pour Paramètres et Mes données.
    private let screens: ProfileAppScreens
    private let onOpenStats: () -> Void
    private let onOpenRecords: () -> Void
    /// Part une fois tout supprimé depuis Mes données.
    private let onErased: () async -> Void

    public init(model: ProfileModel, supplements: SupplementsModel, screens: ProfileAppScreens,
                onOpenStats: @escaping () -> Void, onOpenRecords: @escaping () -> Void, onErased: @escaping () async -> Void) {
        self.model = model
        self.supplements = supplements
        self.screens = screens
        self.onOpenStats = onOpenStats
        self.onOpenRecords = onOpenRecords
        self.onErased = onErased
    }

    public var body: some View {
        NavigationStack {
            content
                .pulseScreenBackground(aura: 0.5)
                .hidingNavigationBar()
                .navigationDestination(for: ProfileDestination.self) { destination($0) }
        }
        .task {
            if !model.hasLoaded { await model.load() }
        }
    }

    private var content: some View {
        let calendar = model.environment.calendar
        let today = model.environment.now()
        return ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                ProfileHeader(summary: model.summary, calendar: calendar)
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let summary = model.summary {
                    ProfileTiles(summary: summary, trend: model.body?.trend, calendar: calendar, today: today)
                    WeightCard(trend: model.body?.trend, calendar: calendar, today: today)
                    RecordsWall(lifts: summary.mainLifts, runs: summary.runs, calendar: calendar, today: today,
                                onOpenRecords: onOpenRecords)
                    BadgeShelfSection(shelf: summary.badges, calendar: calendar, today: today)
                } else if !model.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .accessibilityLabel(String(localized: "Chargement du profil", bundle: .module))
                }
                ProfileLinks(onOpenStats: onOpenStats)
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable { await model.load() }
        .pulseAnnounceOnce(model.errorMessage, id: model.failureCount, isError: true)
    }

    @ViewBuilder
    private func destination(_ destination: ProfileDestination) -> some View {
        switch destination {
        case .supplements:
            SupplementsView(model: supplements)
        case .weight:
            // Chaque pesée enregistrée ou supprimée relit la page : tuile et carte Poids suivent.
            WeightScreen(environment: model.environment) { [model] in await model.load() }
        case .settings:
            // Un réglage enregistré part vers l'app (thème, prénom) ; la page ne se relit que pour un prénom changé.
            SettingsScreen(environment: model.environment, screens: screens) { [model] profile in
                Task { await model.settingsSaved(profile) }
            }
        case .myData:
            MyDataScreen(environment: model.environment, screens: screens, onErased: onErased)
        }
    }
}

/// L'en-tête : l'initiale dans une pastille, le prénom (ou « Ton profil ») et les séances depuis la première.
private struct ProfileHeader: View {
    let summary: ProfileSummary?
    let calendar: Calendar
    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat = 56
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// La pastille à côté du prénom ; aux tailles d'accessibilité, au-dessus, et le prénom passe à la ligne sans rétrécir.
    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Profil", bundle: .module))
                .pulseEyebrow(PulsePalette.text2)
            layout {
                initial
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(PulseFont.title(.largeTitle, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(PulsePalette.text)
                        .lineLimit(isLarge ? nil : 1)
                        .minimumScaleFactor(isLarge ? 1 : 0.6)
                    if let summary {
                        Text(ProfileText.sessionsSince(summary.sessionsTotal, firstSession: summary.firstSession,
                                                       calendar: calendar))
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isHeader)
    }

    private var spoken: String {
        let sessions = summary.map {
            ProfileText.sessionsSinceSpoken($0.sessionsTotal, firstSession: $0.firstSession, calendar: calendar)
        }
        return ProfileText.headerSpoken(name: name, sessions: sessions)
    }

    private var firstName: String? {
        summary?.firstName.flatMap { $0.isEmpty ? nil : $0 }
    }

    private var name: String {
        firstName ?? String(localized: "Ton profil", bundle: .module)
    }

    /// L'initiale en creux dans une pastille d'encre ; une silhouette sans prénom.
    private var initial: some View {
        Group {
            if let letter = firstName?.first {
                Text(String(letter).uppercased())
                    .font(PulseFont.title(.title, weight: .semibold))
            } else {
                Image(systemName: "person.fill")
                    .font(.title2.weight(.semibold))
            }
        }
        .foregroundStyle(PulsePalette.page)
        .frame(width: min(badgeSize, 80), height: min(badgeSize, 80))
        .background(Circle().fill(PulsePalette.ink))
        .accessibilityHidden(true)
    }
}

extension View {
    /// L'onglet a son propre en-tête : la barre de navigation n'apparaît que sur les écrans poussés. Sans effet sur Mac.
    func hidingNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
