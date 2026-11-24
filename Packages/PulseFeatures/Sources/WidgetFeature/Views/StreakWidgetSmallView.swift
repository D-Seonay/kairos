import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le petit widget de l'écran d'accueil pour la série (maquette `ios-accueil`) : flamme, nombre de semaines,
/// rangée des pastilles de la semaine, et progression sous forme « 3 sur 5 cette semaine ».
public struct StreakWidgetSmallView: View {
    private let content: StreakWidgetContent

    public init(content: StreakWidgetContent) {
        self.content = content
    }

    public var body: some View {
        StreakWidgetSmallViewBody(content: content)
            .dynamicTypeSize(...WidgetTypeCap.streakSmall)
    }
}

/// Le contenu de la vue, plafonné par `StreakWidgetSmallView` : ses `@ScaledMetric` lisent la taille déjà plafonnée.
struct StreakWidgetSmallViewBody: View {
    let content: StreakWidgetContent

    /// Les anneaux « à venir » et « repos » et le tiret doivent faire au moins 3:1 sur le dégradé, dans les deux apparences
    /// (mesuré avec l'encre du widget sur la mi-course du dégradé : 3,5:1 et plus).
    private static let upcomingRingOpacity = 0.6
    private static let restRingOpacity = 0.55
    private static let restDashOpacity = 0.6

    @ScaledMetric(relativeTo: .caption) private var headerSize = 12
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 44
    @ScaledMetric(relativeTo: .footnote) private var unitSize = 13
    @ScaledMetric(relativeTo: .caption) private var footerSize = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            streakNumber
            Spacer(minLength: 8)
            weekDots
            Spacer(minLength: 4)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private var header: some View {
        Label {
            Text(StreakWidgetContent.displayName)
        } icon: {
            Image(systemName: "flame.fill")
        }
        .font(.system(size: headerSize, weight: .bold))
        .opacity(0.85)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var streakNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: content.weeksText)
                .font(.system(size: numberSize, weight: .light).monospacedDigit())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if content.isReady {
                Text(String(localized: "semaines", bundle: .module))
                    .font(.system(size: unitSize, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var weekDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(content.weekDays.enumerated()), id: \.offset) { _, state in
                dot(for: state)
            }
        }
    }

    @ViewBuilder
    private func dot(for state: StreakWidgetContent.DayState) -> some View {
        switch state {
        case .completed:
            Circle()
                .fill(Color.primary)
                .frame(width: 14, height: 14)
        case .today:
            Circle()
                .fill(Color.primary.opacity(0.35))
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                )
                .frame(width: 14, height: 14)
        case .upcoming:
            Circle()
                .strokeBorder(Color.primary.opacity(Self.upcomingRingOpacity), lineWidth: 1.5)
                .frame(width: 14, height: 14)
        case .rest:
            Circle()
                .strokeBorder(Color.primary.opacity(Self.restRingOpacity), lineWidth: 1)
                .frame(width: 14, height: 14)
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(Self.restDashOpacity))
                        .frame(width: 6, height: 1.5)
                )
        }
    }

    private var footer: some View {
        Text(content.subtitle)
            .font(.system(size: footerSize, weight: .bold))
            .opacity(0.9)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }
}

#Preview("Petit Streak Widget") {
    let amber = PulsePalette.accent(for: .amber)
    StreakWidgetSmallView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .foregroundStyle(Color(amber.accentInk))
        .padding(16)
        .frame(width: 158, height: 158)
        .background(
            LinearGradient(
                colors: [Color(amber.accent2), Color(amber.accent)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .padding()
}

#Preview("Petit Streak Widget, accessibilité 3") {
    let amber = PulsePalette.accent(for: .amber)
    StreakWidgetSmallView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .dynamicTypeSize(.accessibility3)
        .foregroundStyle(Color(amber.accentInk))
        .padding(16)
        .frame(width: 158, height: 158)
        .background(
            LinearGradient(
                colors: [Color(amber.accent2), Color(amber.accent)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .padding()
}
