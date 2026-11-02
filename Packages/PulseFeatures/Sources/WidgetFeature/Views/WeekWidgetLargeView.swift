import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le grand widget de l'écran d'accueil pour la semaine (maquette `ios-page2`) :
/// en-tête avec badge, rangée des 7 jours, carte séance du jour, jauge de charge et séance de demain.
public struct WeekWidgetLargeView: View {
    private let content: WeekWidgetContent

    public init(content: WeekWidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            daysRow
            divider
            todayBlock
            divider
            acwrBlock
            tomorrowRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private var headerRow: some View {
        HStack {
            Text(WeekWidgetContent.displayName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PulsePalette.text)
            Spacer()
            Text(content.badgeText)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color(PulsePalette.accent(for: .amber).accent).opacity(0.18))
                .foregroundStyle(Color(PulsePalette.accent(for: .amber).accent))
                .clipShape(Capsule())
        }
    }

    private var daysRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(content.days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 5) {
                    Text(day.letter)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PulsePalette.muted)
                    dayBubble(for: day)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayBubble(for day: WeekWidgetContent.DayItem) -> some View {
        let isToday = day.state == .today
        ZStack {
            Circle()
                .fill(isToday ? Color(PulsePalette.accent(for: .amber).accent).opacity(0.18) : PulsePalette.surface2)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isToday ? Color(PulsePalette.accent(for: .amber).accent) : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .frame(width: 28, height: 28)
            Image(systemName: day.iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(
                    isToday ? Color(PulsePalette.accent(for: .amber).accent)
                        : (day.state == .completed ? PulsePalette.text : PulsePalette.muted)
                )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(PulsePalette.line)
            .frame(height: 1)
    }

    private var todayBlock: some View {
        HStack(spacing: 12) {
            MuscleMapView(levels: content.todayMuscleLevels, label: content.todayTitle, height: 74)
                .frame(width: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Aujourd'hui", bundle: .module))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PulsePalette.muted)
                Text(content.todayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PulsePalette.text)
                    .lineLimit(1)
                Text(content.todayMeta)
                    .font(.system(size: 12))
                    .foregroundStyle(PulsePalette.text2)
                    .lineLimit(1)
            }
        }
    }

    private var acwrBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "Charge 7 j / 28 j", bundle: .module))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PulsePalette.muted)
                Spacer()
                Text(content.acwrZoneText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PulsePalette.ok)
            }
            loadBar
        }
    }

    private var loadBar: some View {
        GeometryReader { proxy in
            let fraction = LoadGaugeGeometry.fraction(ratio: content.acwrRatio)
            let xPos = min(max(proxy.size.width * fraction, 4), proxy.size.width - 4)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: PulsePalette.run, location: 0),
                                .init(color: PulsePalette.ok, location: 0.2),
                                .init(color: PulsePalette.ok, location: 0.6),
                                .init(color: PulsePalette.warn, location: 0.78),
                                .init(color: PulsePalette.bad, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 6)
                Circle()
                    .fill(PulsePalette.text)
                    .frame(width: 10, height: 10)
                    .offset(x: xPos - 5)
            }
        }
        .frame(height: 10)
    }

    private var tomorrowRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.run")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PulsePalette.run)
            Text(content.tomorrowText)
                .font(.system(size: 11.5))
                .foregroundStyle(PulsePalette.muted)
                .lineLimit(1)
        }
    }
}

#Preview("Grand Semaine") {
    WeekWidgetLargeView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .padding(16)
        .frame(width: 338, height: 338)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: 22))
        .padding()
        .background(PulsePalette.background)
}
