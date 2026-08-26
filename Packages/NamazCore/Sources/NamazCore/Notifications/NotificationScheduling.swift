import Foundation

/// Bildirim izninin uygulama açısından anlamlı hâli.
public enum NotificationAuthorization: String, Sendable, Hashable {
    case notDetermined
    /// Kullanıcı reddetti. Konum izninde olduğu gibi: sistem bir daha sormaz, tek yol Ayarlar.
    case denied
    case authorized
    /// Kullanıcıya sorulmadan sessizce verilen izin (provisional). Bildirimler doğrudan
    /// bildirim merkezine düşüyor, banner çıkmıyor.
    case provisional

    public var canSchedule: Bool {
        self == .authorized || self == .provisional
    }
}

/// Bir bildirimin ekranda görünecek metni.
///
/// `NamazCore` yerelleştirilmiş metin tutmuyor — o katman servis katmanı. Metni UI paketi
/// kendi kaynak paketinden üretip buraya veriyor.
public struct NotificationContent: Sendable, Hashable {
    public var title: String
    public var body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Planı sisteme kuran katman.
public protocol NotificationScheduling: Sendable {
    var authorization: NotificationAuthorization { get async }
    @discardableResult
    func requestAuthorization() async -> NotificationAuthorization
    /// Bekleyen tüm vakit bildirimlerini silip planı baştan kurar.
    ///
    /// Fark hesaplamak yerine silip yeniden kurmak bilinçli: plan zaten en fazla ~58 kayıt
    /// ve tarih/şehir/ayar değiştiğinde hangi kaydın hâlâ geçerli olduğunu hesaplamak,
    /// kazandığından fazlasını hata olarak geri veriyor.
    func replaceAll(with plan: NotificationPlan, content: @Sendable (PlannedNotification) -> NotificationContent, playsSound: Bool) async
    func cancelAll() async
    /// Şu an sistemde bekleyen vakit bildirimlerinin sayısı — testler ve teşhis için.
    func pendingCount() async -> Int
}

/// Test ve önizleme için bellek içi zamanlayıcı.
public actor StubNotificationScheduler: NotificationScheduling {
    private var authorizationValue: NotificationAuthorization
    private let authorizationAfterRequest: NotificationAuthorization?
    public private(set) var scheduled: [PlannedNotification] = []
    public private(set) var contents: [String: NotificationContent] = [:]

    public init(
        authorization: NotificationAuthorization = .authorized,
        authorizationAfterRequest: NotificationAuthorization? = nil
    ) {
        self.authorizationValue = authorization
        self.authorizationAfterRequest = authorizationAfterRequest
    }

    public var authorization: NotificationAuthorization {
        get async { authorizationValue }
    }

    @discardableResult
    public func requestAuthorization() async -> NotificationAuthorization {
        if let authorizationAfterRequest {
            authorizationValue = authorizationAfterRequest
        }
        return authorizationValue
    }

    public func replaceAll(
        with plan: NotificationPlan,
        content: @Sendable (PlannedNotification) -> NotificationContent,
        playsSound: Bool
    ) async {
        scheduled = plan.notifications
        contents = Dictionary(
            uniqueKeysWithValues: plan.notifications.map { ($0.id, content($0)) }
        )
    }

    public func cancelAll() async {
        scheduled = []
        contents = [:]
    }

    public func pendingCount() async -> Int { scheduled.count }
}
