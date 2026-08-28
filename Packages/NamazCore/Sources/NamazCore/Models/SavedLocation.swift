import Foundation
import PrayerKit

/// Kullanıcının vakit gösterilmesini istediği yer.
///
/// İki kaynağı var ve ayrımı önemli: cihazın anlık konumu her açılışta değişebilir, elle
/// seçilen şehir ise sabittir. Elle seçimde saat dilimi şehirle birlikte saklanıyor, çünkü
/// kullanıcı yurt dışındayken memleketinin vaktine bakmak isteyebilir — o durumda cihazın
/// saat dilimini kullanmak yanlış olurdu.
public struct SavedLocation: Codable, Sendable, Hashable, Identifiable {

    public enum Source: String, Codable, Sendable, Hashable {
        /// Cihazın GPS konumu. Saat dilimi cihazdan alınır.
        case device
        /// Kullanıcının listeden seçtiği şehir. Saat dilimi kayıtla birlikte gelir.
        case manual
    }

    public var id: String
    public var name: String
    public var coordinate: Coordinate
    public var source: Source

    public init(id: String = UUID().uuidString, name: String, coordinate: Coordinate, source: Source) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.source = source
    }

    /// Cihaz konumundan üretir. Kimliği sabit tutuluyor: cihaz konumu tek bir kayıttır,
    /// her okumada yeni bir satır oluşmaz.
    ///
    /// **Koordinat kasten yuvarlanıyor.** Cihazdan gelen okuma kalıcı olarak diske yazılıyor
    /// (widget'ın okuyabilmesi için) ve orada duran her ondalık basamak, telefona erişen
    /// birinin öğrendiği bilgi demek. Vakit hesabı için gereken hassasiyet bundan çok daha
    /// düşük: `LocationPrivacy.decimals` basamak yaklaşık 1 km'ye denk geliyor ve konum
    /// servisinden zaten `kCLLocationAccuracyKilometer` istiyoruz — yani atılan basamaklar
    /// ölçümün kendi hata payının içinde, gerçek bir bilgi taşımıyorlar.
    ///
    /// Elle seçilen şehirlere uygulanmıyor: onlar zaten şehir merkezinin herkese açık
    /// koordinatı, kullanıcının nerede olduğunu söylemiyorlar.
    public static func fromDevice(
        _ snapshot: LocationSnapshot,
        timeZone: TimeZone = .current,
        fallbackName: String
    ) -> SavedLocation {
        SavedLocation(
            id: "device",
            name: snapshot.placeName ?? fallbackName,
            coordinate: LocationPrivacy.coarsened(snapshot.coordinate(timeZone: timeZone)),
            source: .device
        )
    }
}

/// Cihaz konumunun diske yazılmadan önce geçtiği tek nokta.
public enum LocationPrivacy {

    /// İki ondalık basamak ≈ 1,1 km. Enlemde her yerde, boylamda ekvatorda böyle; kutuplara
    /// gidildikçe daha da küçülüyor, yani hassasiyet hiçbir enlemde bunun üstüne çıkmıyor.
    ///
    /// Vakitlere etkisi: 1 km kuzey-güney kayması güneşin doğuş/batışını saniyeler
    /// mertebesinde değiştiriyor, kıble açısını ise 0,05 dereceden az. Telefon pusulasının
    /// hata payı bunun onlarca katı.
    public static let decimals = 2

    public static func coarsened(_ coordinate: Coordinate) -> Coordinate {
        Coordinate(
            latitude: snap(coordinate.latitude, to: decimals),
            longitude: snap(coordinate.longitude, to: decimals),
            timeZoneIdentifier: coordinate.timeZoneIdentifier
        )
    }

    /// Adı bilerek `round` değil: Foundation'ın genel `round` fonksiyonuyla aynı adı
    /// taşıyan bir üye, okuyanı hangisinin çağrıldığı konusunda tereddüde düşürür.
    private static func snap(_ value: Double, to decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (value * factor).rounded() / factor
    }
}
