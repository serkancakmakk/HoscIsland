# HoscIsland — Changelog

Mac için kendi Dynamic Island / notch uygulaması (Alcove · NotchNook · Boring Notch tarzı).

## [1.36.0] — 2026-06-27
### Eklendi
- **Son indirilenler** 🕑 (her iki platform): `~/Downloads` klasöründeki **en
  yeni dosyalar** genişletilmiş kartın çekmecesinde ikon + adla listeleniyor —
  **tıkla → aç**, **dışarı sürükle**. macOS'ta `FileManager` (Downloads dizini),
  LinuxIsland'da `$XDG_DOWNLOAD_DIR` → sysfs yok, saf `std::fs`; tarayıcı yarım
  indirmeleri (`.crdownload`/`.part`) elenir, 8 sn'de bir güncellenir.

## [1.35.0] — 2026-06-27
### Eklendi
- **Bağlı cihaz pilleri** 🎧 (her iki platform): Bluetooth aksesuarlarının
  (AirPods / Magic Mouse / klavye) şarjı genişletilmiş kartın çekmecesinde
  **isim + yüzde** ile listeleniyor (%20 altı kırmızı). macOS'ta `ioreg`
  (`BatteryPercent`), LinuxIsland'da sysfs `power_supply` (`scope=Device`)
  okunur; **ek bağımlılık yok**, 60 sn'de bir güncellenir.

## [1.34.0] — 2026-06-27
### Eklendi
- **Bildirim geçmişi** 📚 (her iki platform): Gelen bildirimler banner gibi
  geçip kaybolmuyor; genişletilmiş kartın çekmecesinde **son 12 bildirim**
  (yeni → eski) gönderen + metinle listeleniyor, **Temizle** ile sıfırlanıyor.
  macOS'ta gönderen uygulamanın ikonu + bağıl zaman; LinuxIsland'da freedesktop
  monitöründen gelen bildirimler aynı listeye düşüyor (olay/Gmail flaşları
  geçmişe girmez).

## [1.33.0] — 2026-06-27
### Değişti
- **Çok-uygulamalı bildirim** 📱 (macOS): Bildirim banner'ı artık yalnız WhatsApp
  değil **tüm uygulamaları** kapsıyor; gönderen + metin + **o uygulamanın ikonu**
  gösteriliyor. (LinuxIsland zaten freedesktop monitörüyle tüm uygulamaları
  gösteriyordu → parite tamam.)

## [1.32.0] — 2026-06-27
### Değişti
- **Genişletilmiş kart toparlandı**: İkincil bölümler (açık pencereler, Gmail,
  pano, raf) artık gövdenin (müzik/idle) altında **sabit yükseklikli, kaydırılabilir
  tek bir çekmecede** toplanıyor — kart içerik arttıkça sonsuza uzamıyor, hover
  bölgesi sabit kalıyor.

## [1.31.0] — 2026-06-27
### Eklendi
- **Şarkı sözleri** 🎤 (her iki platform): Çalan parçanın **senkron** sözleri
  lrclib.net'ten (anahtarsız) çekilir; müzik kartında **o anki satır** çalmayla
  birlikte güncellenir.

## [1.30.0] — 2026-06-27
### Eklendi
- **Açık pencereler göstergesi** 🗂️ (her iki platform): Açık adada o an açık
  pencereler ikon + başlıkla listelenir, **tıkla → o pencereye geç**. macOS'ta
  `CGWindowList` + uygulama aktivasyonu; LinuxIsland'da wlroots kompozitör CLI'ı
  (Hyprland `hyprctl` / Sway `swaymsg`) ile liste + odak.

## [1.29.0] — 2026-06-27
### Eklendi
- **Hava durumu** 🌤️ (her iki platform): Boştaki (müzik yokken) genişletilmiş
  kartta şehir + sıcaklık + duruma göre ikon. IP konum (ipapi.co) → Open-Meteo;
  **API anahtarı gerektirmez**, 30 dk'da bir güncellenir.

## [1.28.0] — 2026-06-27
### Eklendi
- **Parlaklık & ses HUD'u** 🔆 (her iki platform): Parlaklık ya da ses
  değişince notch/adada **ikon + bar** ile şık bir gösterge çakar (~1,3 sn).
  Değer poll'lanır (compositor-agnostik): macOS'ta CoreAudio ses + DisplayServices
  parlaklık; LinuxIsland'da `wpctl` ses + `/sys/class/backlight` parlaklık.

