// swift-tools-version:5.10
import PackageDescription

// Widget'ın zaman çizelgesi ve görünümleri.
//
// Xcode'daki widget extension target'ı yalnızca `@main` bildirimini içerecek; asıl kod
// burada. Sebep: extension target'ları paket olarak derlenemiyor ama içindeki her şey
// derlenebiliyor. Böylece widget de Mac olmadan CI'da doğrulanıyor.
let package = Package(
    name: "NamazWidgets",
    defaultLocalization: "tr",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "NamazWidgets", targets: ["NamazWidgets"])
    ],
    dependencies: [
        .package(path: "../NamazCore"),
        .package(path: "../PrayerKit")
    ],
    targets: [
        .target(
            name: "NamazWidgets",
            dependencies: ["NamazCore", "PrayerKit"],
            path: "Sources/NamazWidgets",
            resources: [.process("Resources")]
        )
    ]
)
