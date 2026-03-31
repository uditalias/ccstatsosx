// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CCStatsOSX",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CCStatsOSX",
            path: "CCStatsOSX",
            exclude: ["Info.plist"]
        )
    ]
)
