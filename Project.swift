import ProjectDescription

let project = Project(
    name: "VideoHelper",
    settings: .settings(
        configurations: [
            .debug(name: "Debug", xcconfig: "./xcconfigs/VideoHelper-Project.xcconfig"),
            .release(name: "Release", xcconfig: "./xcconfigs/VideoHelper-Project.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "VideoHelper",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.androidbroadcast.VideoHelper",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "VideoHelper",
                "LSMinimumSystemVersion": "14.0",
                "NSHumanReadableCopyright": "Copyright © 2025. All rights reserved.",
            ]),
            sources: ["VideoHelper/**/*.swift"],
            resources: [
                "VideoHelper/Assets.xcassets",
                "VideoHelper/Resources/**",
            ],
            entitlements: "VideoHelper/VideoHelper.entitlements",
            dependencies: [],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "./xcconfigs/VideoHelper-App.xcconfig"),
                    .release(name: "Release", xcconfig: "./xcconfigs/VideoHelper-App.xcconfig"),
                ]
            )
        ),
        .target(
            name: "VideoHelperTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.androidbroadcast.VideoHelperTests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["VideoHelperTests/**/*.swift"],
            dependencies: [
                .target(name: "VideoHelper")
            ],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "./xcconfigs/VideoHelper-Tests.xcconfig"),
                    .release(name: "Release", xcconfig: "./xcconfigs/VideoHelper-Tests.xcconfig"),
                ]
            )
        ),
        .target(
            name: "VideoHelperUITests",
            destinations: .macOS,
            product: .uiTests,
            bundleId: "dev.androidbroadcast.VideoHelperUITests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["VideoHelperUITests/**/*.swift"],
            dependencies: [
                .target(name: "VideoHelper")
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "minimal"
                ],
                configurations: [
                    .debug(name: "Debug", xcconfig: "./xcconfigs/VideoHelper-UITests.xcconfig"),
                    .release(name: "Release", xcconfig: "./xcconfigs/VideoHelper-UITests.xcconfig"),
                ]
            )
        ),
    ]
)
