import PulseDesignSystem
import SwiftUI

/// L'écran plein de la course, que l'app présente : le départ, la course, puis le récap, selon l'étape du modèle. La précision
/// de la localisation est relue à l'ouverture et au retour dans l'app, après un passage dans les réglages.
public struct RunFlowView: View {
    private let model: RunModel
    @Environment(\.scenePhase) private var scenePhase

    public init(model: RunModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            switch model.phase {
            case .start(let launch):
                RunStartView(model: model, launch: launch)
            case .running:
                RunView(model: model)
            case .recap(let recap):
                RunRecapView(model: recap, calendar: model.calendar)
            }
        }
        .task { await model.refreshLocationAccuracy() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshLocationAccuracy() } }
        }
    }
}
