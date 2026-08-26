import SwiftUI
import UIKit
import NamazCore
import PrayerKit

/// Kıble ekranı — "Dizgi" yönü.
///
/// Ekranın söylediği iki ayrı şey var ve ayrı tutulmaları önemli:
///
/// - **Kıble açısı** konumdan hesaplanan sabit bir gerçek. Ölçüm gerektirmez, pusula
///   bozuk olsa bile doğrudur. Bu yüzden en üstte, büyük ve kalıcı.
/// - **İbre** telefonun manyetometresinden gelen canlı bir tahmin. Sapma payı var,
///   metal ve mıknatıs bozuyor. Bu yüzden ekran sapma payını gizlemiyor ve kötüyken
///   açıkça uyarıyor — sessizce yanlış yön göstermek, hiç göstermemekten kötü.
struct QiblaScreen: View {

    let location: SavedLocation?

    @State private var model: QiblaViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    init(location: SavedLocation?, headingService: HeadingProviding) {
        self.location = location
        _model = State(initialValue: QiblaViewModel(location: location, headingService: headingService))
    }

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(height: 2)
                        .accessibilityHidden(true)

                    if model.availability == .noLocation {
                        NoLocationNotice()
                    } else {
                        content
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        // Görev ekranla birlikte iptal ediliyor; akış kapanınca manyetometre de duruyor.
        .task { await model.start() }
        .onChange(of: location) { model.update(location: location) }
        // Kıbleyi ararken telefon elde çevriliyor ve gözler ekranda olmayabiliyor.
        // Hizalandığı an tek bir dokunsal darbe, bakmadan da anlaşılmasını sağlıyor.
        .onChange(of: model.isAligned) {
            guard model.isAligned else { return }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let bearing = model.bearing {
            header(bearing: bearing)

            QiblaDial(
                bearing: bearing,
                heading: model.heading,
                relativeAngle: model.relativeAngle,
                isAligned: model.isAligned,
                animated: !reduceMotion
            )
            .padding(.top, 26)
            .frame(maxWidth: .infinity)

            StatusLine(model: model)
                .padding(.top, 22)

            footnotes
                .padding(.top, 26)
        }
    }

    private func header(bearing: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.t("qibla.bearing.label"))
                .microLabelStyle()

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Formatting.degrees(bearing))
                    .font(Typography.place)
                    .foregroundStyle(Palette.ink)

