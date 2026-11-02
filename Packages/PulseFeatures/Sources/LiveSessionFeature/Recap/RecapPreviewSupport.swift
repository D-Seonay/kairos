#if DEBUG
import PulseDomain
import PulseServices
import SwiftUI

extension LivePreviewSupport {
    /// Une séance de pectoraux et triceps dont les séries du développé couché sont validées, pour un vrai récap : le service en
    /// mémoire calcule le bilan. `model` est celui de la séance, `recap` celui du récap.
    static func finishing() async -> (model: LiveSessionModel, recap: RecapModel)? {
        let environment = await environment()
        guard let session = try? await environment.service.start(launch) else { return nil }
        let model = LiveSessionModel(session: session, environment: environment)
        for set in model.session.exercises[0].sets {
            await model.tap(set: set.id)
            await model.setRPE(8, set: set.id)
        }
        let recap = RecapModel(service: environment.service, endedAt: environment.now().addingTimeInterval(55 * 60))
        await recap.load()
        return (model, recap)
    }
}

private struct RecapPreviewHost: View {
    @State private var recap: RecapModel?

    var body: some View {
        Group {
            if let recap {
                RecapView(model: recap, calendar: LivePreviewSupport.calendar, onSaved: {})
            } else {
                ProgressView()
            }
        }
        .task { recap = await LivePreviewSupport.finishing()?.recap }
        .preferredColorScheme(.dark)
    }
}

private struct FinishFlowPreviewHost: View {
    @State private var model: LiveSessionModel?

    var body: some View {
        Group {
            if let model {
                FinishFlow(model: model, onFinished: {})
            } else {
                ProgressView()
            }
        }
        .task { model = await LivePreviewSupport.finishing()?.model }
        .preferredColorScheme(.dark)
    }
}

#Preview("Récap") {
    RecapPreviewHost()
}

#Preview("Récap, accessibilité XL") {
    RecapPreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Terminer") {
    FinishFlowPreviewHost()
}
#endif
