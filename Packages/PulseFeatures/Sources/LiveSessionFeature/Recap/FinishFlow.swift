import PulseDesignSystem
import SwiftUI

/// L'écran de la séance avec la suite de « Terminer » et d'« Abandonner » (spec M4 §14.6, §16, §17) : la confirmation s'il reste
/// des séries prévues, l'alerte de la séance oubliée avec l'heure proposée, puis le récap en plein écran, qu'on ne ferme
/// qu'en enregistrant. `onFinished` est appelé une fois la séance enregistrée ou abandonnée (`LiveSessionCoordinator.didFinish`).
public struct FinishFlow: View {
    private let model: LiveSessionModel
    @State private var flow: FinishFlowModel

    public init(model: LiveSessionModel, onFinished: @escaping @MainActor () -> Void) {
        self.model = model
        _flow = State(initialValue: FinishFlowModel(live: model, onFinished: onFinished))
    }

    public var body: some View {
        LiveSessionView(model: model, onFinish: { Task { await flow.finishTapped() } }, onAbandon: { flow.abandonTapped() })
            .confirmationDialog(confirmationTitle, isPresented: isShowingConfirmation, titleVisibility: .visible) {
                confirmationActions
            } message: {
                if flow.confirmation == .abandon {
                    Text(String(localized: "Les séries validées sont gardées, les autres ne sont pas enregistrées.", bundle: .module))
                }
            }
            .alert(forgottenTitle, isPresented: isShowingForgotten) {
                forgottenActions
            }
            .alert(String(localized: "Abandon impossible", bundle: .module), isPresented: isShowingError) {
                Button(String(localized: "OK", bundle: .module)) { flow.dismissError() }
            } message: {
                Text(flow.errorMessage ?? "")
            }
            .recapCover(item: recapBinding) { recap in
                RecapView(model: recap, calendar: flow.calendar) { flow.recapSaved() }
                    .interactiveDismissDisabled()
            }
    }

    // MARK: Confirmation

    private var confirmationTitle: String {
        switch flow.confirmation {
        case .unfinished(let remaining): FinishFlowModel.remainingText(remaining)
        case .abandon, nil: String(localized: "Abandonner la séance ?", bundle: .module)
        }
    }

    @ViewBuilder
    private var confirmationActions: some View {
        if flow.confirmation == .abandon {
            Button(String(localized: "Abandonner", bundle: .module), role: .destructive) { confirm() }
        } else {
            Button(String(localized: "Terminer quand même", bundle: .module)) { confirm() }
        }
        Button(String(localized: "Continuer la séance", bundle: .module), role: .cancel) { flow.cancelConfirmation() }
    }

    private func confirm() {
        Task { await flow.confirm() }
    }

    // MARK: Séance oubliée

    private var forgottenTitle: String {
        guard let prompt = flow.forgotten else { return "" }
        let time = FinishFlowModel.timeText(prompt.suggestedEnd, calendar: flow.calendar)
        return String(localized: "Séance commencée il y a longtemps : la clore à \(time) ?", bundle: .module)
    }

    @ViewBuilder
    private var forgottenActions: some View {
        if let prompt = flow.forgotten {
            let time = FinishFlowModel.timeText(prompt.suggestedEnd, calendar: flow.calendar)
            Button(String(localized: "Clore à \(time)", bundle: .module)) {
                Task { await flow.chooseEnd(usingSuggestion: true) }
            }
            .keyboardShortcut(.defaultAction)
            Button(String(localized: "Garder l'heure actuelle", bundle: .module)) {
                Task { await flow.chooseEnd(usingSuggestion: false) }
            }
        }
    }

    // MARK: Liaisons

    // Les boutons résolvent eux-mêmes l'état : la fermeture de la fenêtre ne doit pas l'effacer avant que leur tâche le lise.
    private var isShowingConfirmation: Binding<Bool> {
        Binding(get: { flow.confirmation != nil }, set: { _ in })
    }

    private var isShowingForgotten: Binding<Bool> {
        Binding(get: { flow.forgotten != nil }, set: { _ in })
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { flow.errorMessage != nil }, set: { if !$0 { flow.dismissError() } })
    }

    private var recapBinding: Binding<RecapModel?> {
        Binding(get: { flow.recap }, set: { _ in })
    }
}

private extension View {
    /// Le récap en plein écran sur iPhone ; la feuille du Mac, où les tests tournent, n'a pas de plein écran.
    func recapCover<Item: Identifiable & AnyObject, Content: View>(
        item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }
}

extension RecapModel: Identifiable {}
