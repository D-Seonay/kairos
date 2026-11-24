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
        .library(name: "NightFeature", targets: ["NightFeature"]),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
        .library(name: "PhotosFeature", targets: ["PhotosFeature"]),
        .library(name: "PlanningFeature", targets: ["PlanningFeature"]),
        .library(name: "ProfileFeature", targets: ["ProfileFeature"]),
        .library(name: "RunFeature", targets: ["RunFeature"]),
        .library(name: "StatsFeature", targets: ["StatsFeature"]),
        .library(name: "SupplementsFeature", targets: ["SupplementsFeature"]),
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
            dependencies: ["PulseServices", "TrainFeature", "SupplementsFeature", "PhotosFeature", domain, recoveryEngine, content,
                           designSystem],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "NightFeature",
            dependencies: ["PulseServices", designSystem, domain],
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
            name: "PhotosFeature",
            dependencies: ["PulseServices", designSystem, domain],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PlanningFeature",
            dependencies: ["PulseServices", "TrainFeature", "RunFeature", "PhotosFeature", designSystem, domain, content],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "ProfileFeature",
            dependencies: ["PulseServices", "StatsFeature", "SupplementsFeature", "TrainFeature", "PhotosFeature", designSystem, domain,
                           recoveryEngine, content],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "RunFeature",
            dependencies: ["PulseServices", "PhotosFeature", designSystem, domain],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "StatsFeature",
            dependencies: ["PulseServices", "TrainFeature", "NightFeature", designSystem, domain, recoveryEngine, content],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SupplementsFeature",
            dependencies: ["PulseServices", designSystem, domain],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "TodayFeature",
            dependencies: ["PulseServices", "CheckInFeature", "SupplementsFeature", "NightFeature", designSystem, domain, recoveryEngine,
                           content],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "TrainFeature",
            dependencies: ["PulseServices", "PhotosFeature", domain, recoveryEngine, content, designSystem],
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
            dependencies: ["LiveSessionFeature", "TrainFeature", "PhotosFeature", "PulseServices", designSystem, domain, recoveryEngine,
                           content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "NightFeatureTests",
            dependencies: ["NightFeature", "PulseServices", domain],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: ["OnboardingFeature", "PulseServices", "CheckInFeature", domain, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PhotosFeatureTests",
            dependencies: ["PhotosFeature", "PulseServices", domain],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PlanningFeatureTests",
            dependencies: ["PlanningFeature", "TrainFeature", "PhotosFeature", "PulseServices", domain, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ProfileFeatureTests",
            dependencies: ["ProfileFeature", "PulseServices", designSystem, domain, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "RunFeatureTests",
            dependencies: ["RunFeature", "PhotosFeature", "PulseServices", designSystem, domain],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StatsFeatureTests",
            dependencies: ["StatsFeature", "PulseServices", designSystem, domain, content],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SupplementsFeatureTests",
            dependencies: ["SupplementsFeature", "PulseServices", domain],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TodayFeatureTests",
            dependencies: ["TodayFeature", "PulseServices", "CheckInFeature", domain, recoveryEngine, content, designSystem],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TrainFeatureTests",
            dependencies: ["TrainFeature", "PhotosFeature", "PulseServices", domain, content, designSystem],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "WidgetFeatureTests",
            dependencies: ["WidgetFeature", domain],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
