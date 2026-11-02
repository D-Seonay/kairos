import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'en-tête de la séance (spec M4 §14.2) : le titre, « Terminer », le menu « Abandonner », puis la durée écoulée, le tonnage et
/// les séries de travail faites sur prévues. Les confirmations sont celles de l'appelant.
struct LiveHeader: View {
    let session: LiveSession
    let onFinish: () -> Void
    let onAbandon: () -> Void
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(Self.titleText(session.title))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PulsePalette.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                menu
                Button(action: onFinish) {
                    Text(String(localized: "Terminer", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(Color(palette.accentInk))
                        .padding(.horizontal, 18)
                        .frame(minHeight: LiveSetRow.targetHeight)
                        .background(Color(palette.accent), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(LiveSessionIdentifiers.finishButton)
            }
            HStack {
                stat(String(localized: "Durée", bundle: .module)) {
                    Text(timerInterval: session.startedAt...Date.distantFuture, pauseTime: nil, countsDown: false, showsHours: false)
                }
                stat(String(localized: "Tonnage", bundle: .module), spoken: Self.tonnageText(kg: session.tonnageKg)) {
                    Text(Self.tonnageText(kg: session.tonnageKg))
                }
                stat(String(localized: "Séries", bundle: .module),
                     spoken: Self.progressAccessibilityText(done: session.doneWorkingSets, planned: session.plannedWorkingSets)) {
                    Text(Self.progressText(done: session.doneWorkingSets, planned: session.plannedWorkingSets))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var menu: some View {
        Menu {
            Button(role: .destructive, action: onAbandon) {
                Label(String(localized: "Abandonner", bundle: .module), systemImage: "xmark.circle")
            }
            .accessibilityIdentifier(LiveSessionIdentifiers.abandonButton)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundStyle(PulsePalette.text2)
                .frame(width: LiveSetRow.targetHeight, height: LiveSetRow.targetHeight)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Menu de la séance", bundle: .module))
        .accessibilityIdentifier(LiveSessionIdentifiers.menuButton)
    }

    private func stat(_ name: String, spoken: String? = nil, @ViewBuilder value: () -> some View) -> some View {
        VStack(spacing: 0) {
            Text(name).font(.caption2.weight(.semibold)).foregroundStyle(PulsePalette.muted)
            value()
                .font(.headline.monospacedDigit())
                .foregroundStyle(PulsePalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(spoken ?? "")
    }
}

// MARK: - Textes

extension LiveHeader {
    /// Le titre de la séance ; « Séance » quand elle n'en a pas.
    nonisolated static func titleText(_ title: String) -> String {
        title.isEmpty ? String(localized: "Séance", bundle: .module) : title
    }

    /// « 4 / 14 » : les séries de travail faites sur prévues.
    nonisolated static func progressText(done: Int, planned: Int) -> String {
        "\(done) / \(planned)"
    }

    /// « 4 séries faites sur 14 ».
    nonisolated static func progressAccessibilityText(done: Int, planned: Int) -> String {
        done == 1 ? String(localized: "1 série faite sur \(planned)", bundle: .module)
            : String(localized: "\(done) séries faites sur \(planned)", bundle: .module)
    }

    /// « 1240 kg », « 62,5 kg ».
    nonisolated static func tonnageText(kg: Double) -> String {
        String(localized: "\(PulseFormat.decimal(kg, maxFractionDigits: 1)) kg", bundle: .module)
    }
}
