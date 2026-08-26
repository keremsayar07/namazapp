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
        .library(name: "PrayerKit", targets: ["PrayerKit"]),
        // Diyanet referans verisiyle karşılaştırma raporu üreten geliştirme aracı.
        // Uygulamaya dahil edilmez; yalnızca CI'da çalışır.
        .executable(name: "prayerkit-calibrate", targets: ["PrayerKitCalibration"]),
        // Diyanet ayna arşivinden hicri düzeltme tablosunu üreten geliştirme aracı.
        // Uygulamaya dahil edilmez; yalnızca CI'da çalışır.
        .executable(name: "prayerkit-hijri-table", targets: ["PrayerKitHijriTable"])
    ],
    targets: [
        .target(
            name: "PrayerKit",
            path: "Sources/PrayerKit"
        ),
        .executableTarget(
            name: "PrayerKitCalibration",
            dependencies: ["PrayerKit"],
            path: "Sources/PrayerKitCalibration"
        ),
        .executableTarget(
            name: "PrayerKitHijriTable",
            dependencies: ["PrayerKit"],
            path: "Sources/PrayerKitHijriTable"
        ),
        .testTarget(
            name: "PrayerKitTests",
            dependencies: ["PrayerKit"],
            path: "Tests/PrayerKitTests"
        )
    ]
)
