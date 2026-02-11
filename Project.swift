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
        // Targets will be defined in later steps
    ]
)
