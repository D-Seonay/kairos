import PulseServices
import SwiftUI

/// Le choix du jour de rattrapage d'une séance manquée (« Rattraper… ») : les jours de repos à venir d'abord, puis les jours
/// déjà chargés, dont la séance serait remplacée.
private struct CatchUpDialog: ViewModifier {
    let model: PlanningModel
    let onDone: () async -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            if let day = model.catchingUp {
                ForEach(model.catchUpTargets(for: day)) { target in
                    Button(model.catchUpLabel(of: target)) {
                        Task {
                            await model.catchUp(day, on: target)
                            await onDone()
                        }
                    }
                }
            }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) { model.catchingUp = nil }
        } message: {
            Text(String(localized: "La séance passe sur le jour choisi ; le jour manqué devient « Rattrapée ».", bundle: .module))
        }
    }

    private var title: String {
        guard let day = model.catchingUp else { return "" }
        return String(localized: "Rattraper « \(model.title(of: day)) »", bundle: .module)
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { model.catchingUp != nil }, set: { if !$0 { model.catchingUp = nil } })
    }
}

extension View {
    func catchUpDialog(model: PlanningModel, onDone: @escaping () async -> Void) -> some View {
        modifier(CatchUpDialog(model: model, onDone: onDone))
    }
}
