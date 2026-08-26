import CoreLocation
import Foundation

/// `CLGeocoder` ile şehir arama.
///
/// **Neden gömülü şehir listesi yok:** 81 il ve ~970 ilçenin koordinatlarını uygulamaya
/// gömmek, hem doğrulanması gereken bir veri yığını (ve bizim kuralımız doğrulanmamış veri
/// kullanmamak) hem de yurt dışındaki kullanıcıyı dışarıda bırakan bir çözüm olurdu.
/// `CLGeocoder` Apple'ın kendi servisi: dünyanın her yerini biliyor, saat dilimini de
/// veriyor, üçüncü taraf bağımlılık gerektirmiyor.
///
/// **Kota:** `CLGeocoder` uygulama başına hız sınırlı. Bu yüzden çağıran taraf her tuş
/// vuruşunda değil, yazma durduktan sonra arıyor (bkz. `CityPickerViewModel`) ve aynı anda
/// yalnızca bir istek açık tutuluyor.
public final class GeocoderCitySearch: CitySearching, @unchecked Sendable {

    private let geocoder = CLGeocoder()

    public init() {}

    public func search(_ query: String) async throws -> [CityCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        // Önceki arama hâlâ sürüyorsa iptal et: kullanıcı yazmaya devam ettiyse eski
        // sorgunun sonucu zaten işe yaramaz ve kotayı boşuna harcar.
        geocoder.cancelGeocode()

        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.geocodeAddressString(trimmed)
        } catch let error as CLError where error.code == .geocodeFoundNoResult {
            return []
        } catch let error as CLError where error.code == .geocodeCanceled {
            // İptal, hata değil — yeni bir arama başladı demektir.
            return []
        } catch {
            throw CitySearchError.unavailable
        }

        var seen = Set<String>()
        return placemarks.compactMap(Self.candidate(from:)).filter { seen.insert($0.id).inserted }
    }

    private static func candidate(from placemark: CLPlacemark) -> CityCandidate? {
        guard let location = placemark.location else { return nil }

        // İlçe (locality) varsa onu tercih ediyoruz; yoksa il, o da yoksa yerin kendi adı.
        let name = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.name
        guard let name, !name.isEmpty else { return nil }

        // Bağlam satırı: aynı adı taşıyan yerleri ayırt etmek için. "Merkez" diye üç sonuç
        // gelirse kullanıcı hangisinin hangi il olduğunu görebilmeli.
        let context = [placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .filter { $0 != name && !$0.isEmpty }
        let region = context.joined(separator: ", ")

        // Saat dilimi gelmezse aday kullanılamaz: yanlış saat diliminde hesaplanan vakit,
        // vakit göstermemekten daha kötü.
        guard let timeZone = placemark.timeZone else { return nil }

        return CityCandidate(
            name: name,
            region: region,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timeZoneIdentifier: timeZone.identifier
        )
    }
}
