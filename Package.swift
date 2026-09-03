// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Musim",
    platforms: [.macOS(.v14)],
    dependencies: [
        // In-app auto-update (appcast + EdDSA-signed DMGs served from GitHub Releases).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Musim",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Musim"
        )
    ]
)