## [1.27.0] — 2026-06-27
### Eklendi
- **LinuxIsland parite — pano + olay flaşı + Gmail**: macOS'taki üç özellik Linux'a
  da eklendi —
  - **Pano geçmişi**: `wl-paste` poll + `wl-copy` ile geri kopyala (`services/clipboard.rs`).
  - **Olay flaşları**: GIO `VolumeMonitor` ile disk bağlanma/çıkarılma banner'ı (`services/devices.rs`).
  - **Gmail**: Atom feed (ureq + quick-xml), gönderen/konu listesi (tıkla → `xdg-open`),
    yeni postada banner; e-posta config'te, şifre `~/.config/linux-island/gmail-pass` (0600).

## [1.26.0] — 2026-06-27
### Eklendi
- **Gmail bağlama** 📧 (macOS): Ayarlar → *Gmail* bölümünden e-posta + **Uygulama
  Şifresi** ile bağlanılır. Gelen okunmamışlar adada **gönderen + konu** olarak
  listelenir (tıkla → tarayıcıda aç), yeni posta gelince **banner** çakar,
  okunmamış sayısı rozetlenir. Atom feed (OAuth/Google Cloud gerektirmez); şifre
  **Keychain**'de saklanır, yalnızca başlıklar okunur.
  - _Linux karşılığı sırada._

## [1.25.0] — 2026-06-27
### Eklendi
- **Pano geçmişi** 📋 (macOS): Son kopyalanan metinler açık adada şerit halinde;
  tıkla → geri kopyala, Temizle. _(Linux sırada.)_
- **Olay flaşları** 🔌 (macOS): Disk/çıkarılabilir aygıt bağlanıp çıkarılınca
  notch'ta kısa bildirim. _(Linux sırada.)_

## [1.24.0] — 2026-06-27
### Eklendi
- **Rafa uygulama ekleme** 📲 (her iki platform): Raf artık uygulamaları da tutar —
  ikonuyla görünür, **tıklayınca uygulamayı başlatır**. Raf başlığına **＋ Uygulama**
  butonu eklendi (macOS: /Applications seçici; Linux: `.desktop` seçici, `Name`/`Icon`
  ayrıştırılır, `gio launch` ile başlatılır).
- Raf artık ada açıkken **her zaman görünür** (boşken ipucu metni) → boş rafa da
  uygulama/dosya eklenebilir.

## [1.23.0] — 2026-06-27
### Değişti
- **Ayarlar penceresi yeniden tasarlandı** (Alcove-tarzı yumuşak): yuvarlak kartlar,
  renkli gradient ikon rozetleri, soft gölge, gradient zemin, gruplu bölümler.
### Düzeltildi
- **Taşınabilir ada artık gerçekten taşınıyor** (macOS): `isMovableByWindowBackground`
  SwiftUI içeriğiyle çalışmıyordu; taşıma **açık sürükleme** ile yeniden yazıldı —
  adanın **üst (notch) şeridinden** tutulur, alttaki kontrollerle çakışmaz, ada
  **ekran dışına kaçamaz** (clamp). **Sıfırla** artık aç/kapa anahtarının yanında
  her zaman görünür.

## [1.22.0] — 2026-06-27
### Eklendi
- **Hover hassasiyeti** 👋 (her iki platform): Ayarlar → **Anında / Normal / Rahat**.
  Açılma gecikmesi + kapanma süresini ayarlar (interaction monitörü / GTK motion).
- **LinuxIsland taşınabilir ada tamamlandı**: `movable` açılınca köşeye sıçrama
  düzeltildi (ilk açılışta yatay merkeze yerleşir, sonra sürüklenir).

## [1.21.0] — 2026-06-26
### Eklendi
- **Pomodoro zamanlayıcı** ⏲️ (her iki platform): Boştaki (müzik yokken)
  genişletilmiş kartta 25 dk geri sayım — başlat/duraklat + sıfırla. macOS'ta
  idle kart, LinuxIsland'da ada içinde widget satırı.

