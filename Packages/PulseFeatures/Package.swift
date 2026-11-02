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
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
        .library(name: "TodayFeature", targets: ["TodayFeature"]),
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
            name: "WidgetFeature",
            dependencies: [domain, designSystem],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseServicesTests",
            dependencies: ["PulseServices"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CheckInFeatureTests",
            dependencies: ["CheckInFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: ["OnboardingFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TodayFeatureTests",
            dependencies: ["TodayFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "WidgetFeatureTests",
            dependencies: ["WidgetFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
