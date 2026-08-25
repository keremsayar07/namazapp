import Foundation
@testable import PrayerKit

/// Diyanet-verified accuracy fixtures — **intentionally empty.**
///
/// This is where İstanbul/Ankara/Gaziantep reference times (and the ±1 dakika tolerance tests
/// that consume them) belong once we have data with a citable, primary Diyanet source. See
/// `VERIFICATION_NEEDED.md` for exactly what's needed and why it isn't here yet: automated
/// access to `namazvakitleri.diyanet.gov.tr` is blocked by that site's `robots.txt`, and the
/// official `awqatsalah.diyanet.gov.tr` API requires developer credentials we don't have.
///
/// Every fixture added here must carry: şehir, tarih, kullanılan hesaplama yöntemi, beklenen
/// namaz vakitleri, ve Diyanet referansı (kaynak URL veya API yanıtı). No estimated or
/// AI-recalled figure should ever be added to this file — see the project's explicit
/// instruction not to fabricate reference data.
struct DiyanetReferenceFixture {
    let city: String
    let coordinate: Coordinate
    let date: Date
    let method: CalculationMethod
    let expected: [Prayer: Date]
    /// Where this expected data came from — a URL, an API response, or a specific official
    /// document. Required for every fixture; never left as a placeholder.
    let diyanetSource: String
}

/// Populate once VERIFICATION_NEEDED.md's data need is resolved.
let diyanetReferenceFixtures: [DiyanetReferenceFixture] = []
