// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseDesignSystem",
    defaultLocalization: "fr",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PulseDesignSystem", targets: ["PulseDesignSystem"])
    ],
    dependencies: [
        .package(path: "../PulseDomain")
    ],
    targets: [
        .target(
            name: "PulseDesignSystem",
            dependencies: ["PulseDomain"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseDesignSystemTests",
            dependencies: ["PulseDesignSystem"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
