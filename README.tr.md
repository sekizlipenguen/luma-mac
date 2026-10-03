<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma uygulama simgesi">
</p>

# macOS için Luma

**Mac'inin ne yaptığını gör. Alanı neyin kullandığını bul. Kontrol ederek temizle.**

**12 arayüz dili · Yerel macOS uygulaması · Ücretsiz ve sınırsız kullanım**

Luma; sistem izleme, depolama inceleme ve Mac bakımı için SwiftUI ile geliştirilmiş yerel bir macOS uygulamasıdır. Hesap, abonelik, reklam ve telemetri içermez.

**Kişisel ve ticari kullanım ücretsizdir. Cihaz, kullanıcı, özellik veya süre sınırı yoktur.** Kaynak kod incelenebilir ve değiştirilmeden derlenebilir. Kendi kopyanız dahil kodu veya belgeleri değiştirmek ve türev sürüm üretmek için yazılı izin gerekir. [Lisans](LICENSE).

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

[Sürümler](https://github.com/sekizlipenguen/luma-mac/releases) · [Hata bildir](https://github.com/sekizlipenguen/luma-mac/issues)

**[DMG indir — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [ZIP](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip)

## Ekran görüntüleri

İngilizce arayüzle çalışan gerçek Luma ekranlarıdır. Değerler bilgisayara ve o anki iş yüküne göre değişir.

![Özet: CPU, bellek, depolama, ağ ve pil](Docs/Images/dashboard.png)

<details>
<summary>Temizlik, geliştirici araçları ve simülatör ekranları</summary>

![Temizlik kuralları](Docs/Images/cleanup.png)

![Geliştirici temizliği](Docs/Images/developer.png)

![iOS simülatörleri ve Android emülatörleri](Docs/Images/simulators.png)

</details>

## Neler yapar?

- **Özet:** CPU kullanımı, bellek basıncı, sıkıştırılmış bellek, swap, disk alanı, ağ hızları, pil ve süreç enerji sayaçlarını gösterir.
- **CPU işlemleri:** uygulamaları yardımcı süreçleriyle gruplar; arama, toplam tüketim ve alt süreçleri inceleme sunar. Normal kapatma işleminden önce onay ister.
- **Bellek:** gerçek bellek kullanımını ve basıncını açıklar; sahte RAM temizliği yapmaz.
- **Ağ:** Wi-Fi/Ethernet hareketini ve yerel bağlantıları gösterir. API'nin sağlamadığı uygulama başına veri hızlarını uydurmaz.
- **Depolama:** disk kullanımını ve klasör boyutlarını hızlı veya ev dizinini kapsayan taramalarla inceletir.
- **Finder klasör boyutu:** sağ tık menüsü veya Servisler üzerinden seçilen klasörün boyutunu Luma panelinde hesaplar.
- **Büyük dosyalar:** belirlediğiniz boyut eşiğinin üzerindeki dosyaları bulur.
- **Kopyalar:** SHA-256 ile dosya içeriklerini karşılaştırır; silmeden önce sonuçları inceletir.
- **Temizlik:** izin verilen kurallar için alan tahmini, inceleme ve onay sunar. Varsayılan işlem Çöp Sepeti'ne taşımaktır.
- **Geliştirici:** desteklenen geliştirme önbellekleri ve derleme çıktılarını inceletir; seçenekler yüklü araçlara göre değişir.
- **Uygulamalar:** yüklü uygulamaları listeler; kaldırırken ilgili dosyaları tek tek seçebilirsiniz.
- **Başlangıç:** giriş öğeleri ve LaunchAgent kayıtlarını gösterir. Sistem LaunchDaemon kayıtları yalnızca görüntülenebilir.
- **Simülatörler:** iOS simülatörleri ve Android emülatörlerini listeler; seçili veya listelenen sanal cihazları onayla kapatır. Fiziksel telefonları kapsam dışı tutar ve cihaz verilerini silmez.
- **Disk sağlığı:** macOS ve disk destekliyorsa SMART bilgilerini gösterir.
- **Güvenlik:** FileVault, güvenlik duvarı, Gatekeeper, SIP ve izin durumlarını ilgili Ayarlar bağlantılarıyla gösterir. Antivirüs değildir.
- **Mac bakım, zamanlama ve geçmiş:** desteklenen bakım işlemleri ve yerel kayıtları sunar. Zamanlama uygulamayı açar; arka planda sessizce dosya silmez.

## Desteklenen diller

**12 arayüz dili:** İngilizce, Türkçe, Almanca, Fransızca, İspanyolca, İtalyanca, Brezilya Portekizcesi, Japonca, Korece, Basitleştirilmiş Çince, Rusça ve Arapça.

Dili **Ayarlar → Dil** bölümünden seçebilir veya sistem dilini takip edebilirsiniz. Sistem Varsayılanı bir seçim biçimidir; 13. dil değildir. Bazı teknik veya henüz çevrilmemiş metinler İngilizce görünebilir. Desteklenen her dilin README bağlantısı sayfanın başındadır.

## Güvenlik ve gizlilik

Temizlik yalnızca `CleanupRule` ve `PathSafety` kontrollerinden geçen konumlarda yapılır. Sistem dizinleri, anahtar zincirleri, Mail, Messages ve SSH anahtarları gibi hassas alanlar hariç tutulur. Deneme taraması dosyaları değiştirmez. Onay vermeden önce seçimleri inceleyin; dosyalar Çöp Sepeti'nde durduğu sürece Finder üzerinden geri alınabilir.

Temel özellikler yerelde çalışır ve internet gerektirmez. Analitik SDK bulunmaz. İşlem geçmişi `~/Library/Application Support/Luma/Operations/operations.jsonl` konumunda saklanır.

Desteklenen genel API yoksa sıcaklık gösterilmez; masaüstü Mac'lerde pil verisi bulunmayabilir; SMART desteği diske bağlıdır. Uygulama eksiklikleri açıkça belirtir.

## Kurulum

**macOS 15 veya üzeri gerekir. Apple Silicon ve Intel desteklenir.**

**[DMG indir — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [Uygulama ZIP'i](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip) · [SHA-256 doğrulama](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/SHA256SUMS.txt)

DMG'yi açın, `Luma.app` dosyasını **Applications / Uygulamalar** klasörüne sürükleyin, disk imajını çıkarın ve uygulamayı Uygulamalar'dan açın. Alternatif olarak uygulama ZIP'ini açıp `Luma.app` dosyasını Uygulamalar'a taşıyın. GitHub'ın otomatik kaynak kod arşivleri kurulabilir uygulama içermez.

**İlk ön sürüm (0.1.0) ad-hoc imzalıdır; Developer ID dağıtım imzası ve Apple noter onayı yoktur.** macOS ilk açılışı engellerse ve kaynağa güveniyorsanız, uygulamayı açmayı denedikten sonra **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** yolunu kullanıp Aç'ı onaylayın. Kurumsal Mac'lerde bu izin kapalı olabilir. [Apple'ın yönergesi](https://support.apple.com/tr-tr/102445).

- **Tam Disk Erişimi:** korunan kullanıcı Library konumları için Sistem Ayarları → Gizlilik ve Güvenlik → Tam Disk Erişimi bölümünden Luma'ya izin verin. İzin yoksa erişilemeyen alanlar atlanır.
- **Finder:** sağ tık menüsü için macOS uzantı ayarlarından Finder uzantısını etkinleştirin; klasör boyutu Servisi de kullanılabilir.
- **Simülatörler:** iOS için Xcode komut satırı araçları; Android için `adb` dahil Android SDK araçları gerekir.

Luma desteklediği kullanıcı alanlarını tarayabilmek için App Sandbox'ı kapalı kullanır. Dağıtım kanalı GitHub Releases'tir; imza durumunu ilgili sürümden kontrol edin. Paketleme ve gelecekteki Developer ID dağıtımı [yayın rehberinde](Docs/Releasing.md) açıklanır.

## Kaynak koddan derleme

Swift 6 ve macOS 15 SDK veya üzerini destekleyen Xcode ile XcodeGen gerekir. Lisans, uygulama kodunu değiştirmeden derleme ve yerel imzalama ayarlarını yapmaya izin verir.

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
open Luma.xcodeproj
```

Developer ID sertifikası olmadan yerel Release derlemesi:

```bash
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Çıktı: `build/Build/Products/Release/Luma.app`. Bu derleme ad-hoc imzalıdır; Developer ID imzası veya noter onayı oluşturmaz.

## Belgeler ve geri bildirim

Mevcut mimari MVVM, Observation, actor servisleri ve `AppEnvironment` üzerinden protokol tabanlı bağımlılık yönetimi kullanır.

- [Mimari](Docs/Architecture.md)
- [Güvenlik modeli](Docs/Safety-Model.md)
- [API eşleştirmesi](Docs/API-Matrix.md)
- [Geri bildirim politikası](Docs/Contributing.md)
- [Güvenlik bildirimleri](SECURITY.md)
- [Lisans açıklaması](Docs/Licensing.md)

Hataları ve önerileri [Issues](https://github.com/sekizlipenguen/luma-mac/issues) üzerinden paylaşabilirsiniz. Sürüm, macOS sürümü, adımlar, beklenen ve gerçekleşen sonucu yazın; eklerden kişisel yolları ve özel bilgileri çıkarın.

Resmi değişiklikler bakımcıların kontrolündedir. Üçüncü kişilerin kod veya belge değişiklikleri için önceden yazılı izin gerekir; izinsiz pull request kabul edilmez.

## Lisans

**Luma Free Use, No Modification License 1.0.** Bağlayıcı İngilizce metin [LICENSE](LICENSE) dosyasındadır.

Kişisel ve ticari kullanım ücretsiz ve sınırsızdır. Kod incelenebilir, değiştirilmeden derlenebilir ve aynı lisans/telif bildirimleri korunarak değişmemiş kopyalar paylaşılabilir. Kendi kopyanızı değiştirmek, türev ürün üretmek, yeniden markalamak veya kodu başka ürüne dahil etmek yazılı izne bağlıdır.

Bu, **kaynağı görülebilen yazılım (source available)** modelidir. [Açık kaynak tanımı](https://opensource.org/osd) değişiklik ve türev sürüm izni gerektirdiğinden Luma bu lisansla açık kaynak sayılmaz. GitHub'ın görüntüleme ve fork hakları geçerlidir; bunlar tek başına değişiklik izni vermez. Önceden verilmiş lisans hakları varsa geri alınmaz.
