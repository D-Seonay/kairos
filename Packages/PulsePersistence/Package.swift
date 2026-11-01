// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulsePersistence",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PulsePersistence", targets: ["PulsePersistence"])
    ],
    dependencies: [
        .package(path: "../PulseDomain")
    ],
    targets: [
        .target(
            name: "PulsePersistence",
            dependencies: ["PulseDomain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulsePersistenceTests",
            dependencies: ["PulsePersistence"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
