// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PrayerKit",
    defaultLocalization: "tr",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PrayerKit", targets: ["PrayerKit"])
    ],
    targets: [
        .target(
            name: "PrayerKit",
            path: "Sources/PrayerKit"
        ),
        .testTarget(
            name: "PrayerKitTests",
            dependencies: ["PrayerKit"],
            path: "Tests/PrayerKitTests"
        )
    ]
)
