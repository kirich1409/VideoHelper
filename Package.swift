// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

let package = Package(
    name: "VideoHelper",
    dependencies: [
        // Add Swift package dependencies here if needed in future
        // Example: .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0"),
    ]
)
