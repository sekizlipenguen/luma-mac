<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma uygulama simgesi">
</p>

# macOS için Luma

**Mac'inin ne yaptığını gör. Alanı neyin kullandığını bul. Kontrol ederek temizle.**

Luma; sistem izleme, depolama inceleme ve Mac bakımı için SwiftUI ile geliştirilmiş yerel bir macOS uygulamasıdır. Hesap, abonelik, reklam ve telemetri içermez.

**Kişisel ve ticari kullanım ücretsizdir. Cihaz, kullanıcı, özellik veya süre sınırı yoktur.** Kaynak kod incelenebilir ve değiştirilmeden derlenebilir. Kendi kopyanız dahil kodu veya belgeleri değiştirmek ve türev sürüm üretmek için yazılı izin gerekir. [Lisans](LICENSE).

[English](README.md) · [Sürümler](https://github.com/sekizlipenguen/luma-mac/releases) · [Hata bildir](https://github.com/sekizlipenguen/luma-mac/issues)

## Ekran görüntüleri

Türkçe arayüzle çalışan gerçek Luma ekranlarıdır. Değerler bilgisayara ve o anki iş yüküne göre değişir.

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

Arayüz İngilizce, Türkçe, Almanca, Fransızca, İspanyolca, İtalyanca, Brezilya Portekizcesi, Japonca, Korece, Basitleştirilmiş Çince, Rusça ve Arapça destekler.

## Güvenlik ve gizlilik

Temizlik yalnızca `CleanupRule` ve `PathSafety` kontrollerinden geçen konumlarda yapılır. Sistem dizinleri, anahtar zincirleri, Mail, Messages ve SSH anahtarları gibi hassas alanlar hariç tutulur. Deneme taraması dosyaları değiştirmez. Onay vermeden önce seçimleri inceleyin; dosyalar Çöp Sepeti'nde durduğu sürece Finder üzerinden geri alınabilir.

Temel özellikler yerelde çalışır ve internet gerektirmez. Analitik SDK bulunmaz. İşlem geçmişi `~/Library/Application Support/Luma/Operations/operations.jsonl` konumunda saklanır.

Desteklenen genel API yoksa sıcaklık gösterilmez; masaüstü Mac'lerde pil verisi bulunmayabilir; SMART desteği diske bağlıdır. Uygulama eksiklikleri açıkça belirtir.

## Kurulum

**macOS 15 veya üzeri gerekir.**

Yayınlanan resmi uygulama paketlerini [GitHub Releases](https://github.com/sekizlipenguen/luma-mac/releases) sayfasından edinin. Her sürümün mimari, imza ve noter onayı durumunu sürüm notlarından kontrol edin. Kaynak kod ZIP'i kurulabilir uygulama değildir; uygulama paketi henüz yoksa aşağıdaki derleme adımlarını kullanın.

Uygulama ZIP'ini açın, `Luma.app` dosyasını Uygulamalar'a taşıyın ve açın. İmza/noter onayı durumu ilgili sürüm için ayrıca doğrulanmalıdır.

- **Tam Disk Erişimi:** korunan kullanıcı Library konumları için Sistem Ayarları → Gizlilik ve Güvenlik → Tam Disk Erişimi bölümünden Luma'ya izin verin. İzin yoksa erişilemeyen alanlar atlanır.
- **Finder:** sağ tık menüsü için macOS uzantı ayarlarından Finder uzantısını etkinleştirin; klasör boyutu Servisi de kullanılabilir.
- **Simülatörler:** iOS için Xcode komut satırı araçları; Android için `adb` dahil Android SDK araçları gerekir.

Luma desteklediği kullanıcı alanlarını tarayabilmek için App Sandbox'ı kapalı kullanır. Dağıtım kanalı GitHub Releases'tir; herkese açık uygulama paketlerinde Developer ID imzası ve Apple noter onayı hedeflenir.

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
