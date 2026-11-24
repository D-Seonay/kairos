import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La répartition par phase : le nom, la durée, la part de la nuit, une barre proportionnelle et l'écart à la moyenne des
/// 14 nuits précédentes. Chaque ligne se lit en une phrase.
struct StageBreakdownList: View {
    let rows: [BreakdownRow]

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "Répartition", bundle: .module))
                    .pulseEyebrow(PulsePalette.text2)
                    .accessibilityAddTraits(.isHeader)
                ForEach(rows) { row in
                    BreakdownRowView(row: row)
                }
            }
        }
    }
}

private struct BreakdownRowView: View {
    let row: BreakdownRow
    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    labels
                }
                VStack(alignment: .leading, spacing: 2) {
                    labels
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PulsePalette.line)
                    Capsule().fill(row.stage.color)
                        .frame(width: row.barWidth(available: proxy.size.width, minimum: barHeight))
                }
            }
            .frame(height: barHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder private var labels: some View {
        Text(row.name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PulsePalette.text)
        Text(PulseFormat.duration(minutes: row.minutes))
            .font(PulseFont.value(.subheadline))
            .foregroundStyle(PulsePalette.text)
        Text(NightText.share(row.share))
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text2)
        if let delta = row.delta {
            Text(String(localized: "\(delta) vs ta moyenne", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.muted)
        }
    }

    /// « Profond, 1 heure 30 minutes, 20 %, 12 minutes de plus que ta moyenne ».
    private var spoken: String {
        var text = "\(row.name), \(NightText.spokenMinutes(row.minutes)), \(NightText.share(row.share))"
        if let delta = row.delta {
            text += String(localized: ", \(delta) par rapport à ta moyenne", bundle: .module)
        }
        return text
    }
}
