import Foundation
import UserNotifications

/// `UNUserNotificationCenter` ile gerçek uygulama.
public struct UserNotificationScheduler: NotificationScheduling {

    /// Bizim kurduğumuz bildirimleri tanımak için ön ek. Sadece bunları siliyoruz ki
    /// ileride başka bir özellik kendi bildirimini kurduğunda onu çöpe atmayalım.
    private static let identifierPrefix = "namaz."

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public var authorization: NotificationAuthorization {
        get async {
            let settings = await center.notificationSettings()
            return Self.map(settings.authorizationStatus)
        }
    }

    @discardableResult
    public func requestAuthorization() async -> NotificationAuthorization {
        let current = await authorization
        guard current == .notDetermined else { return current }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // İzin isteği hata verirse (nadir) reddedilmiş saymak doğru davranış:
            // uygulama bildirimsiz de tam çalışıyor.
            return .denied
        }
        return await authorization
    }

    public func replaceAll(
        with plan: NotificationPlan,
        content: @Sendable (PlannedNotification) -> NotificationContent,
        playsSound: Bool
    ) async {
        await cancelAll()

        for notification in plan.notifications {
            let text = content(notification)
            let payload = UNMutableNotificationContent()
            payload.title = text.title
            payload.body = text.body
            payload.sound = playsSound ? .default : nil
            // Aynı vaktin bildirimleri bildirim merkezinde gruplanmasın diye vakte göre
            // eşik veriyoruz — kullanıcı geçmiş vakitleri tek tek görmek zorunda kalmıyor.
            payload.threadIdentifier = "namaz.prayer.\(notification.prayer.rawValue)"

            // `UNCalendarNotificationTrigger`, `UNTimeIntervalNotificationTrigger` yerine
            // bilinçli: cihaz uykudayken geçen süre, saat dilimi değişimi ve yaz saati
            // geçişleri takvim tetikleyicisinde doğru ele alınıyor.
            var components = Calendar(identifier: .gregorian).dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: notification.fireDate
            )
            components.timeZone = TimeZone.current

            let request = UNNotificationRequest(
                identifier: notification.id,
                content: payload,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            // Tek bir bildirimin kurulamaması diğerlerini engellememeli.
            try? await center.add(request)
        }
    }

    public func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    public func pendingCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.identifier.hasPrefix(Self.identifierPrefix) }.count
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .ephemeral: return .authorized
        case .provisional: return .provisional
        @unknown default: return .denied
        }
    }

    /// Plan dışı tek bildirim — zamanlayıcı için.
    ///
    /// Kimlik `namaz.` ön ekini TAŞIMAMALI; `cancelAll()` o ön ekli her şeyi siliyor ve
    /// vakit bildirimleri uygulama her öne geldiğinde yeniden kuruluyor. Ad alanları
    /// ayrı olduğu sürece ikisi birbirine dokunmuyor.
    public func schedule(identifier: String, at date: Date, title: String, body: String) async {
        let payload = UNMutableNotificationContent()
        payload.title = title
        payload.body = body
        payload.sound = .default

        // Geçmiş bir tarihe bildirim kurulamaz; sessizce vazgeçiyoruz.
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(
            UNNotificationRequest(identifier: identifier, content: payload, trigger: trigger)
        )
    }

    public func cancel(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

}
