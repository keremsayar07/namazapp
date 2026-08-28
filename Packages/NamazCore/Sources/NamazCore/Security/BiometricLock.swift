import Foundation
import LocalAuthentication

/// Notlar sekmesinin isteğe bağlı kilidi.
///
/// **Neden bu var, neden şifreleme yok.** Notlar zaten `FileProtection.complete` altında
/// duruyor: cihaz kilitliyken dosya donanım destekli olarak şifreli ve okunamıyor. Buna
/// kendi şifreleme katmanımızı eklemek gerçek bir saldırganı durdurmazdı — anahtarı da aynı
/// cihazda tutmak zorunda kalırdık — ama veri kaybı riski getirirdi.
///
/// Data Protection'ın karşılamadığı tek senaryo şu: **telefon açıkken birisi eline aldı.**
/// O anda dosyalar erişilebilir durumda ve uygulama açılıyor. Bu kilit tam olarak bunun
/// için; başka bir iddiası yok.
public protocol BiometricLocking: Sendable {
    /// Cihazda Face ID / Touch ID ya da en azından bir parola tanımlı mı.
    var isAvailable: Bool { get }
    /// Kilidi açmayı dener. Kullanıcı iptal ederse ya da doğrulama başarısız olursa `false`.
    func authenticate(reason: String) async -> Bool
}

public struct DeviceBiometricLock: BiometricLocking {

    public init() {}

    /// `.deviceOwnerAuthentication` — yalnızca biyometri DEĞİL.
    ///
    /// Bilerek: `.deviceOwnerAuthenticationWithBiometrics` seçilseydi, Face ID birkaç kez
    /// başarısız olduğunda ya da kullanıcı maskeliyken notlarına hiç erişemezdi. Bu
    /// politika parolaya düşmeye izin veriyor, yani kullanıcı kendi verisinden kilitlenmiyor.
    private static let policy: LAPolicy = .deviceOwnerAuthentication

    public var isAvailable: Bool {
        LAContext().canEvaluatePolicy(Self.policy, error: nil)
    }

    public func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(Self.policy, error: nil) else { return false }
        // Hata fırlatılırsa (iptal, başarısızlık, izin yok) sonuç `false`. Kilit
        // açılmadığında notlar gösterilmiyor — hata durumunda "aç" tarafına düşmek,
        // kilidi anlamsız kılardı.
        return (try? await context.evaluatePolicy(Self.policy, localizedReason: reason)) ?? false
    }
}

/// Test ve önizleme için. Sistem diyaloğu açmıyor.
public struct StubBiometricLock: BiometricLocking {
    public let isAvailable: Bool
    private let succeeds: Bool

    public init(isAvailable: Bool = true, succeeds: Bool = true) {
        self.isAvailable = isAvailable
        self.succeeds = succeeds
    }

    public func authenticate(reason: String) async -> Bool {
        isAvailable && succeeds
    }
}
