import Foundation
import Observation
import PrayerKit

/// Kıble ekranının durumu.
///
/// Ekranın iki ayrı bilgisi var ve bunları ayırmak önemli: **kıble açısı** konumdan
/// hesaplanan sabit bir gerçek (İstanbul'da yaklaşık 151°, ölçüm gerektirmez), **ibre** ise
/// telefonun o anki yönüne bağlı canlı bir okuma. Pusula bozuk ya da yoksa ilki hâlâ
/// gösterilebilir — kullanıcı açıyı bilirse başka bir pusulayla da kıbleyi bulabilir.
@MainActor
@Observable
public final class QiblaViewModel {

    public enum Availability: Sendable, Hashable {
        /// Konum yok: kıble açısı bile hesaplanamıyor.
        case noLocation
        /// Konum var, pusula donanımı yok. Açı gösteriliyor, ibre yok.
        case noCompass
        /// Pusula var ama henüz geçerli okuma gelmedi (kalibrasyon sürüyor olabilir).
        case waiting
        /// Canlı ibre.
        case live
    }

    /// İbrenin "hizalandı" sayıldığı yarı açı, derece.
    ///
    /// ±3°: elle tutulan bir telefonda daha dar bir aralık ulaşılamaz olurdu, daha genişi
    /// ise anlamsızlaşırdı. Şunu da not etmek gerek — bu, ölçümün *doğru* olduğu anlamına
    /// gelmez; telefon manyetometresinin kendi hatası tipik olarak ±5-10°. Bu yüzden ekran
    /// doğruluk okumasını da gösteriyor ve kötüyken uyarıyor.
    public static let alignmentTolerance: Double = 3

    /// Yeni okumanın yumuşatmadaki ağırlığı. Küçük değer sakin ama tembel bir ibre,
    /// büyük değer titrek bir ibre demek. 0.2 ikisinin arasında duruyor.
    public static let smoothingFactor: Double = 0.2

    public private(set) var location: SavedLocation?
    /// Yumuşatılmış cihaz yönü, 0..<360. Geçerli okuma yoksa `nil`.
    public private(set) var heading: Double?
    /// Son geçerli okumanın sapma payı, derece.
    public private(set) var accuracy: Double?
    public private(set) var isCompassAvailable: Bool

    private let headingService: HeadingProviding
    /// Yumuşatma birim çember üzerinde yapılıyor. Doğrudan derece ortalaması alınsaydı
    /// 359° ile 1° arasındaki geçiş ibreyi çemberin öbür ucuna fırlatırdı.
    ///
    /// Gözlemden muaf: her değişimine zaten `heading` eşlik ediyor, ekranın ayrıca bu ara
    /// değeri izlemesi gereksiz yere yeniden çizim tetiklerdi.
    @ObservationIgnored
    private var smoothed: (x: Double, y: Double)?

    public init(location: SavedLocation?, headingService: HeadingProviding) {
        self.location = location
        self.headingService = headingService
        self.isCompassAvailable = headingService.isAvailable
    }

    // MARK: - Türetilen değerler

    /// Kıble açısı, gerçek kuzeyden saat yönünde. Konumdan hesaplanır, ölçüm gerektirmez.
    public var bearing: Double? {
        location.map { QiblaMath.qiblaBearing(from: $0.coordinate) }
    }

    /// Kâbe'ye kuş uçuşu uzaklık, metre.
    public var distanceMeters: Double? {
        location.map { QiblaMath.distanceToKaaba(from: $0.coordinate) }
    }

    /// Cihazı kaç derece çevirmek gerekiyor. Pozitif: sağa. Okuma yoksa `nil`.
    public var relativeAngle: Double? {
        guard let bearing, let heading else { return nil }
        return QiblaMath.relativeAngle(from: heading, to: bearing)
    }

    public var isAligned: Bool {
        guard let relativeAngle else { return false }
        return abs(relativeAngle) <= Self.alignmentTolerance
    }

    /// Okuma geliyor ama güvenilmeyecek kadar sapmalı. Ekran bunu söylemek zorunda:
    /// sessizce yanlış yön göstermek, hiç yön göstermemekten kötü.
    public var needsCalibration: Bool {
        guard let accuracy else { return false }
        return accuracy > HeadingSnapshot.poorAccuracyThreshold
    }

    public var availability: Availability {
        if location == nil { return .noLocation }
        if !isCompassAvailable { return .noCompass }
        return heading == nil ? .waiting : .live
    }

    // MARK: - Akış

    /// Ekran görünürken çalışır. Görev iptal edildiğinde akış kapanıyor ve donanım duruyor —
    /// SwiftUI'ın `.task`'ı bunu ekran kaybolunca kendiliğinden yapıyor.
    public func start() async {
        isCompassAvailable = headingService.isAvailable
        guard isCompassAvailable else { return }
        for await snapshot in headingService.headings() {
            ingest(snapshot)
        }
    }

    /// Şehir değiştiğinde. Açı ve uzaklık türetilmiş olduğu için başka bir şey yapmak
    /// gerekmiyor — ibre zaten cihaza bağlı, konuma değil.
    public func update(location: SavedLocation?) {
        self.location = location
    }

    /// Tek bir okumayı işler. Akıştan bağımsız olarak `internal` — testler manyetometre
    /// olmadan da bu mantığı çalıştırabilsin diye.
    func ingest(_ snapshot: HeadingSnapshot) {
        guard snapshot.isValid else {
            // Geçersiz okuma son iyi değeri silmiyor: kısa bir bozulmada ibrenin yok olup
            // geri gelmesi, hafifçe kaymasından çok daha rahatsız edici.
            return
        }
        accuracy = snapshot.accuracy

        let radians = snapshot.trueHeading * .pi / 180
        let sample = (x: sin(radians), y: cos(radians))

        if let current = smoothed {
            let a = Self.smoothingFactor
            smoothed = (
                x: current.x * (1 - a) + sample.x * a,
                y: current.y * (1 - a) + sample.y * a
            )
        } else {
            // İlk okuma doğrudan alınıyor: sıfırdan yumuşatmaya başlamak ibreyi kuzeyden
            // gerçek yöne doğru gereksiz bir yolculuğa çıkarırdı.
            smoothed = sample
        }

        guard let smoothed else { return }
        let degrees = atan2(smoothed.x, smoothed.y) * 180 / .pi
        heading = (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
