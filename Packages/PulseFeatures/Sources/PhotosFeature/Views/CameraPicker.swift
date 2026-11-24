import SwiftUI
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

/// L'appareil photo du système (`UIImagePickerController`). Rend les octets JPEG de la photo prise, ou `nil` si on annule. La
/// photo n'est pas enregistrée dans Photos : Pulse en garde seul une copie réduite.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (Data?) -> Void

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
        private let onFinish: (Data?) -> Void

        init(onFinish: @escaping (Data?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            // Le JPEG garde l'orientation : le service la corrige à la lecture.
            onFinish(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
#endif

extension View {
    /// Présente l'appareil photo en plein écran. Sur Mac (les tests), l'appareil photo n'existe pas : rien ne s'affiche.
    @ViewBuilder
    func cameraCover(isPresented: Binding<Bool>, onCapture: @escaping (Data) -> Void) -> some View {
        #if canImport(UIKit)
        fullScreenCover(isPresented: isPresented) {
            CameraPicker { data in
                isPresented.wrappedValue = false
                if let data { onCapture(data) }
            }
            .ignoresSafeArea()
        }
        #else
        self
        #endif
    }
}
