// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseDomain",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PulseDomain", targets: ["PulseDomain"]),
    ],
    targets: [
        .target(
            name: "PulseDomain",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseDomainTests",
            dependencies: ["PulseDomain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
