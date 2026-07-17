// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FusionStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FusionStudio", targets: ["FusionStudio"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FusionStudio",
            path: "FusionStudio",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)