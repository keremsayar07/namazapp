// swift-tools-version:5.10
import PackageDescription

// SwiftUI görünümleri. iOS'a özgü olduğu için macOS platformu YOK — bu paket
// `swift build` ile değil, iOS hedefine `xcodebuild` ile derleniyor
// (bkz. .github/workflows/namazui-build.yml). Mac olmadan görsel doğrulama yapılamıyor
// ama derleme doğrulaması yapılabiliyor; ayrım bilinçli.
let package = Package(
    name: "NamazUI",
    defaultLocalization: "tr",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "NamazUI", targets: ["NamazUI"])
    ],
    dependencies: [
        .package(path: "../NamazCore"),
        .package(path: "../PrayerKit")
    ],
    targets: [
        .target(
            name: "NamazUI",
            dependencies: ["NamazCore", "PrayerKit"],
            path: "Sources/NamazUI",
            resources: [.process("Resources")]
        )
    ]
)
