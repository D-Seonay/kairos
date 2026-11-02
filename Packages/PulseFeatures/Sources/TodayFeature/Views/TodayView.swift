import CheckInFeature
import PulseDesignSystem
import PulseServices
import SwiftUI

/// L'onglet « Aujourd'hui » : en-tête, carte de récupération (ou check-in), séance du jour, charge d'entraînement et tendances,
/// avec sa feuille de mobilité et l'écran « Pourquoi », poussé dans sa pile de navigation. « Démarrer » rend la séance à lancer à
/// l'app, qui ouvre l'écran en direct ; « Reprendre la séance » lui demande de rouvrir celle en cours.
public struct TodayView: View {
    private let model: TodayModel
    private let onOpenProfile: () -> Void
    private let onStartSession: (SessionLaunch) -> Void
    private let onResumeSession: () -> Void

    public init(model: TodayModel, onOpenProfile: @escaping () -> Void, onStartSession: @escaping (SessionLaunch) -> Void,
                onResumeSession: @escaping () -> Void) {
        self.model = model
        self.onOpenProfile = onOpenProfile
        self.onStartSession = onStartSession
        self.onResumeSession = onResumeSession
    }

    public var body: some View {
        @Bindable var model = model
        NavigationStack {
            content
                .background(PulsePalette.background)
                .hidingNavigationBar()
                .navigationDestination(isPresented: $model.isShowingWhy) {
                    WhyView(model: model, onStart: startSession, onResume: onResumeSession)
                }
        }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .mobility: MobilitySheet()
            }
        }
        // Le retour au premier plan est rafraîchi par la racine de l'app, quel que soit l'onglet affiché.
        .task { await model.refresh() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: PulseMetrics.spacing) {
                TodayHeader(model: model, onOpenProfile: onOpenProfile)
                recoveryOrCheckIn
                SessionCard(model: model, onWhy: model.showWhy, onStart: startSession, onResume: onResumeSession)
                LoadCard(content: model.load)
                TrendTilesView(tiles: model.trends)
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable { await model.refresh() }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.greeting)
                        .font(.title.weight(.heavy))
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.dateText)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
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
            Image(systemName: "person.crop.circle")
                .font(.title)
                .foregroundStyle(PulsePalette.text2)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Profil", bundle: .module))
    }

    private var syncPill: some View {
        Button {
            Task { await model.refresh() }
        } label: {
            Label(syncText, systemImage: "arrow.triangle.2.circlepath")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PulsePalette.text2)
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(PulsePalette.surface2, in: Capsule())
        }
        .buttonStyle(.plain)
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
