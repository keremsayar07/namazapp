import SwiftUI
import NamazUI

/// Uygulamanın giriş noktası.
///
/// Kasten bu kadar küçük. Bağımlılıkların nasıl kurulduğu `NamazUI` içindeki
/// `Dependencies.live()`'da; sekmelerin ne olduğu `RootTabView`'da. Bu dosyanın bildiği tek
/// şey "uygulama açılınca kök görünümü göster".
///
/// Faydası şu: uygulama hedefi Swift Package Manager paketleri gibi CI'da derlenemiyor
/// (Xcode projesi gerekiyor), dolayısıyla burada ne kadar az kod olursa Mac olmadan
/// doğrulanamayan yüzey o kadar küçük kalıyor.
@main
struct NamazApp: App {

    /// `@State` ile bir kez kuruluyor: `Dependencies.live()` içinde `CLLocationManager` ve
    /// `UNUserNotificationCenter` gibi tekil sistem nesneleri var, her görünüm
    /// güncellemesinde yeniden yaratılmamalılar.
    @State private var dependencies = Dependencies.live()

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
    }
}