                if let name = location?.name {
                    Text(name)
                        .font(Typography.dateline)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let distance = model.distanceMeters {
                Text(L.t("qibla.distance %@", Formatting.distance(distance)))
                    .font(Typography.microLabel)
                    .foregroundStyle(Palette.inkSoft)
            }

            // Dürüstlük notu. Bir kıble pusulasının doğruluğunu abartmak, kullanıcıyı
            // yanlış yöne güvenle döndürmek demek.
            Text(L.t("qibla.note"))
                .font(Typography.microLabel)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Kadran

/// Halka gerçek kuzeye sabitleniyor (cihaz yönünün tersine dönüyor), ibre ise kıbleye.
/// Böylece K harfi her zaman gerçek kuzeyi, ibre her zaman Kâbe'yi gösteriyor — tıpkı elde
/// tutulan bir pusula gibi.
///
/// Pusula yoksa halka döndürülmüyor ve "ekranın üstü kuzey olsaydı" varsayımı durum
/// satırında açıkça yazılıyor; sessizce sabit bir ibre göstermek kullanıcıyı yanıltırdı.
private struct QiblaDial: View {
    let bearing: Double
    let heading: Double?
    let relativeAngle: Double?
    let isAligned: Bool
    let animated: Bool

    private let size: CGFloat = 260

    /// İbrenin ekrandaki açısı. Pusula varsa cihaza göre, yoksa doğrudan kuzeye göre.
    private var needleAngle: Double { relativeAngle ?? bearing }
    private var ringAngle: Double { heading.map { -$0 } ?? 0 }

    private var motion: Animation? {
        // İnce ama önemli: yay animasyonu ibrenin okumadaki titremeyi yumuşatıyor.
        // Hareket azaltma açıksa hiç animasyon yok — dönen bir kadran baş döndürebiliyor.
        animated ? .interactiveSpring(response: 0.35, dampingFraction: 0.85) : nil
    }

    var body: some View {
        ZStack {
            // Sabit referans çentiği: cihazın baktığı yön. Kadran döner, bu durur.
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(width: 1.5, height: 14)
                Spacer(minLength: 0)
            }
            .frame(height: size + 24)

            Circle()
                .stroke(Palette.rule, lineWidth: 1)
                .frame(width: size, height: size)

            Circle()
                .stroke(Palette.rule, lineWidth: 1)
                .frame(width: size - 48, height: size - 48)

            CardinalRing(diameter: size - 24)
                .rotationEffect(.degrees(ringAngle))

            Needle(length: size / 2 - 30)
                .rotationEffect(.degrees(needleAngle))

            Circle()
                .fill(isAligned ? Palette.mark : Palette.ink)
                .frame(width: 6, height: 6)
        }
        .frame(width: size, height: size + 24)
        .animation(motion, value: needleAngle)
        .animation(motion, value: ringAngle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        // İçerik sürekli değişiyor; VoiceOver'a bunu söylemek her dönüşte okumayı
        // baştan başlatmasını engelliyor.
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Kadran görsel; ekran okuyucuya dönülecek yönü sözle söylemek zorunda.
    private var spoken: String {
        guard let relativeAngle else {
            return L.t("qibla.accessibility.static %@", Formatting.degrees(bearing))
        }
        if isAligned { return L.t("qibla.aligned") }
        let amount = String(Int(abs(relativeAngle).rounded()))
        return relativeAngle > 0
            ? L.t("qibla.turn.right %@", amount)
            : L.t("qibla.turn.left %@", amount)
    }
}

/// K / D / G / B harfleri. İkon değil harf: bu ekranın dili de tipografi.
private struct CardinalRing: View {

    /// Harflerin oturduğu çemberin çapı — iki kural çizgisinin arasına denk geliyor.
    let diameter: CGFloat

    private struct Cardinal: Identifiable {
        /// Yerelleştirme anahtarı aynı zamanda kimlik: dört harf, dört anahtar.
        let id: String
        let angle: Double
    }

    private let points: [Cardinal] = [
        Cardinal(id: "compass.north", angle: 0),
        Cardinal(id: "compass.east", angle: 90),
        Cardinal(id: "compass.south", angle: 180),
        Cardinal(id: "compass.west", angle: 270)
    ]

    var body: some View {
        ZStack {
            ForEach(points) { point in
                VStack(spacing: 0) {
                    Text(L.t(point.id))
                        .font(Typography.microLabel)
                        .foregroundStyle(point.angle == 0 ? Palette.ink : Palette.inkSoft)
                        // Harf halkayla dönerken baş aşağı kalmasın diye kendi açısı
                        // kadar geri döndürülüyor.
                        .rotationEffect(.degrees(-point.angle))
                    Spacer(minLength: 0)
                }
                .frame(height: diameter)
                .rotationEffect(.degrees(point.angle))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Kıble ibresi: merkezden yukarı doğru tek bir çizgi, ucunda küçük bir nokta.
///
/// Tek uçlu. Çift uçlu bir ibre "arkanız da kıble" diye okunabilirdi ve bu ekranda
/// yanlış anlaşılmaya yer yok.
private struct Needle: View {
    let length: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Palette.mark)
                .frame(width: 9, height: 9)
            Rectangle()
                .fill(Palette.mark)
                .frame(width: 2, height: length - 9)
            // Alt yarı boş bırakılıyor ki dönme merkezi kadranın merkezi olsun.
            Color.clear
                .frame(width: 2, height: length)
        }
        .frame(height: length * 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Durum satırı

private struct StatusLine: View {
    let model: QiblaViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(Font.system(.headline, design: .serif))
                .foregroundStyle(model.isAligned ? Palette.mark : Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(Typography.prayerName)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay { Rectangle().stroke(Palette.rule, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        switch model.availability {
        case .noLocation:
            return L.t("qibla.nolocation.title")
        case .noCompass:
            return L.t("qibla.nocompass.title")
        case .waiting:
            return L.t("qibla.waiting")
        case .live:
            guard let angle = model.relativeAngle else { return L.t("qibla.waiting") }
            if model.isAligned { return L.t("qibla.aligned") }
            let amount = String(Int(abs(angle).rounded()))
            return angle > 0
                ? L.t("qibla.turn.right %@", amount)
                : L.t("qibla.turn.left %@", amount)
        }
    }

    private var detail: String? {
        if model.availability == .noCompass { return L.t("qibla.nocompass.body") }
        if model.needsCalibration, let accuracy = model.accuracy {
            return L.t("qibla.calibration %@", String(Int(accuracy.rounded())))
        }
        if let accuracy = model.accuracy {
            return L.t("qibla.accuracy %@", String(Int(accuracy.rounded())))
        }
        return nil
    }
}

// MARK: - Konum yok

private struct NoLocationNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("qibla.nolocation.title"))
                .font(Font.system(.title2, design: .serif))
                .foregroundStyle(Palette.ink)

            Text(L.t("qibla.nolocation.body"))
                .font(Typography.prayerName)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 26)
    }
}

// MARK: - Önizlemeler

#Preview("Kıble") {
    QiblaScreen(
        location: SavedLocation(
            name: "İstanbul",
            coordinate: Coordinate(
                latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"
            ),
            source: .manual
        ),
        headingService: StubHeadingService(
            snapshots: [HeadingSnapshot(trueHeading: 120, accuracy: 8)]
        )
    )
}

#Preview("Pusula yok") {
    QiblaScreen(
        location: SavedLocation(
            name: "Ankara",
            coordinate: Coordinate(
                latitude: 39.9334, longitude: 32.8597, timeZoneIdentifier: "Europe/Istanbul"
            ),
            source: .manual
        ),
        headingService: StubHeadingService(isAvailable: false)
    )
}

#Preview("Konum yok") {
    QiblaScreen(location: nil, headingService: StubHeadingService(isAvailable: false))
}
