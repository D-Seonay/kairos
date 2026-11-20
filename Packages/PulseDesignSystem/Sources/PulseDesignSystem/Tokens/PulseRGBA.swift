import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Une couleur sRGB en composantes, comparable et testable sans passer par `Color`.
public struct PulseRGBA: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(hex: UInt32, opacity: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.opacity = opacity
    }
}

public extension Color {
    init(_ rgba: PulseRGBA) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.opacity)
    }
}

/// Une couleur à deux tirages : un pour l'apparence claire, un pour la sombre.
public struct PulseTone: Equatable, Sendable {
    public let light: PulseRGBA
    public let dark: PulseRGBA

    public init(light: PulseRGBA, dark: PulseRGBA) {
        self.light = light
        self.dark = dark
    }
}

public extension Color {
    /// Une couleur qui suit l'apparence : `light` en clair, `dark` en sombre. Résolue par SwiftUI, y compris dans un `Canvas`
    /// et dans les widgets.
    init(light: PulseRGBA, dark: PulseRGBA) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let rgba = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.opacity)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let rgba = isDark ? dark : light
            return NSColor(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.opacity)
        })
        #endif
    }

    init(_ tone: PulseTone) {
        self.init(light: tone.light, dark: tone.dark)
    }
}
