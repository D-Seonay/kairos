import PhotosUI
import PulseDesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Le menu d'ajout : « Prendre une photo » si l'appareil existe (« Autoriser l'appareil photo dans Réglages » s'il est refusé) et
/// « Choisir dans Photos », dont le sélecteur du système ne demande aucune autorisation. L'ajout se fait dans une `Task` : il ne
/// bloque rien, la saisie et le minuteur de repos continuent.
struct AddPhotoMenu<Label: View>: View {
    let model: SessionPhotosModel
    let cameraState: CameraAccess.State
    @ViewBuilder let label: () -> Label
    @State private var showsCamera = false
    @State private var showsPicker = false
    @State private var selection: [PhotosPickerItem] = []
    @Environment(\.openURL) private var openURL

    var body: some View {
        Menu {
            cameraItem
            Button(PhotoText.chooseFromLibrary, systemImage: "photo.on.rectangle") { showsPicker = true }
        } label: {
            label()
        }
        .photosPicker(isPresented: $showsPicker, selection: $selection, maxSelectionCount: max(1, model.remainingSlots),
                      matching: .images)
        .onChange(of: selection) { _, items in importItems(items) }
        .cameraCover(isPresented: $showsCamera) { data in Task { await model.add([data]) } }
    }

    @ViewBuilder
    private var cameraItem: some View {
        switch cameraState {
        case .available:
            Button(PhotoText.takePhoto, systemImage: "camera") { showsCamera = true }
        case .denied:
            Button(PhotoText.allowCamera, systemImage: "gearshape") { openSettings() }
        case .unavailable:
            EmptyView()
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        #endif
    }

    /// Charge les images choisies puis les passe au modèle, qui garde les premières dans la limite. Une image qui ne se charge pas
    /// part vide : le modèle la signale comme illisible.
    private func importItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        selection = []
        Task {
            var images: [Data] = []
            for item in items {
                images.append((try? await item.loadTransferable(type: Data.self)) ?? Data())
            }
            await model.add(images)
        }
    }
}

private struct CameraStateTracking: ViewModifier {
    @Binding var state: CameraAccess.State
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { state = CameraAccess.current() }
            // De retour de Réglages, l'autorisation a pu changer.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { state = CameraAccess.current() }
            }
    }
}

extension View {
    /// Tient `state` à jour : à l'apparition et au retour dans l'app.
    func trackingCameraState(_ state: Binding<CameraAccess.State>) -> some View {
        modifier(CameraStateTracking(state: state))
    }
}
