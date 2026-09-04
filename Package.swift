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
    ],
    // Pin the Swift 5 language mode: the codebase uses pre-concurrency patterns
    // that are warnings in Swift 5 but hard errors under Swift 6 (some CI
    // toolchains default to Swift 6 mode even for a 5.9 tools-version).
    swiftLanguageVersions: [.v5]
)
