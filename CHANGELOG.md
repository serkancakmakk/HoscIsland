# HoscIsland — Changelog

Mac için kendi Dynamic Island / notch uygulaması (Alcove · NotchNook · Boring Notch tarzı).

## [1.11.0] — 2026-06-25
### Eklendi
- **Dosya rafı (shelf)** 📁: Notch'a dosya sürükle-bırak → rafa eklenir; açık adada
  raf şeridinde küçük resimlerle görünür, **dışarı sürüklenebilir**, tıkla-aç, ✕ ile
  kaldır, "Temizle". Raf `UserDefaults`'a kaydedilir (yeniden açılınca kalır).
  - Sürükleme notch'a gelince ada açılıp **bırakma bölgesi** oluyor (mavi kenar).
  - Pencere `hitTest` ile yalnız notch bölgesinde etkileşimli → menü çubuğu hâlâ geçirgen.
### Değişti
- Proje **HoscIsland** olarak yeniden adlandırıldı (bundle id korundu → izinler kaldı).

## [1.10.0] — 2026-06-25
### Eklendi
- **Ekran görüntüsü önizleme** 📸: SS alınca notch'ta küçük önizleme + hızlı
  eylemler (**Kopyala / Finder'da göster / Sil**); küçük resme tıklayınca açılır,
  ~6 sn sonra kapanır.
  - Anlık algılama: `DispatchSource` (vnode) ile dosya yazılır yazılmaz tetikleniyor.
  - macOS "floating thumbnail" kapatıldı (`show-thumbnail=false`) → SS anında
    diske yazılıp önizleme gecikmesiz çıkıyor.

## [1.9.0] — 2026-06-25
### Eklendi
- **Ayarlardan özellik kontrolü**: Ayarlar'a *Özellikler* bölümü eklendi —
  Müzik göstergesi, WhatsApp banner, Okunmamış rozeti aç/kapa + **Pil göstergesi**
  için 3 mod: **Kapalı / Değişince / Her zaman**.
- **Pil "Her zaman" modu**: Seçilince pil + yüzde notch'ta sürekli durur (müzikle
  birlikteyken sağ kanatta pil ikonu). "Değişince" modunda eski flash davranışı.

## [1.8.0] — 2026-06-25
### Eklendi
- **Şarj göstergesi** 🔋: Kablo takıp çıkarınca notch'ta **çizilen pil + yüzde**
  flash'ı (şarjda yeşil + şimşek, düşük pilde kırmızı). IOKit `IOPowerSources`
  ile anlık plug/unplug algılama (poll yok).

## [1.7.0] — 2026-06-25
### Eklendi
- **Karıştır / Tekrarla** düğmeleri: Açık adadaki kontrollere eklendi; aktifken
  yeşil yanar. Spotify (`shuffling`/`repeating`) ve Music (`shuffle enabled`/
  `song repeat`) için çalışıyor.
### Düzeltildi
- **WhatsApp bildirimleri bazen gelmiyordu**: Artık hem `rec_id` hem
  `delivered_date` izleniyor → gruplu/yeniden-teslim edilen bildirimler de
  yakalanıyor. Poll aralığı 1,5 sn'ye indirildi.

## [1.6.0] — 2026-06-25
### Eklendi
- **Ses kontrolü**: Açık adada sürükle-bırak **sistem ses seviyesi** kaydırıcısı
  (uygulamadan bağımsız; hoparlör ikonlarıyla).

## [1.5.0] — 2026-06-25
### Eklendi
- **Şarkı ilerleme çubuğu**: Açık adada geçen/toplam süre + **sürükle-bırak seek**
  (Spotify ms, Music sn farkı çözüldü). Çubuk pollar arası yerel olarak akıcı ilerliyor.
- **Kapağa tıkla → uygulamayı öne getir** (Music/Spotify `activate`).

