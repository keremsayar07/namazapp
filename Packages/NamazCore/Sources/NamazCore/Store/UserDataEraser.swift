import Foundation

/// "Tüm verilerimi sil".
///
/// **Neden var.** Uygulamanın hesabı yok, sunucusu yok, veriyi kimseyle paylaşmıyor — yani
/// silinecek uzak bir kopya da yok. Ama cihazdaki veri kullanıcının dini pratiğini ve özel
/// notlarını taşıyor. Telefonu devretmeden, bir başkasına vermeden ya da sadece baştan
/// başlamak istediğinde bunu tek yerden yapabilmesi gerekiyor. Uygulamayı silmek de aynı işi
/// görür ama kullanıcı bunu bilmek zorunda değil ve çoğu zaman uygulamayı tutup veriyi
/// bırakmak istiyor.
///
/// **Neden ayrı bir tip.** Silme, dosya deposunu da tercihleri de bilmek zorunda; bunu bir
/// görünüm modelinin içine koymak, bir gün yeni bir aracı listeye eklemeyi unutmak demekti.
/// Burada tek sorumluluk var ve testi `UserDataFile.allCases` üzerinden yürüyor: yeni bir
/// dosya eklenip listeye yazılmazsa test düşüyor.
public struct UserDataEraser: Sendable {

    private let store: FileStoring
    private let preferences: Preferences

    public init(store: FileStoring, preferences: Preferences = Preferences()) {
        self.store = store
        self.preferences = preferences
    }

    /// Siler ve silinen dosya sayısını döndürür.
    ///
    /// Dosya yoksa da sayılıyor: çağıranın ilgilendiği şey "kaç dosya kaldı" değil, "liste
    /// eksiksiz yürütüldü mü". Var olmayan bir dosyayı silmek zaten sorunsuz.
    @discardableResult
    public func eraseAll() async -> Int {
        for file in UserDataFile.allCases {
            await store.delete(file.rawValue)
        }
        preferences.removeAll()
        Diagnostics.log(.userDataDeleted(fileCount: UserDataFile.allCases.count))
        return UserDataFile.allCases.count
    }
}
