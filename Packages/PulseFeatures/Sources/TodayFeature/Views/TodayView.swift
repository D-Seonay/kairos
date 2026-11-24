import CheckInFeature
import NightFeature
import PulseDesignSystem
import PulseDomain
import PulseServices
import SupplementsFeature
import SwiftUI

/// L'onglet « Aujourd'hui » : en-tête, carte de récupération (ou check-in), séance du jour, charge d'entraînement et tendances,
/// avec sa feuille de mobilité et l'écran « Pourquoi », poussé dans sa pile de navigation. Un jour de musculation, « Démarrer »
/// est ancré en bas de l'écran : l'action du jour reste sous le pouce, quelle que soit la position du défilement.
/// « Démarrer » rend la séance à lancer à l'app, qui ouvre l'écran en direct ; « Reprendre la séance » lui demande de rouvrir
/// celle en cours ; « Démarrer la course », sur la carte d'une course, rend la course à lancer. La carte Compléments, sous la séance,
/// ouvre l'écran Compléments dans la même pile.
public struct TodayView: View {
    private let model: TodayModel
    private let supplements: SupplementsModel?
    private let onOpenProfile: () -> Void
    private let onStartSession: (SessionLaunch) -> Void
    private let onResumeSession: () -> Void
    private let onStartRun: (RunLaunch) -> Void
    /// Sans programme, « Créer une routine » : l'app ouvre l'onglet Séance.
    private let onCreateRoutine: () -> Void
    /// L'écran Compléments poussé ; l'app le tient pour qu'un rappel touché l'ouvre. Sans lui, l'accueil garde le sien.
    private let showsSupplements: Binding<Bool>?
    @State private var localShowsSupplements = false
    /// Le modèle de l'écran Nuit, créé au toucher de la tuile Sommeil : il garde la nuit affichée tant que l'écran reste poussé.
    @State private var nightModel: NightModel?

