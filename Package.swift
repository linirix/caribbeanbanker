// swift-tools-version: 5.9
import PackageDescription

let coreSources = [
    "Sources/CentralBanker/Advisor.swift",
    "Sources/CentralBanker/BalanceHarness.swift",
    "Sources/CentralBanker/Cabinet.swift",
    "Sources/CentralBanker/CLIOptions.swift",
    "Sources/CentralBanker/Commands.swift",
    "Sources/CentralBanker/Communication.swift",
    "Sources/CentralBanker/CrisisMeasures.swift",
    "Sources/CentralBanker/Difficulty.swift",
    "Sources/CentralBanker/Display.swift",
    "Sources/CentralBanker/Economy.swift",
    "Sources/CentralBanker/Events.swift",
    "Sources/CentralBanker/ExternalEnvironment.swift",
    "Sources/CentralBanker/Forecasting.swift",
    "Sources/CentralBanker/GameConfig.swift",
    "Sources/CentralBanker/GameLength.swift",
    "Sources/CentralBanker/GameSession.swift",
    "Sources/CentralBanker/ModelParameters.swift",
    "Sources/CentralBanker/OpeningConditions.swift",
    "Sources/CentralBanker/Presentation.swift",
    "Sources/CentralBanker/QuarterReport.swift",
    "Sources/CentralBanker/Random.swift",
    "Sources/CentralBanker/SaveLoad.swift",
    "Sources/CentralBanker/Scenario.swift",
    "Sources/CentralBanker/ScoreCard.swift",
    "Sources/CentralBanker/SessionLog.swift",
    "Sources/CentralBanker/TerminalApp.swift"
]

let package = Package(
    name: "CentralBanker",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "CentralBankerCore",
            targets: ["CentralBankerCore"]
        ),
        .executable(
            name: "CentralBanker",
            targets: ["CentralBanker"]
        )
    ],
    targets: [
        .target(
            name: "CentralBankerCore",
            path: ".",
            exclude: [
                ".github",
                "CHANGELOG.md",
                "PLAYER_GUIDE.md",
                "VERSION",
                "dist",
                "README.md",
                "scripts",
                "Sources/CentralBankerApp",
                "Tests",
                "run.sh"
            ],
            sources: coreSources,
            resources: [
                .copy("Config")
            ]
        ),
        .executableTarget(
            name: "CentralBanker",
            dependencies: ["CentralBankerCore"],
            path: "Sources/CentralBankerApp"
        ),
        .testTarget(
            name: "CentralBankerTests",
            dependencies: ["CentralBankerCore"],
            path: "Tests/CentralBankerTests"
        ),
    ]
)
