// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseContent",
    defaultLocalization: "fr",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PulseContent", targets: ["PulseContent"])
    ],
    dependencies: [
        .package(path: "../PulseDomain")
    ],
    targets: [
        .target(
            name: "PulseContent",
            dependencies: ["PulseDomain"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseContentTests",
            dependencies: ["PulseContent"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