    public init(model: TodayModel, supplements: SupplementsModel? = nil, showsSupplements: Binding<Bool>? = nil,
                onOpenProfile: @escaping () -> Void, onStartSession: @escaping (SessionLaunch) -> Void,
                onResumeSession: @escaping () -> Void, onStartRun: @escaping (RunLaunch) -> Void = { _ in },
                onCreateRoutine: @escaping () -> Void = {}) {
        self.model = model
        self.supplements = supplements
        self.showsSupplements = showsSupplements
        self.onOpenProfile = onOpenProfile
        self.onStartSession = onStartSession
        self.onResumeSession = onResumeSession
        self.onStartRun = onStartRun
        self.onCreateRoutine = onCreateRoutine
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
                .pulseAnimation(.snappy, value: startTitle)
                .hidingNavigationBar()
                .navigationDestination(isPresented: $model.isShowingWhy) {
                    WhyView(model: model, onStart: startSessionFromWhy, onResume: resumeSessionFromWhy)
                }
                .navigationDestination(isPresented: isShowingSupplements) {
                    if let supplements { SupplementsView(model: supplements) }
                }
                .navigationDestination(isPresented: $model.isShowingNight) {
                    if let nightModel { NightScreen(model: nightModel) }
                }
        }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .mobility: MobilitySheet()
            }
        }
        // Le score qui arrive ou change sous le focus (lecture Santé, check-in validé) est dit à voix haute.
        .onChange(of: model.score) { old, new in
            if let announcement = TodayModel.scoreAnnouncement(old: old, new: new) {
                PulseAnnouncement.post(announcement)
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
                SessionCard(model: model, onWhy: model.showWhy, onResume: onResumeSession, onStartRun: onStartRun,
                            onCreateRoutine: onCreateRoutine)
                if let offer = model.deloadOffer {
                    DeloadOfferCard(offer: offer, errorMessage: model.deloadErrorMessage) { accepted in
                        Task { await model.decideDeload(accepted) }
                    }
                }
                if let supplements {
                    SupplementsCard(model: supplements) { isShowingSupplements.wrappedValue = true }
                }
                PulseSectionHeader(String(localized: "Tendances", bundle: .module))
                LoadCard(content: model.load)
                TrendTilesView(tiles: model.trends, onOpenSleep: openNightAction)
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable {
            await model.refresh()
            await supplements?.load()
        }
    }

    /// L'action de la tuile Sommeil, seulement quand elle montre une nuit. Propriété typée plutôt qu'un ternaire sur une
    /// référence de méthode : le compilateur Release échoue sur ce dernier (voir PlanningView, 969406b).
    private var openNightAction: (() -> Void)? {
        guard model.canOpenNight else { return nil }
        return { openNight() }
    }

    /// Pousse l'écran Nuit sur la nuit qui s'est terminée ce matin (ou la plus récente).
    private func openNight() {
        let environment = model.environment
        nightModel = NightModel(service: environment.nights, initialDay: environment.now(), calendar: environment.calendar)
        model.isShowingNight = true
    }

    private var isShowingSupplements: Binding<Bool> {
        showsSupplements ?? $localShowsSupplements
    }

    /// Le libellé du bouton ancré, `nil` quand la séance du jour n'est pas une musculation à lancer, ou tant que le check-in
    /// attend ses réponses : « Démarrer » ne se superpose pas au formulaire et à son propre bouton.
    private var startTitle: String? {
        if case .needsCheckIn = model.score { return nil }
        guard case .strength(let card) = model.card else { return nil }
        return card.startButton
    }

    private func startSession() {
        if let launch = model.shownSessionLaunch() {
            onStartSession(launch)
        }
    }

    /// Depuis l'écran « Pourquoi » : la séance s'ouvre en plein écran et l'écran se referme derrière elle, l'accueil revient
    /// à la fin de la séance.
    private func startSessionFromWhy() {
        model.closeWhy()
        startSession()
    }

    private func resumeSessionFromWhy() {
        model.closeWhy()
        onResumeSession()
    }

    /// Les données ne suffisent pas : le check-in prend la place de la carte de récupération, la séance reste dessous. L'erreur
    /// d'enregistrement s'affiche juste au-dessus du bouton du check-in.
    @ViewBuilder
    private var recoveryOrCheckIn: some View {
        if case .needsCheckIn = model.score {
            VStack(spacing: 12) {
                CheckInView(form: model.checkIn, scrollable: false, errorMessage: model.errorMessage,
                            isSubmitting: model.isSubmittingCheckIn) { _ in
                    Task { await model.submitCheckIn() }
                }
            }
            // Le message apparaît sous le focus, sur un conteneur qui reste là : l'annonce suit son changement.
            .pulseAnnounceError(model.errorMessage)
        } else {
            RecoveryCard(score: model.score, factors: model.factors, marker: model.marker, spokenMarker: model.spokenMarker,
                         onWhy: model.showWhy, isLoading: model.isLoading, scoreFailed: model.scoreFailed)
        }
    }
}

/// « Bonjour Mathéo », la date, la pastille « Synchro 08:00 » qui relance la lecture et le bouton du profil.
private struct TodayHeader: View {
    let model: TodayModel
    let onOpenProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                // Pendant la lecture, un indicateur à la place du point : la touche a bien été prise en compte.
                if model.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(model.lastSyncText == nil ? PulsePalette.muted : PulsePalette.text)
                        .frame(width: 6, height: 6)
                }
                Text(syncText)
                    .pulseEyebrow(PulsePalette.text2)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(PulsePalette.surface.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(PulsePalette.ink.opacity(0.2), lineWidth: 1))
            // La pastille reste à 32 points ; la cible tactile monte à 44.
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(model.isLoading)
        .accessibilityLabel(model.syncAccessibilityText)
        .accessibilityValue(model.isLoading ? String(localized: "Lecture en cours", bundle: .module) : "")
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
