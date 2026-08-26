// swift-tools-version:5.10
import PackageDescription

// Uygulamanın servis katmanı: konum, depo (repository) ve view model'ler.
//
// PrayerKit'ten neden ayrı: PrayerKit saf hesaplama — sıfır sistem bağımlılığı, widget
// süreci dahil her yerden çağrılabilir. NamazCore ise CoreLocation gibi sistem servislerine
// dokunuyor. İkisini ayrı tutmak, widget'ın CoreLocation'ı linklemek zorunda kalmamasını
// sağlıyor ve hesaplama katmanını test ederken sistem izinleri devreye girmiyor.
//
// macOS platformu, Mac'te `swift test` (ve GitHub Actions macOS koşucusunda CI) çalışabilsin
// diye ekli. CoreLocation macOS'ta da var; iOS'a özgü SwiftUI görünümleri ayrı bir hedefe
// gelecek ve iOS için `xcodebuild` ile derlenecek.
let package = Package(
    name: "NamazCore",
    defaultLocalization: "tr",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "NamazCore", targets: ["NamazCore"])
    ],
    dependencies: [
        .package(path: "../PrayerKit")
    ],
    targets: [
        .target(
            name: "NamazCore",
            dependencies: ["PrayerKit"],
            path: "Sources/NamazCore"
        ),
        .testTarget(
            name: "NamazCoreTests",
            dependencies: ["NamazCore", "PrayerKit"],
            path: "Tests/NamazCoreTests"
        )
    ]
)
