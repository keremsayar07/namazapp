import Foundation

/// Pusuladan gelen tek bir okuma.
public struct HeadingSnapshot: Sendable, Hashable {
    /// Cihazın üst kenarının **gerçek** kuzeye göre açısı, 0..<360.
    ///
    /// Manyetik kuzey değil: kıble açısı coğrafi bir yön, manyetik sapma (deklinasyon)
    /// Türkiye'de bile 5-7 dereceyi buluyor ve bu, birkaç bin kilometre ötede yüzlerce
    /// kilometrelik bir kaymaya karşılık geliyor.
    public var trueHeading: Double

    /// Okumanın sapma payı, derece. Negatifse okuma geçersiz — CoreLocation henüz
    /// kalibre olmamış demektir.
    public var accuracy: Double

    public init(trueHeading: Double, accuracy: Double) {
        self.trueHeading = trueHeading
        self.accuracy = accuracy
    }

    public var isValid: Bool { accuracy >= 0 }

    /// Bu eşiğin üstünde kullanıcıya "pusulanı kalibre et" demek gerekiyor.
    ///
    /// 15°, telefonun manyetometresinin iyi koşullarda verdiği ±5-10°'lik tipik hatanın
    /// belirgin biçimde üstünde. Daha düşük bir eşik uyarıyı sürekli gösterir ve
    /// anlamsızlaştırırdı.
    public static let poorAccuracyThreshold: Double = 15

    public var isAccurate: Bool { isValid && accuracy <= Self.poorAccuracyThreshold }
}

/// Pusula kaynağı. Protokol arkasında, çünkü testte manyetometre yok — ve simülatörde de.
public protocol HeadingProviding: Sendable {
    /// Cihazda pusula donanımı var mı. iPad'lerin bir kısmında ve simülatörde yok.
    var isAvailable: Bool { get }

    /// Okuma akışı. Akışı tüketen görev iptal edilince donanım da durur; ekran
    /// kapandığında manyetometrenin çalışmaya devam etmemesi için bu şart.
    func headings() -> AsyncStream<HeadingSnapshot>
}

/// Önizleme ve test için. Verilen okumaları sırayla yayınlar.
public struct StubHeadingService: HeadingProviding {
    public let isAvailable: Bool
    private let snapshots: [HeadingSnapshot]

    public init(isAvailable: Bool = true, snapshots: [HeadingSnapshot] = []) {
        self.isAvailable = isAvailable
        self.snapshots = snapshots
    }

    public func headings() -> AsyncStream<HeadingSnapshot> {
        AsyncStream { continuation in
            for snapshot in snapshots {
                continuation.yield(snapshot)
            }
            continuation.finish()
        }
    }
}