## [1.4.0] — 2026-06-25
### Eklendi
- **Gelen mesaj banner'ı**: WhatsApp mesajı gelince notch açılıp **gönderen + mesaj
  metnini** gösteriyor (bildirim `data` plist'i çözülerek), ~5 sn sonra kapanıyor.
- **Okunmamış mesaj rozeti**: Okunmamış WhatsApp sayısı notch'ta rozet olarak
  gösteriliyor; okudukça azalıyor. **Ayarlardan açılıp kapatılabiliyor.**
### Teknik
- **Kalıcı kod imzası**: Sabit kendinden-imzalı kimlikle (`PilotNotch Self-Signed`)
  imzalanıyor → FDA ve Otomasyon izinleri artık her derlemede silinmiyor.

## [1.3.0] — 2026-06-25
### Eklendi
- **WhatsApp bildirim göstergesi**: WhatsApp'tan bildirim geldiğinde notch'ta
  WhatsApp ikonu + yeşil "yeni mesaj" nabzı yanıp ~4,5 sn sonra kayboluyor.
  - macOS Bildirim Merkezi veritabanı (`group.com.apple.usernoted`) izleniyor.
  - **Tam Disk Erişimi** gerektirir → menüde *Bildirimler için Tam Disk Erişimi…*
    kısayolu eklendi.
- Ada açıkken üst içerik fiziksel kameranın altından başlıyor (dinamik `topInset`),
  fontlar küçültüldü; sanatçı/albüm artık kameranın arkasında kaybolmuyor.

## [1.2.0] — 2026-06-25
### Eklendi
- **Kompakt "şimdi çalıyor" görünümü**: Ada kapalıyken müzik çalıyorsa genişler;
  solda albüm kapağı, sağda **hareketli equalizer** (müzik ritmi) gösterir.
- Equalizer çalarken zıplar, duraklatınca düz durur.

### Düzeltildi
- **Menü çubuğu/sekme tıklanamıyordu**: Hover artık fare konumu izlenerek algılanıyor;
  ada kapalıyken pencere tamamen tıklamaya geçirgen (`ignoresMouseEvents`), altındaki
  menü çubuğu ve sekmeler normal kullanılabiliyor. Sadece açıkken tıklanabilir.
- Kompakt içerik fiziksel kamera/notch alanından net şekilde dışarı kondu.

### Teknik
- Now Playing artık `osascript` alt-süreciyle çalışıyor (NSAppleScript'in arka plan
  thread deadlock'u ve `st` rezerve-kelime syntax hatası giderildi).

## [1.1.0] — 2026-06-25
### Eklendi
- **Ekran seçimi**: Menü çubuğu → *Ayarlar…* penceresinden adanın hangi ekranda görüneceği seçilebilir.
  - Bağlı tüm ekranlar listelenir (ad, çözünürlük, notch durumu).
  - "Otomatik" modu notch'lu ekranı tercih eder.
  - Seçim `UserDefaults`'a kaydedilir, ekran takılıp çıkarıldığında otomatik güncellenir.
- Menü çubuğuna *Ayarlar…* (⌘,) öğesi.

### Düzeltildi
- Ada yanlış (ikinci) ekranda açılıyordu; artık seçilen / notch'lu ekrana sabitleniyor.

## [1.0.0] — 2026-06-25
### Eklendi
- Notch üstüne oturan saydam, her zaman üstte, tüm masaüstlerinde görünen panel.
- Hover ile collapsed pill ↔ expanded kart (spring animasyon).
- Music.app & Spotify için Now Playing: kapak, şarkı, sanatçı, albüm.
- Medya kontrolleri: önceki / oynat-durdur / sonraki (AppleScript).
- Menü çubuğu simgesi + Çıkış.
- Xcode'suz derleme: SwiftPM + `build.sh` ile `.app` paketleme.

---

## 🚧 Yapılacaklar (Roadmap)

> Öncelik kategorilere göre gruplandı; maddeler kullanıcı onayıyla tek tek eklenecek.

### 🎵 Medya & Now Playing
- [x] ⏱️ **Şarkı ilerleme çubuğu** — geçen/toplam süre; sürükle-seek + kapağa
      tıklayınca uygulamayı öne getirme. ✅ (1.5.0)
- [ ] 🎚️ **Canlı görselleştirici** — mevcut `EqualizerView` yerine gerçek ritimden
      beslenen waveform animasyonu.
- [x] 🔊 **Ses kontrolü** — notch içinde sistem ses kaydırıcısı. ✅ (1.6.0)
      _(AirPods/çıkış cihazı seçimi sonraya bırakıldı)_
- [ ] ❤️ **Beğen / favori** — çalan parçayı beğenme (Music "Love", Spotify save).
- [ ] 🎤 **Şarkı sözleri** — varsa senkron sözleri genişletilmiş kartta gösterme.

### 🔋 Pil & Güç
- [x] 🔋 **Şarj göstergesi** — kablo takınca notch'ta pil + yüzde flash'ı. ✅ (1.8.0)
- [ ] ⚠️ **Düşük pil uyarısı** — eşik altına düşünce kısa bir notch uyarısı.
- [ ] 🎧 **Bağlı cihaz pilleri** — AirPods / Magic Mouse / klavye şarj durumu.

### 🖥️ Sistem HUD (yerine geçme)
- [ ] 🔆 **Parlaklık & ses HUD'u** — sistemin ortadaki HUD'u yerine notch'ta
      şık bir gösterge.
- [x] 📸 **Ekran görüntüsü önizleme** — notch'ta önizleme + kopyala/Finder/sil.
      ✅ (1.10.0)
- [ ] 🔌 **Anlık olay flaşları** — şarja takma, cihaz bağlanma vb. kısa bildirimler.

### 📁 Dosya Rafı (Shelf)
- [x] 📁 **Sürükle-bırak tepsi** — notch'a bırakılan dosyalar için raf. ✅ (1.11.0)
- [ ] 📤 **Hızlı AirDrop / paylaşım** — raftaki dosyayı tek tıkla paylaşma.
- [ ] 🕑 **Son indirilenler / SS otomatik toplama** — rafta hızlı erişim.

### 🔔 Bildirimler
- [ ] 📱 **Çok uygulamalı bildirim** — WhatsApp dışı uygulamalar için de
      `NotificationWatcher` üzerinden genel destek (bundle eşleme listesi).
- [ ] 📚 **Bildirim yığını / geçmiş** — son bildirimleri genişletilmiş kartta
      listeleme.

### 🧩 Widget'lar (boştayken)
- [ ] 📅 **Takvim / sıradaki etkinlik** — boştaki notch'ta sonraki toplantı.
- [ ] ⏲️ **Zamanlayıcı / Pomodoro** — notch'tan hızlı sayaç.
- [ ] 📋 **Pano geçmişi** — son kopyalananlara hızlı erişim.
- [ ] 🌤️ **Hava durumu** — özetlenmiş günlük durum.

### 🎨 Özelleştirme & Davranış
- [ ] 🎨 **Görünüm ayarları** — ada boyutu, köşe yarıçapı, renk/tema
      (`NotchMetrics` parametreleştirme + `SettingsView` sekmesi).
- [ ] 👋 **Hover hassasiyeti** — açılma gecikmesi / kapanma süresi ayarı
      (`NotchController` hover zamanlayıcıları).
- [ ] 🖱️ **Etkileşim modu** — hover yerine "tıkla-aç" seçeneği.
- [ ] 🚀 **Açılışta otomatik başlat** — `SMAppService` (Login Item) + ayar anahtarı.

### 🛠️ Teknik & Dağıtım
- [ ] 🌍 **İngilizce yerelleştirme** — TR/EN dil desteği.
- [ ] ⬆️ **Otomatik güncelleme** — Sparkle entegrasyonu.
- [ ] 🔏 **İmzalama & notarization** — dağıtım için imzalı `.app`.
- [ ] ⚙️ **Sekmeli Ayarlar penceresi** — Genel / Görünüm / Medya / Hakkında.

### 🔎 İncelenecek / kısıtlar
- macOS 15.4+ MediaRemote 3. parti uygulamalara kapalı → şu an yalnız Music &
  Spotify. Sistem geneli "now playing" için alternatif araştırılacak.
- Şarj / cihaz pili verisi için `IOKit` (IOPowerSources) ile özel girişim gerekli.
- Pano / bildirim erişimi ek gizlilik izinleri gerektirebilir.