## [1.20.0] — 2026-06-26
### Eklendi
- **Açılışta otomatik başlat** 🚀 (her iki platform): Ayarlardan açılınca oturum
  açılışında otomatik başlar. macOS'ta `SMAppService` (Login Item), LinuxIsland'da
  `~/.config/autostart/linux-island.desktop` XDG autostart girişi.

## [1.19.0] — 2026-06-26
### Eklendi
- **Düşük pil uyarısı** ⚠️ (her iki platform): Pil şarjda değilken **%20'nin
  altına ilk inişte** bir kez uyarır. macOS'ta kırmızı pil flash'ı, LinuxIsland'da
  "🔋 Düşük pil — %X" banner'ı (5 sn). Pil göstergesi *Kapalı* iken susar.

## [1.18.0] — 2026-06-26
### Teknik
- **LinuxIsland tam parite (özellik bazında)**: kalan macOS özellikleri de
  Linux'a eklendi —
  - **Medya tamamlama**: ilerleme çubuğu + **seek** (`SetPosition`), **shuffle/
    repeat** (aktifken yeşil), **kapağa tıkla → uygulamayı öne getir** (`Raise`).
  - **Dosya rafı**: sürükle-bırak ekle, chip + ✕ + "Temizle", **dışarı sürükle**,
    `~/.config/linux-island/shelf`'e kalıcı.
  - **Ayar penceresi (GUI)**: adaya **sağ tıkla** → toggle'lar + pil modu (TOML'a yazar).
- Kalan (platform-sınırlı/minör): okunmamış rozeti, çoklu monitör seçimi,
  equalizer animasyonu, collapsed input-passthrough — roadmap'te.

## [1.17.0] — 2026-06-26
### Teknik
- **LinuxIsland ~parite**: macOS özelliklerinin çoğu Linux'a taşındı —
  now-playing (MPRIS, kapak dâhil), **pil** (sysfs), **ses** (wpctl/PipeWire),
  **ekran görüntüsü önizleme** (inotify + kopyala/aç/sil), **bildirim banner'ı**
  (freedesktop D-Bus monitör), **ayarlar** (TOML), **tıkla/hover modu** ve
  **taşınabilir ada** (layer-shell margin sürükleme).

## [1.16.0] — 2026-06-26
### Teknik
- **CI/CD release hattı** (GitHub Actions): Her push'ta macOS `.app` + Linux
  binary derlenir; commit mesajında **`[release]`** geçtiğinde ikisi de
  **GitHub Releases**'a yüklenir (sürüm `CHANGELOG`'dan okunur).
- **LinuxIsland M1 — MPRIS now-playing**: `zbus` ile çalan parça (başlık/sanatçı),
  oynat/duraklat/önceki/sonraki ve swipe ile parça geçişi. macOS'tan farklı olarak
  **tüm MPRIS uyumlu oynatıcıları** kapsar (sadece Music/Spotify değil).

## [1.15.0] — 2026-06-26
### Eklendi
- **Taşınabilir ada** 🤚: Ayarlar → *Taşınabilir ada* açıkken, ada açıldığında
  arka planından **sürükleyerek** istediğin yere taşıyabilirsin. Konum
  `UserDefaults`'a kaydedilir (yeniden açılınca kalır); hover/tıklama bölgeleri
  yeni konuma taşınır. **Sıfırla** ile ortaya geri döner. Ekran dışına taşmayı
  önlemek için konum kırpılır.

## [1.14.0] — 2026-06-26
### Teknik
- **Katmanlı `NotchController` refactor'u**: Şişen 405 satırlık controller dört
  odaklı dosyaya ayrıldı (davranış birebir korundu):
  - `NotchModels.swift` — paylaşılan durum + model türleri (`NotchState`,
    `NotchNotification`, `BatteryFlash`, `ScreenshotPreview`, `PassthroughHostingView`).
  - `NotchGeometry.swift` — ekran dikdörtgenleri + notch/top-inset tespiti.
  - `NotchInteractionMonitor.swift` — hover poll'u, swipe ve click monitörleri,
    collapse debounce'u (olay yutmayan, closure tabanlı arayüz).
  - `NotchController.swift` — yalnızca orkestrasyon: panel, durum gözlemcileri ve
    özellik monitörlerinin (now-playing/bildirim/pil/SS) bağlanması.

