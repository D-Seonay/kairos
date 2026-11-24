import PulseDesignSystem
import PulseServices
import SwiftUI

/// Le bandeau « Reprendre la course » en haut des onglets, quand la course tourne sans être à l'écran (écran réduit, relance) :
/// son titre, le temps en mouvement (figé en pause), la distance et « Reprendre ». Comme celui de la séance de musculation.
public struct ResumeRunBar: View {
    private let snapshot: RunSnapshot
    private let onResume: () -> Void

    public init(snapshot: RunSnapshot, onResume: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onResume = onResume
    }

    public var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                TimelineView(.periodic(from: snapshot.startedAt, by: 1)) { context in
                    let seconds = Int(RunClock.movingSeconds(from: snapshot.startedAt, pauses: snapshot.pauses, at: context.date))
                    summary(seconds: seconds)
                }
                Button(String(localized: "Reprendre", bundle: .module), action: onResume)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel(String(localized: "Reprendre la course", bundle: .module))
                    .accessibilityIdentifier(RunIdentifiers.resumeButton)
            }
        }
        .accessibilityIdentifier(RunIdentifiers.resumeBar)
    }

    private func summary(seconds: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.isPaused ? String(localized: "Course en pause", bundle: .module)
                 : String(localized: "Course en cours", bundle: .module))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PulsePalette.text2)
            Text(snapshot.launch.title)
                .font(.headline)
            Text(Self.detail(snapshot, seconds: seconds))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(PulsePalette.text2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(snapshot, seconds: seconds))
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// « 24:13 · 4,38 km », ou le temps seul sans distance.
    static func detail(_ snapshot: RunSnapshot, seconds: Int) -> String {
        let time = RunText.elapsed(seconds: seconds)
        guard snapshot.distanceMeters != nil else { return time }
        return "\(time) · \(RunText.distance(snapshot.distanceMeters))"
    }

    /// « Course en cours, Footing facile, 24 minutes 13, 4,4 kilomètres ».
    static func spoken(_ snapshot: RunSnapshot, seconds: Int) -> String {
        var parts = [snapshot.isPaused ? String(localized: "Course en pause", bundle: .module)
                     : String(localized: "Course en cours", bundle: .module), snapshot.launch.title,
                     RunText.elapsedSpoken(seconds: seconds)]
        if let distance = RunText.distanceSpoken(snapshot.distanceMeters) { parts.append(distance) }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview("Reprendre la course") {
    ResumeRunBar(snapshot: RunPreviewSupport.snapshot(), onResume: {})
        .padding()
        .background(PulsePalette.background)
}

#Preview("Reprendre la course, accessibilité 3") {
    ResumeRunBar(snapshot: RunPreviewSupport.snapshot(paused: true), onResume: {})
        .padding()
        .background(PulsePalette.background)
        .dynamicTypeSize(.accessibility3)
}
#endif
