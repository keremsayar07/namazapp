import Foundation
import Observation

/// Şehir seçme ekranının durumu.
@MainActor
@Observable
public final class CityPickerViewModel {

    public enum State: Sendable, Hashable {
        /// Henüz aranacak bir şey yazılmadı.
        case empty
        case searching
        case results([CityCandidate])
        /// Arama çalıştı ama sonuç yok. `noResults`, `failed`'dan ayrı: biri kullanıcının
        /// yazdığıyla ilgili, diğeri sistemle. Ekranda söylenecek şey de farklı.
        case noResults
        case failed
    }

    public private(set) var state: State = .empty

    /// Arama kutusunun metni.
    ///
    /// Burada bilinçli olarak `didSet` YOK. İki sebep: `@Observable` makrosu depolanan
    /// özellikleri hesaplanan özelliklere dönüştürüyor ve özellik gözlemcileriyle birlikte
    /// davranışı belirsiz; ayrıca gözlenen bir değerin yan etkisi olarak arka planda ağ işi
    /// başlatmak, çağrı sırasını okunmaz hâle getiriyor. Arama açıkça tetikleniyor:
    /// görünüm `.onChange(of: model.query) { model.queryChanged() }` diyor.
    public var query: String = ""

    private let search: CitySearching
    private let debounce: Duration
    /// Gözlemlenmesi anlamsız: görünüm bu görevin kimliğiyle değil, `state` ile ilgileniyor.
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    /// `debounce` testlerde sıfıra çekilebilsin diye enjekte ediliyor — testin 300 ms
    /// beklemesi gereksiz yavaşlık olurdu.
    public init(search: CitySearching, debounce: Duration = .milliseconds(300)) {
        self.search = search
        self.debounce = debounce
    }

    // `deinit` içinde görevi iptal etmiyoruz: `deinit` aktör yalıtımının dışında çalışır ve
    // yalıtılmış özelliğe oradan dokunmak derlenmez. Gerek de yok — görev `self`'i zayıf
    // tutuyor, dolayısıyla model yok olduğunda geriye sadece hiçbir şey yapmayan bir görev
    // kalıyor, sızıntı olmuyor.

    /// `query` değiştiğinde görünümün çağırdığı yer.
    ///
    /// Her tuş vuruşunda arama yapmıyoruz. İki sebep: `CLGeocoder` uygulama başına hız
    /// sınırlı ve sınıra takılınca bir süre hiç cevap vermiyor; ayrıca yazma sürerken gelen
    /// sonuçlar zaten anında eskiyor.
    public func queryChanged() {
        scheduleSearch()
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            state = .empty
            return
        }

        state = .searching
        let search = self.search
        let debounce = self.debounce

        // `[weak self]`: kaçan bir closure'da `self`'e örtük erişim derlenmez, ayrıca ekran
        // kapandıysa bekleyen aramanın modeli hayatta tutmasının anlamı yok.
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            do {
                let results = try await search.search(trimmed)
                guard !Task.isCancelled else { return }
                self?.state = results.isEmpty ? .noResults : .results(results)
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed
            }
        }
    }

    /// Testlerin bekleyen aramayı deterministik biçimde tamamlayabilmesi için.
    public func waitForPendingSearch() async {
        await searchTask?.value
    }
}
