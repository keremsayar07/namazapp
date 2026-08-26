import CoreLocation
import Foundation

#if os(iOS)

/// `HeadingProviding`'in CoreLocation ile gerçek uygulaması.
///
/// Üç ayrıntı bu sınıfın var olma sebebi:
///
/// 1. **`trueHeading` bedava değil.** Gerçek kuzey, manyetik okumaya deklinasyon
///    düzeltmesi uygulanarak bulunuyor ve o düzeltme konuma bağlı. Apple'ın belgesi açık:
///    konum güncellemeleri çalışmıyorsa `trueHeading` −1 döner. Bu yüzden
///    `startUpdatingHeading()` ile birlikte `startUpdatingLocation()` da çağrılıyor.
///    Doğruluk kilometre mertebesine çekildi — deklinasyon için fazlasıyla yeterli, pil
///    için önemli fark.
/// 2. **Akış bitince donanım durmalı.** `onTermination` ile hem pusula hem konum
///    güncellemeleri kapanıyor; ekrandan çıkıldığında manyetometre çalışmaya devam ederse
///    pil sessizce erir.
/// 3. **Kalibrasyon arayüzü sistemin işi.** `shouldDisplayHeadingCalibration` true dönüyor:
///    gerekirse iOS kendi "sekiz çiz" ekranını gösteriyor, biz taklidini yazmıyoruz.
public final class CoreLocationHeadingService: NSObject, HeadingProviding, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let box = ContinuationBox()

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        // Cihaz ne kadar dönerse dönsün her değişimi bildir: ibre pürüzsüz aksın.
        // Yumuşatma view model'de, çünkü orada test edilebiliyor.
        manager.headingFilter = kCLHeadingFilterNone
    }

    public var isAvailable: Bool {
        CLLocationManager.headingAvailable()
    }

    public func headings() -> AsyncStream<HeadingSnapshot> {
        AsyncStream { continuation in
            guard CLLocationManager.headingAvailable() else {
                continuation.finish()
                return
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                // CLLocationManager tek bir kuyruktan kullanılsın diye durdurma da
                // ana kuyruğa gönderiliyor.
                Task { @MainActor in
                    self.manager.stopUpdatingHeading()
                    self.manager.stopUpdatingLocation()
                    await self.box.clear()
                }
            }

            Task {
                await self.box.set(continuation)
                await MainActor.run {
                    self.manager.startUpdatingLocation()
                    self.manager.startUpdatingHeading()
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationHeadingService: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let snapshot = HeadingSnapshot(
            trueHeading: newHeading.trueHeading,
            // `headingAccuracy` negatifse okuma geçersiz; konum yoksa `trueHeading` de −1
            // gelir. İkisini tek bir geçersizlik işaretine indirgiyoruz.
            accuracy: newHeading.trueHeading < 0 ? -1 : newHeading.headingAccuracy
        )
        Task { await box.yield(snapshot) }
    }

    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Pusula hatası ölümcül değil: akışı kapatmıyoruz, o an geçerli okuma yok deyip
        // geçiyoruz. Ekran sabit kıble açısını göstermeye devam ediyor.
        Task { await box.yield(HeadingSnapshot(trueHeading: -1, accuracy: -1)) }
    }
}

// MARK: - Akış kutusu

/// Akışın continuation'ını actor korumasında tutar. Delegate geri çağrıları CoreLocation'ın
/// kuyruğundan geliyor, akış başka bir görevde tüketiliyor; ikisi arasındaki tek paylaşılan
/// durum burası.
private actor ContinuationBox {
    private var continuation: AsyncStream<HeadingSnapshot>.Continuation?

    func set(_ continuation: AsyncStream<HeadingSnapshot>.Continuation) {
        // Önceki akış hâlâ açıksa kapat: aynı anda iki tüketici beklenen bir kullanım
        // değil ve yarım kalmış bir akış bırakmak istemiyoruz.
        self.continuation?.finish()
        self.continuation = continuation
    }

    func yield(_ snapshot: HeadingSnapshot) {
        continuation?.yield(snapshot)
    }

    func clear() {
        continuation = nil
    }
}

#else

/// macOS'ta pusula donanımı ve `startUpdatingHeading` API'si yok. Tip yine de var olmalı:
/// `NamazCore` CI'da macOS'a derleniyor ve `Composition` bu adı iki platformda da anıyor.
/// Davranışı dürüst — "pusula yok" diyor, ekran da zaten o duruma hazır.
public final class CoreLocationHeadingService: HeadingProviding, @unchecked Sendable {
    public init() {}

    public var isAvailable: Bool { false }

    public func headings() -> AsyncStream<HeadingSnapshot> {
        AsyncStream { $0.finish() }
    }
}

#endif
