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
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .process("Resources/exercises.json"),
                .process("Resources/hevy-exercises.json"),
                .process("Resources/programs.json"),
                .copy("Resources/Programs")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseContentTests",
            dependencies: ["PulseContent"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
