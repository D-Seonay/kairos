import SwiftUI
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

/// L'appareil photo du système (`UIImagePickerController`). Rend l'image prise, ou `nil` si on annule : l'encodage JPEG de
/// l'original (12 Mpx) se fait plus tard, hors de l'acteur principal. La photo n'est pas enregistrée dans Photos : Pulse en garde
/// seul une copie réduite.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

/// L'encodage d'une photo prise, hors de l'acteur principal.
enum CameraEncoding {
    /// Le JPEG de l'image ; il garde l'orientation, que le service corrige à la lecture.
    @concurrent
    static func jpeg(_ image: UIImage) async -> Data? {
        image.jpegData(compressionQuality: 0.9)
    }
}
#endif

extension View {
    /// Présente l'appareil photo en plein écran. `onCapture` reçoit un chargeur qui encode la photo prise hors de l'acteur
    /// principal (pour `SessionPhotosModel.add(loading:)`). `onAppear` et `onDisappear` suivent l'appareil photo à l'écran : la
    /// section Photos de corps le compte parmi ses écrans, sinon le plein écran, qui fait disparaître la liste en dessous, la
    /// reverrouillerait. Sur Mac (les tests), l'appareil photo n'existe pas : rien ne s'affiche.
    @ViewBuilder
    func cameraCover(isPresented: Binding<Bool>, onAppear: @escaping () -> Void = {}, onDisappear: @escaping () -> Void = {},
                     onCapture: @escaping (@escaping @Sendable () async -> Data?) -> Void) -> some View {
        #if canImport(UIKit)
        fullScreenCover(isPresented: isPresented) {
            CameraPicker { image in
                isPresented.wrappedValue = false
                if let image { onCapture { await CameraEncoding.jpeg(image) } }
            }
            .ignoresSafeArea()
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
        }
        #else
        self
        #endif
    }
}
