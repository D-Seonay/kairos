// swift-tools-version: 6.2
import PackageDescription

let domain = Target.Dependency.product(name: "PulseDomain", package: "PulseDomain")
let recoveryEngine = Target.Dependency.product(name: "PulseRecoveryEngine", package: "PulseRecoveryEngine")
let content = Target.Dependency.product(name: "PulseContent", package: "PulseContent")
let designSystem = Target.Dependency.product(name: "PulseDesignSystem", package: "PulseDesignSystem")

let package = Package(
    name: "PulseFeatures",
    defaultLocalization: "fr",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PulseServices", targets: ["PulseServices"]),
        .library(name: "CheckInFeature", targets: ["CheckInFeature"]),
        .library(name: "LiveSessionFeature", targets: ["LiveSessionFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
        .library(name: "TodayFeature", targets: ["TodayFeature"]),
        .library(name: "TrainFeature", targets: ["TrainFeature"]),
        .library(name: "WidgetFeature", targets: ["WidgetFeature"])
    ],
    dependencies: [
        .package(path: "../PulseDomain"),
        .package(path: "../PulseRecoveryEngine"),
        .package(path: "../PulseContent"),
        .package(path: "../PulseDesignSystem")
    ],
    targets: [
        .target(
            name: "PulseServices",
            dependencies: [domain, recoveryEngine, content],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CheckInFeature",
            dependencies: [domain, recoveryEngine, designSystem],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "LiveSessionFeature",
            dependencies: ["PulseServices", "TrainFeature", domain, recoveryEngine, content, designSystem],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "OnboardingFeature",
            dependencies: ["PulseServices", "CheckInFeature", designSystem, domain, content],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "TodayFeature",
            dependencies: ["PulseServices", "CheckInFeature", designSystem, domain, recoveryEngine, content],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "TrainFeature",
            dependencies: ["PulseServices", domain, recoveryEngine, content, designSystem],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "WidgetFeature",
            dependencies: [domain, designSystem],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseServicesTests",
            dependencies: ["PulseServices", domain, recoveryEngine, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CheckInFeatureTests",
            dependencies: ["CheckInFeature", domain],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LiveSessionFeatureTests",
            dependencies: ["LiveSessionFeature", "TrainFeature", "PulseServices", domain, recoveryEngine, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: ["OnboardingFeature", "PulseServices", "CheckInFeature", domain, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TodayFeatureTests",
            dependencies: ["TodayFeature", "PulseServices", "CheckInFeature", domain, recoveryEngine, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TrainFeatureTests",
            dependencies: ["TrainFeature", "PulseServices", domain, content, designSystem],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "WidgetFeatureTests",
            dependencies: ["WidgetFeature", domain],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
