import AppIntents
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TodayFeature

/// « Quel est mon score de récupération ? » : lit le score du jour déjà calculé et enregistré par Pulse, sans ouvrir l'app, et
/// le dit avec son état. Le score vient de données Apple Santé : comme pour le reste de l'app, rien ne s'affiche ni ne se dit
/// iPhone verrouillé sans déverrouillage (Face ID ou code).
struct RecoveryScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Score de récupération"
    static let description = IntentDescription("Dit ton score de récupération du jour et ton état, sans ouvrir Pulse.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Dependency private var dependencies: AppDependencies

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let now = dependencies.now()
        let calendar = dependencies.calendar
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
        let recoveries = try await dependencies.recovery.dailyRecoveries(from: dayStart, to: dayEnd)
        let recovery = ShortcutText.todaysRecovery(recoveries, now: now, calendar: calendar)
        // Le marqueur de calibration tel que l'accueil le dit à VoiceOver (« en calibration, 9 nuits »).
        let calibration = recovery.flatMap(FactorFormatter.spokenMarker(for:))
        let reply = ShortcutText.recoveryScore(recovery, calibration: calibration)
        return .result(dialog: IntentDialog("\(reply)"), view: RecoveryScoreSnippet(recovery: recovery, reply: reply))
    }
}

/// Sous la réponse de Siri : le score, son état et son marqueur comme sur l'accueil, et « Voir pourquoi » qui ouvre l'écran
/// « Pourquoi » de l'app.
private struct RecoveryScoreSnippet: View {
    let recovery: DailyRecovery?
    let reply: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let recovery {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(recovery.score.rounded()))")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recovery.category.localizedName)
                            .font(.headline)
                        // « Estimé » ou « En calibration (9 nuits) », comme sur la carte de l'accueil.
                        if let marker = FactorFormatter.marker(for: recovery) {
                            Text(marker)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(reply)
            } else {
                Text(reply)
                    .font(.headline)
            }
            Button(intent: OpenWhyIntent()) {
                Label(recovery == nil ? String(localized: "Ouvrir Pulse") : String(localized: "Voir pourquoi"),
                      systemImage: recovery == nil ? "arrow.up.forward.app" : "info.circle")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
