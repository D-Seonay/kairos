import Foundation
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Le presse-papiers de l'image sans fond : on la copie, puis on la colle dans l'éditeur de story d'Instagram, où elle devient
/// un sticker posé sur sa propre photo. Partager la même image l'enverrait en fond de story.
@MainActor
public enum ShareCardPasteboard {
    public static func copy(png: Data) {
        #if os(iOS)
        UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
        #endif
    }
}
