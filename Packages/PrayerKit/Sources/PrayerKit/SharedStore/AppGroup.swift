import Foundation

/// Uygulama ile widget uzantısının paylaştığı kabın kimliği.
///
/// Tek yerde duruyor: bu dize hem uygulamanın hem uzantının entitlement dosyasında
/// birebir aynı olmak zorunda. Bir harf farkında widget çökmüyor, hata da vermiyor —
/// sadece hiçbir zaman veri bulamıyor. CI'da bu üç yerin eşitliğini denetleyen bir adım var.
///
/// **Bu dosya eskiden `PrayerTimesSnapshot.swift` idi.** Orada, uygulamanın hiçbir yerinden
/// çağrılmayan bir `PrayerTimesSnapshotStore` duruyordu: kullanıcının koordinatlarını
/// paylaşılan kaba, dosya koruma sınıfı hiç belirtilmeden yazan ölü bir kod yolu. Widget
/// verisini `Preferences` üzerinden okuduğu için hiç kullanılmıyordu. Faz 7.6'da kaldırıldı —
/// çağrılmayan kod da saldırı yüzeyidir; bir gün biri onu çağırır.
public enum AppGroup {
    /// Uygulama ve widget hedeflerindeki "App Groups" yetkisiyle ve Apple Developer
    /// portalındaki App ID kaydıyla aynı olmalı.
    public static let identifier = "group.com.keremsayar.namaz"

    /// App Group yetkisi henüz kurulmamışsa `nil`. Çağıranlar bunu ele almak zorunda;
    /// hiçbir yerde zorla açılmıyor (`!`).
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
