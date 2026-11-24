import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

// MARK: - Mur des records

/// Les quatre levés de base et les trois chronos de course, toujours affichés ; « Tout voir » ouvre Stats → Records. Avec
/// `opensLifts`, un levé qui a un record ouvre la progression de l'exercice, comme une ligne de Stats → Records.
struct RecordsWall: View {
    let lifts: [StrengthRecordLine]
    let runs: [RunBest]
    let calendar: Calendar
    let today: Date
    /// Vrai quand le profil peut pousser la fiche d'un exercice (`ProfileDestination.exercise`).
    var opensLifts = false
    let onOpenRecords: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(String(localized: "Records", bundle: .module)) {
                Button(String(localized: "Tout voir", bundle: .module), action: onOpenRecords)
                    .buttonStyle(PillButtonStyle())
            }
            ObsidianCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(RecordStats.mainLifts, id: \.self) { id in
                        liftRow(id)
                    }
                    Divider().overlay(PulsePalette.line)
                    ForEach(runs) { run in
                        row(title: ProfileText.runTitle(run.distance),
                            detail: run.date.map { ProfileText.shortDate($0, calendar: calendar, today: today) },
                            value: run.seconds.map { ProfileText.raceTime(seconds: $0) },
                            missing: String(localized: "Pas encore couru", bundle: .module),
                            spoken: ProfileText.runRecordSpoken(run, calendar: calendar, today: today))
                    }
                }
            }
        }
    }

    /// Le record d'un levé de base, nommé par le répertoire d'exercices ; sans record, son nom français et « Pas encore de record ».
    @ViewBuilder
    private func liftRow(_ id: String) -> some View {
        let line = lifts.first { $0.exercise == .content(id: id) }
        let title = line?.name ?? ProfileText.mainLiftName(id)
        let spoken = ProfileText.liftRecordSpoken(title: title, line: line, calendar: calendar, today: today)
        let content = row(title: title,
                          detail: line.map { ProfileText.shortDate($0.date, calendar: calendar, today: today) },
                          value: line.map(ProfileText.recordValue),
                          missing: String(localized: "Pas encore de record", bundle: .module),
                          spoken: spoken, showsChevron: opensLifts && line != nil)
        if opensLifts, let line {
            NavigationLink(value: ProfileDestination.exercise(line.exercise)) { content }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken)
                .accessibilityHint(String(localized: "Ouvre la progression de l'exercice", bundle: .module))
                .accessibilityAddTraits(.isButton)
        } else {
            content
        }
    }

    /// Sans valeur (un levé sans record, une distance jamais couverte) : `missing`.
    /// Titre et valeur côte à côte ; aux tailles d'accessibilité, la valeur sous le titre. VoiceOver lit `spoken`, la valeur d'abord.
    private func row(title: String, detail: String?, value: String?, missing: String, spoken: String,
                     showsChevron: Bool = false) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 12) {
                if let value {
                    Text(value)
                        .font(PulseFont.value(.headline))
                        .foregroundStyle(PulsePalette.text)
                } else {
                    Text(missing)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
                if showsChevron { RowChevron() }
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
