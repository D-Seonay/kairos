// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseHealth",
    defaultLocalization: "fr",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "PulseHealth", targets: ["PulseHealth"])
    ],
    dependencies: [
        .package(path: "../PulseDomain")
    ],
    targets: [
        .target(
            name: "PulseHealth",
            dependencies: ["PulseDomain"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseHealthTests",
            dependencies: ["PulseHealth"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
