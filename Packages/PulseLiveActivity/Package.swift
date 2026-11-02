// swift-tools-version: 6.2
import PackageDescription

/// La Live Activity de séance, partagée entre l'app et `PulseWidgets` : ActivityKit et AppIntents, iOS seulement.
let package = Package(
    name: "PulseLiveActivity",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "PulseLiveActivity", targets: ["PulseLiveActivity"])
    ],
    targets: [
        .target(
            name: "PulseLiveActivity",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
