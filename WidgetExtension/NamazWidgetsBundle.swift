import SwiftUI
import WidgetKit
import NamazWidgets

/// Widget uzantısının giriş noktası.
///
/// Uzantı hedefleri Swift Package olarak derlenemiyor; bu yüzden widget'ların tamamı
/// `NamazWidgets` paketinde duruyor ve CI'da doğrulanıyor. Burada yalnızca `@main`
/// bildirimi var — Mac olmadan derlenemeyen tek satır bu olsun diye.
@main
struct NamazWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        PrayerLockScreenWidget()
    }
}