## [1.13.0] — 2026-06-25
### Eklendi
- **Açılma şekli ayarı**: Ayarlar → *Açılma şekli* = **Hover / Tıkla**.
  - **Tıkla** modunda hover ile açılmaz (menüleri kapatmaz); üzerine gelince
    **hafifçe büyür** (ipucu), **tıklayınca** açılır.
- **Swipe ile şarkı geçişi** (scroll tabanlı): Notch üzerinde iki parmak yatay
  kaydırma → sonraki/önceki parça. Global, **olay yutmayan** monitör.
### Düzeltildi
- **Notch altındaki alana tıklanamıyor/sürüklenemiyordu**: Kapalıyken ada artık
  **tamamen geçirgen** (hover modunda); altındaki sekmeler/pencereler serbest.
  Dosya bırakma, sürüklemeyi notch'a getirince hover-açılmayla çalışıyor.

## [1.12.0] — 2026-06-25
### Eklendi
- **Swipe ile şarkı geçişi** (ilk sürüm, sürükle tabanlı).
### Düzeltildi
- Sınırda sekme tıklama (ilk deneme).

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
- [x] 🎤 **Şarkı sözleri** — senkron sözler, o anki satır. ✅ (1.31.0)

### 🔋 Pil & Güç
- [x] 🔋 **Şarj göstergesi** — kablo takınca notch'ta pil + yüzde flash'ı. ✅ (1.8.0)
- [x] ⚠️ **Düşük pil uyarısı** — eşik altına (%20) düşünce kısa uyarı. ✅ (1.19.0)
- [x] 🎧 **Bağlı cihaz pilleri** — AirPods / Magic Mouse / klavye şarj durumu. ✅ (1.35.0)

### 🖥️ Sistem HUD (yerine geçme)
- [x] 🔆 **Parlaklık & ses HUD'u** — notch'ta ikon + bar göstergesi. ✅ (1.28.0)
- [x] 📸 **Ekran görüntüsü önizleme** — notch'ta önizleme + kopyala/Finder/sil.
      ✅ (1.10.0)
- [x] 🔌 **Anlık olay flaşları** — disk/aygıt bağlanma kısa bildirimleri. ✅ (1.25.0, macOS)

### 📁 Dosya Rafı (Shelf)
- [x] 📁 **Sürükle-bırak tepsi** — notch'a bırakılan dosyalar için raf. ✅ (1.11.0)
- [ ] 📤 **Hızlı AirDrop / paylaşım** — raftaki dosyayı tek tıkla paylaşma.
- [x] 🕑 **Son indirilenler** — çekmecede ~/Downloads hızlı erişim. ✅ (1.36.0)

### 🔔 Bildirimler
- [x] 📱 **Çok uygulamalı bildirim** — tüm uygulamalar + uygulama ikonu. ✅ (1.33.0)
- [x] 📚 **Bildirim yığını / geçmiş** — son bildirimleri genişletilmiş kartta
      listeleme. ✅ (1.34.0)

### 🧩 Widget'lar (boştayken)
- [x] 🗂️ **Açık sekmeler/pencereler göstergesi** — açık pencereleri listeleyip
      tıkla-geç. ✅ (1.30.0)
- [ ] 📅 **Takvim / sıradaki etkinlik** — boştaki notch'ta sonraki toplantı.
- [x] ⏲️ **Zamanlayıcı / Pomodoro** — boştaki kartta 25 dk sayaç. ✅ (1.21.0)
- [x] 📋 **Pano geçmişi** — son kopyalananlara hızlı erişim. ✅ (1.25.0, macOS)
- [x] 🌤️ **Hava durumu** — boştaki kartta şehir + sıcaklık + ikon. ✅ (1.29.0)

### 🎨 Özelleştirme & Davranış
- [ ] 🎨 **Görünüm ayarları** — ada boyutu, köşe yarıçapı, renk/tema
      (`NotchMetrics` parametreleştirme + `SettingsView` sekmesi).
- [x] 👋 **Hover hassasiyeti** — açılma gecikmesi / kapanma süresi ayarı. ✅ (1.22.0)
- [ ] 🖱️ **Etkileşim modu** — hover yerine "tıkla-aç" seçeneği.
- [x] 🚀 **Açılışta otomatik başlat** — `SMAppService` (Login Item) + ayar anahtarı. ✅ (1.20.0)

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
