import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le petit widget de l'écran d'accueil pour la charge (maquette `ios-page2`) :
/// ratio ACWR en grand, zone optimale, barre de repère et bornes 0,8 / 1,3.
public struct LoadWidgetSmallView: View {
    private let content: LoadWidgetContent

    public init(content: LoadWidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            bigRatio
            zoneLabel
            Spacer(minLength: 8)
            gaugeBar
            Spacer(minLength: 4)
            boundsRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private var header: some View {
        Label {
            Text(LoadWidgetContent.displayName)
        } icon: {
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(PulsePalette.muted)
        .lineLimit(1)
    }

    private var bigRatio: some View {
        Text(content.ratioText)
            .font(.system(size: 38, weight: .heavy))
            .foregroundStyle(PulsePalette.text)
            .monospacedDigit()
            .lineLimit(1)
    }

    private var zoneLabel: some View {
        Text(content.zoneText)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(content.isOptimal ? PulsePalette.ok : PulsePalette.warn)
            .lineLimit(1)
    }

    private var gaugeBar: some View {
        GeometryReader { proxy in
            let fraction = LoadGaugeGeometry.fraction(ratio: content.ratio)
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
                    .frame(height: 7)
                Circle()
                    .fill(PulsePalette.text)
                    .frame(width: 11, height: 11)
                    .offset(x: xPos - 5.5)
            }
        }
        .frame(height: 11)
    }

    private var boundsRow: some View {
        HStack {
            Text("0,8")
            Spacer()
            Text("1,3")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(PulsePalette.muted)
    }
}

#Preview("Petit Charge Widget") {
    LoadWidgetSmallView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .padding(16)
        .frame(width: 158, height: 158)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: 22))
        .padding()
        .background(PulsePalette.background)
}
