import CheckInFeature
import PulseDesignSystem
import PulseServices
import SupplementsFeature
import SwiftUI

/// L'onglet « Aujourd'hui » : en-tête, carte de récupération (ou check-in), séance du jour, charge d'entraînement et tendances,
/// avec sa feuille de mobilité et l'écran « Pourquoi », poussé dans sa pile de navigation. Un jour de musculation, « Démarrer »
/// est ancré en bas de l'écran : l'action du jour reste sous le pouce, quelle que soit la position du défilement.
/// « Démarrer » rend la séance à lancer à l'app, qui ouvre l'écran en direct ; « Reprendre la séance » lui demande de rouvrir
/// celle en cours. La carte Compléments, sous la séance, ouvre l'écran Compléments dans la même pile.
public struct TodayView: View {
    private let model: TodayModel
    private let supplements: SupplementsModel?
    private let onOpenProfile: () -> Void
    private let onStartSession: (SessionLaunch) -> Void
    private let onResumeSession: () -> Void
    /// L'écran Compléments poussé ; l'app le tient pour qu'un rappel touché l'ouvre. Sans lui, l'accueil garde le sien.
    private let showsSupplements: Binding<Bool>?
    @State private var localShowsSupplements = false

    public init(model: TodayModel, supplements: SupplementsModel? = nil, showsSupplements: Binding<Bool>? = nil,
                onOpenProfile: @escaping () -> Void, onStartSession: @escaping (SessionLaunch) -> Void,
                onResumeSession: @escaping () -> Void) {
        self.model = model
        self.supplements = supplements
        self.showsSupplements = showsSupplements
        self.onOpenProfile = onOpenProfile
        self.onStartSession = onStartSession
        self.onResumeSession = onResumeSession
    }

    public var body: some View {
        @Bindable var model = model
        NavigationStack {
            content
                .pulseScreenBackground()
                .pulseDockedAction(isPresented: startTitle != nil) {
                    Button(action: startSession) {
                        Label(startTitle ?? "", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier(TodayIdentifiers.sessionStart)
                }
                .animation(.snappy, value: startTitle)
                .hidingNavigationBar()
                .navigationDestination(isPresented: $model.isShowingWhy) {
                    WhyView(model: model, onStart: startSession, onResume: onResumeSession)
                }
                .navigationDestination(isPresented: isShowingSupplements) {
                    if let supplements { SupplementsView(model: supplements) }
                }
        }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .mobility: MobilitySheet()
            }
        }
        // Le retour au premier plan est rafraîchi par la racine de l'app, quel que soit l'onglet affiché.
        .task {
            await model.refresh()
            await supplements?.load()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: PulseMetrics.spacing) {
                TodayHeader(model: model, onOpenProfile: onOpenProfile)
                recoveryOrCheckIn
                SessionCard(model: model, onWhy: model.showWhy, onResume: onResumeSession)
                if let offer = model.deloadOffer {
                    DeloadOfferCard(offer: offer) { accepted in Task { await model.decideDeload(accepted) } }
                }
                if let supplements {
                    SupplementsCard(model: supplements) { isShowingSupplements.wrappedValue = true }
                }
                PulseSectionHeader(String(localized: "Tendances", bundle: .module))
                LoadCard(content: model.load)
                TrendTilesView(tiles: model.trends)
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable {
            await model.refresh()
            await supplements?.load()
        }
    }

    private var isShowingSupplements: Binding<Bool> {
        showsSupplements ?? $localShowsSupplements
    }

    /// Le libellé du bouton ancré, `nil` quand la séance du jour n'est pas une musculation à lancer.
    private var startTitle: String? {
        guard case .strength(let card) = model.card else { return nil }
        return card.startButton
    }

    private func startSession() {
        if let launch = model.shownSessionLaunch() {
            onStartSession(launch)
        }
    }

    /// Les données ne suffisent pas : le check-in prend la place de la carte de récupération, la séance reste dessous.
    @ViewBuilder
    private var recoveryOrCheckIn: some View {
        if case .needsCheckIn = model.score {
            VStack(spacing: 12) {
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                CheckInView(form: model.checkIn, scrollable: false) { _ in
                    Task { await model.submitCheckIn() }
                }
            }
        } else {
            RecoveryCard(score: model.score, factors: model.factors, marker: model.marker, onWhy: model.showWhy)
        }
    }
}

/// « Bonjour Mathéo », la date, la pastille « Synchro 08:00 » qui relance la lecture et le bouton du profil.
private struct TodayHeader: View {
    let model: TodayModel
    let onOpenProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.dateText)
                        .pulseEyebrow(PulsePalette.text2)
                    Text(model.greeting)
                        .font(PulseFont.title(.largeTitle, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 8)
                profileButton
            }
            syncPill
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profileButton: some View {
        Button(action: onOpenProfile) {
            IconChip(systemName: "person", size: 44)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(String(localized: "Profil", bundle: .module))
    }

    private var syncPill: some View {
        Button {
            Task { await model.refresh() }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.lastSyncText == nil ? PulsePalette.muted : PulsePalette.text)
                    .frame(width: 6, height: 6)
                Text(syncText)
                    .pulseEyebrow(PulsePalette.text2)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(PulsePalette.surface.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(PulsePalette.ink.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(model.isLoading)
        .accessibilityHint(String(localized: "Relit tes données Apple Santé", bundle: .module))
    }

    private var syncText: String {
        guard let time = model.lastSyncText else { return String(localized: "Pas encore synchronisé", bundle: .module) }
        return String(localized: "Synchro \(time)", bundle: .module)
    }
}

private extension View {
    /// L'accueil a son propre en-tête : la barre de navigation n'apparaît que sur l'écran poussé. Sans effet sur Mac.
    func hidingNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
