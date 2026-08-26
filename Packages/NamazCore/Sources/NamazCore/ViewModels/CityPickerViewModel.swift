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
    public var query: String = "" {
        didSet { if query != oldValue { scheduleSearch() } }
    }

    private let search: CitySearching
    private let debounce: Duration
    private var searchTask: Task<Void, Never>?

    /// `debounce` testlerde sıfıra çekilebilsin diye enjekte ediliyor — testin 300 ms
    /// beklemesi gereksiz yavaşlık olurdu.
    public init(search: CitySearching, debounce: Duration = .milliseconds(300)) {
        self.search = search
        self.debounce = debounce
    }

    deinit { searchTask?.cancel() }

    /// Her tuş vuruşunda arama yapmıyoruz. İki sebep: `CLGeocoder` uygulama başına hız
    /// sınırlı ve sınıra takılınca bir süre hiç cevap vermiyor; ayrıca yazma sürerken gelen
    /// sonuçlar zaten anında eskiyor.
    private func scheduleSearch() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            state = .empty
            return
        }

        state = .searching
        searchTask = Task { [debounce, search] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            do {
                let results = try await search.search(trimmed)
                guard !Task.isCancelled else { return }
                state = results.isEmpty ? .noResults : .results(results)
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed
            }
        }
    }

    /// Testlerin bekleyen aramayı deterministik biçimde tamamlayabilmesi için.
    public func waitForPendingSearch() async {
        await searchTask?.value
    }
}
