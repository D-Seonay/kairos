import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Les chiffres de la course en cours : le temps en mouvement (rafraîchi chaque seconde depuis le départ et les pauses), la
/// distance, l'allure du km en cours et la moyenne, la progression de l'objectif et la FC. Les gros chiffres suivent la taille du
/// texte, plafonnée pour tenir dans l'écran.
struct RunLiveMetrics: View {
    let snapshot: RunSnapshot
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 88
    @ScaledMetric(relativeTo: .title) private var distanceSize: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                time
                distance
            }
            paces
            if let progress = snapshot.targetProgress { RunProgressBar(progress: progress) }
            if let bpm = snapshot.heartRate { heartRate(bpm) }
        }
    }

    // MARK: Temps et distance

    private var time: some View {
        TimelineView(.periodic(from: snapshot.startedAt, by: 1)) { context in
            let seconds = Int(RunClock.movingSeconds(from: snapshot.startedAt, pauses: snapshot.pauses, at: context.date))
            Text(RunText.elapsed(seconds: seconds))
                .font(PulseFont.score(size: min(timeSize, 140)))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(PulsePalette.text)
                .accessibilityLabel(String(localized: "Temps en mouvement", bundle: .module))
                .accessibilityValue(RunText.elapsedSpoken(seconds: seconds))
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier(RunIdentifiers.elapsed)
        }
    }

    private var distance: some View {
        Text(RunText.distance(snapshot.distanceMeters))
            .font(PulseFont.score(size: min(distanceSize, 80)))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(PulsePalette.run)
            .accessibilityLabel(String(localized: "Distance", bundle: .module))
            .accessibilityValue(RunText.distanceSpoken(snapshot.distanceMeters)
                                ?? String(localized: "non mesurée", bundle: .module))
            .accessibilityIdentifier(RunIdentifiers.distance)
    }

    // MARK: Allures

    /// Côte à côte, l'une sous l'autre aux tailles de texte d'accessibilité.
    private var paces: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            pace(snapshot.currentKilometerPace, name: String(localized: "allure km", bundle: .module),
                 spokenName: String(localized: "Allure du kilomètre en cours", bundle: .module))
            pace(snapshot.averagePace, name: String(localized: "moyenne", bundle: .module),
                 spokenName: String(localized: "Allure moyenne", bundle: .module))
        }
    }

    private func pace(_ seconds: Int?, name: String, spokenName: String) -> some View {
        VStack(spacing: 2) {
            Text(RunText.pace(seconds))
                .font(PulseFont.value(.title2))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(name)
                .pulseEyebrow()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenName)
        .accessibilityValue(RunText.paceSpoken(seconds))
    }

    // MARK: FC

    private func heartRate(_ bpm: Double) -> some View {
        Label {
            Text(RunText.heartRate(bpm)).font(PulseFont.value(.title3))
        } icon: {
            Image(systemName: "heart.fill").accessibilityHidden(true)
        }
        .foregroundStyle(PulsePalette.text2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Fréquence cardiaque", bundle: .module))
        .accessibilityValue(RunText.heartRateSpoken(bpm))
    }
}

/// La progression vers l'objectif : une barre à l'encre de la course et le pourcentage. Pleine à l'objectif atteint.
struct RunProgressBar: View {
    let progress: Double

    var body: some View {
        let fraction = min(max(progress, 0), 1)
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PulsePalette.runSoft)
                    Capsule().fill(PulsePalette.run)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
            .pulseAnimation(.easeOut(duration: 0.4), value: fraction)
            Text(RunText.percent(progress))
                .font(PulseFont.value(.headline))
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Progression de l'objectif", bundle: .module))
        .accessibilityValue(RunText.percent(progress))
    }
}
