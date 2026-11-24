import MapKit
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La carte du tracé d'une course (spec V2a §4.5) : une polyligne MapKit tracée à l'encre, sur un fond désaturé dans le style
/// argentique, sans contrôles ni interaction. Rien ne s'affiche quand le tracé est vide. VoiceOver la lit comme une image :
/// « Tracé de la course, 4,4 kilomètres ».
public struct RunRouteMap: View {
    private let points: [RunTrackPoint]
    private let distanceMeters: Double?

    /// `distanceMeters` : la distance de la séance à dire ; sans elle, la longueur du tracé simplifié.
    public init(points: [RunTrackPoint], distanceMeters: Double? = nil) {
        self.points = points
        self.distanceMeters = distanceMeters
    }

    public var body: some View {
        if !points.isEmpty {
            Map(initialPosition: .automatic, interactionModes: []) {
                MapPolyline(coordinates: coordinates)
                    .stroke(PulsePalette.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControls {}
            .saturation(0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(RunText.routeLabel(distanceMeters: distanceMeters ?? RunText.routeDistance(points)))
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier(RunIdentifiers.routeMap)
        }
    }

    private var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

#if DEBUG
#Preview("Tracé") {
    RunRouteMap(points: RunPreviewSupport.loop())
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
        .padding()
}
#endif
