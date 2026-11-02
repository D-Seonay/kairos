// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseRecoveryEngine",
    defaultLocalization: "fr",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PulseRecoveryEngine", targets: ["PulseRecoveryEngine"])
    ],
    dependencies: [
        .package(path: "../PulseDomain")
    ],
    targets: [
        .target(
            name: "PulseRecoveryEngine",
            dependencies: ["PulseDomain"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseRecoveryEngineTests",
            dependencies: ["PulseRecoveryEngine"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
