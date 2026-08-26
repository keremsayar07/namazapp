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
    public static func fromDevice(
        _ snapshot: LocationSnapshot,
        timeZone: TimeZone = .current,
        fallbackName: String
    ) -> SavedLocation {
        SavedLocation(
            id: "device",
            name: snapshot.placeName ?? fallbackName,
            coordinate: snapshot.coordinate(timeZone: timeZone),
            source: .device
        )
    }
}
