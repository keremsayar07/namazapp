import Foundation

// MARK: - Not defteri

/// Kullanıcının kendi yazdığı bir not.
///
/// Uygulamadaki en hassas veri bu. Bir namaz kaydı kişinin pratiğini gösteriyor; bir not
/// ise doğrudan kendi cümleleri olabilir. Depolama tarafında `FileProtection.complete`
/// altında duruyor (cihaz kilitliyken okunamıyor) ve isteğe bağlı Face ID kilidi var.
public struct Note: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var title: String
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Listede gösterilecek ad. Başlık boşsa gövdenin ilk satırı kullanılıyor —
    /// "Başlıksız" yazan bir liste, kullanıcının notlarını birbirinden ayırt edilemez kılar.
    public var displayTitle: String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstLine, !firstLine.isEmpty else { return nil }
        return String(firstLine.prefix(60))
    }

    public var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct NoteBook: Codable, Sendable, Hashable {
    public var notes: [Note]

    public init(notes: [Note] = []) {
        self.notes = notes
    }

    /// En son düzenlenen üstte. Kullanıcı en çok üzerinde çalıştığı nota dönüyor.
    public var sorted: [Note] {
        notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Başlıkta ve gövdede arar. Türkçe harf katlaması `SearchFolding` üzerinden —
    /// "İSTANBUL" yazan bir notu "istanbul" araması bulmalı, aksi hâlde arama işe yaramaz.
    public func search(_ query: String) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter {
            SearchFolding.contains($0.title, trimmed) || SearchFolding.contains($0.body, trimmed)
        }
    }
}

// MARK: - Zamanlayıcı

/// Geri sayım.
///
/// **Sayaç diye bir şey yok.** iOS'ta arka planda saniye sayan bir zamanlayıcı çalıştırılmaz;
/// uygulama askıya alınır ve sayaç durur. Onun yerine burada tutulan tek şey **bitiş anı**.
/// Kalan süre her bakışta o andan hesaplanıyor. Uygulama kapansa, arka plana geçse, telefon
/// yeniden başlasa bile bozulacak bir şey yok — çünkü bozulabilecek bir sayaç yok.
///
/// Bitişte haber verilmesini de bir yerel bildirim sağlıyor; uygulamanın uyanık olması
/// gerekmiyor.
public struct CountdownTimer: Codable, Sendable, Hashable {
    /// Çalışıyorsa bitiş anı, durmuşsa `nil`.
    public var endsAt: Date?
    /// Seçilen süre. Duraklatma yok; "yeniden başlat" bu değeri kullanıyor.
    public var duration: TimeInterval
    /// Kullanıcının verdiği ad. Boş olabilir.
    public var label: String

    public init(endsAt: Date? = nil, duration: TimeInterval = 600, label: String = "") {
        self.endsAt = endsAt
        self.duration = duration
        self.label = label
    }

    public func isRunning(at now: Date) -> Bool {
        guard let endsAt else { return false }
        return endsAt > now
    }

    /// Süresi dolmuş ama kullanıcı henüz kapatmamış. Ekran "bitti" diyebilsin diye ayrı
    /// bir durum: sıfırlanmış bir zamanlayıcıyla biten bir zamanlayıcı aynı şey değil.
    public func isFinished(at now: Date) -> Bool {
        guard let endsAt else { return false }
        return endsAt <= now
    }

    /// Kalan süre, saniye. Negatife düşmüyor.
    public func remaining(at now: Date) -> TimeInterval {
        guard let endsAt else { return duration }
        return max(0, endsAt.timeIntervalSince(now))
    }

    /// Tamamlanma oranı, 0...1. Süre sıfırsa `nil` — sıfıra bölmek yerine çubuk çizilmiyor.
    public func progress(at now: Date) -> Double? {
        guard duration > 0, endsAt != nil else { return nil }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }

    /// Hazır süreler. Serbest giriş de var ama bu dördü tek dokunuşla erişilebilir olsun.
    public static let presets: [TimeInterval] = [5 * 60, 10 * 60, 15 * 60, 30 * 60]
}
