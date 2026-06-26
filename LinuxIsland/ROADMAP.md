# LinuxIsland — Yol Haritası

macOS sürümünün **mevcut** (changelog 1.0 → 1.15) özelliklerinin Linux'a taşınma
planı. Her satır bir macOS özelliği, karşısında Linux yaklaşımı ve zorluk.

Durum: ☐ planlandı · ◐ kısmi/araştırma gerekli · ✅ tamam

## Özellik haritası

| macOS özelliği (sürüm) | Linux yaklaşımı | Zorluk | Durum |
|---|---|---|---|
| Üstte oturan saydam panel (1.0) | `gtk4-layer-shell` overlay, anchor TOP | Orta | ☐ |
| Hover ile collapse ↔ expand + spring (1.0) | `EventControllerMotion` + CSS transition | Kolay | ☐ |
| Now playing: kapak/şarkı/sanatçı (1.0) | **MPRIS** `Metadata` | Kolay | ☐ |
| Medya kontrolleri prev/play/next (1.0) | MPRIS `Previous`/`PlayPause`/`Next` | Kolay | ☐ |
| Menü çubuğu simgesi + Çıkış (1.0) | `StatusNotifierItem` (tray) veya app menüsü | Orta | ☐ |
| Ekran seçimi (1.1) | layer-shell `set_monitor` + çoklu monitör listesi | Orta | ☐ |
| Kompakt now-playing + equalizer (1.2) | MPRIS `PlaybackStatus` + CSS animasyon | Kolay | ☐ |
| WhatsApp/uygulama bildirimi (1.3–1.4) | **org.freedesktop.Notifications** monitör; bundle yerine `app_name`/`desktop-entry` eşleme | Orta | ◐ |
| Okunmamış rozeti (1.4) | Bildirim sayacı (uygulama bazlı) — kaynak sınırlı, araştır | Zor | ◐ |
| Kalıcı imza/izinler (1.4) | Linux'ta gereksiz (imza modeli farklı) | — | ✅ (n/a) |
| İlerleme çubuğu + seek (1.5) | MPRIS `Position` + `SetPosition`/`Seek` | Orta | ☐ |
| Kapağa tıkla → uygulamayı öne getir (1.5) | MPRIS `Raise` | Kolay | ☐ |
| Sistem ses kaydırıcısı (1.6) | PipeWire/PulseAudio sink volume | Orta | ☐ |
| Karıştır/tekrarla (1.7) | MPRIS `Shuffle`/`LoopStatus` | Kolay | ☐ |
| Şarj göstergesi flash (1.8) | **UPower** `OnBattery`/`Percentage` sinyalleri | Kolay | ☐ |
| Pil modu kapalı/değişince/her zaman (1.9) | UPower + ayar | Kolay | ☐ |
| Ayarlardan özellik aç/kapa (1.9) | `settings.rs` + ayar penceresi | Kolay | ☐ |
| Ekran görüntüsü önizleme + eylemler (1.10) | `inotify` ile SS dizini; kopyala=`wl-copy`, aç=`xdg-open`, sil | Orta | ☐ |
| Dosya rafı (shelf) DnD (1.11) | GTK4 `DropTarget`/`DragSource`; kalıcılık config | Orta | ☐ |
| Swipe ile şarkı geçişi (1.12–1.13) | `EventControllerScroll` (yatay birikim) | Kolay | ☐ |
| Açılma şekli hover/tıkla (1.13) | ayar + controller modu | Kolay | ☐ |
| Collapsed tam geçirgen (1.13) | layer-shell input region yalnız açıkken | Orta | ☐ |
| Katmanlı mimari (1.14) | `model/geometry/interaction/controller` baştan böyle | — | ☐ (tasarımda) |
| Taşınabilir ada (1.15) | layer-shell margin sürükleme + ayar | Orta | ☐ |

## Kilometre taşları

### M0 — İskelet  ◐ (başladı)
- ✅ GTK4 + layer-shell ile üst-orta, üstte duran pill (`main.rs`).
- ✅ collapsed ↔ expanded geçişi (CSS) + hover controller + collapse debounce (`interaction.rs`, `ui/island.rs`).
- ✅ swipe (yatay scroll) iskeleti — şimdilik stderr'e log.
- ✅ `model/geometry/interaction/ui` modül iskeleti.
- ☐ collapsed iken input passthrough (input region daraltma).
- ☐ Linux'ta `cargo run` ile ilk görsel doğrulama.

### M1 — Now Playing  ✅ (Linux CI doğrulaması bekliyor)
- ✅ MPRIS: metadata, oynat/duraklat/önceki/sonraki, swipe, play/pause ikonu.
- ✅ Kapak resmi (`mpris:artUrl`), ilerleme çubuğu + **seek** (`SetPosition`).
- ✅ **Shuffle/repeat** (aktifken yeşil) + kapağa tıkla → **raise**.
- ☐ Çoklu oynatıcı seçimi (şu an ilk bulunan).
- ☐ Linux CI'da derleme doğrulaması (zbus/zvariant API'leri).

### ⏲️ Pomodoro  ✅
- Ada içinde 25 dk geri sayım + başlat/duraklat/sıfırla (`pomodoro.rs`, macOS ile ortak madde).

### 🗂️ Açık sekmeler/pencereler göstergesi (planlandı)
- macOS roadmap'iyle ortak: adada açık sekmeleri/pencereleri listeleyip tıkla-geç.
- Linux'ta kaynak: kompozitöre göre değişir — wlroots `foreign-toplevel-management`
  protokolü (açık toplevel'leri listeler) en uygun aday.

### M2 — Sistem göstergeleri  ◐ (büyük kısmı yazıldı)
- ✅ Pil göstergesi: sysfs poll + modlar (`services/battery.rs`).
- ✅ Ses kaydırıcısı: `wpctl` (PipeWire) (`services/volume.rs`).
- ✅ `inotify` ekran görüntüsü önizleme + kopyala/aç/sil (`services/screenshots.rs`).
- ✅ **Düşük pil uyarısı** — %20 altına ilk inişte banner (`main.rs`, macOS ile ortak madde).
- ☐ Pil "değişince" flash davranışı (şu an her zaman göster) + UPower'a geçiş.

### M3 — Bildirim & Raf  ✅
- ✅ freedesktop bildirim monitörü + banner (`services/notifications.rs`).
- ✅ **Dosya rafı**: DnD ile ekle, chip + ✕ + "Temizle", dışarı sürükle, kalıcı (`shelf.rs`, `ui/shelf.rs`).
- ☐ Okunmamış rozeti (kaynak sınırlı — freedesktop "okundu" durumu taşımaz).

### M4 — Cila & dağıtım  ◐
- ✅ Ayarlar (TOML) + tıkla/hover modu + taşınabilirlik (`settings.rs`, drag → margin).
- ✅ **Ayar penceresi (GUI)** — sağ tıkla aç (`ui/settings_window.rs`).
- ✅ **Açılışta otomatik başlat** — XDG `.desktop` autostart (`autostart.rs`, macOS ile ortak madde).
- ✅ CI: macOS `.app` + Linux binary derleme; `[release]` ile GitHub Releases.
- ☐ Çoklu monitör seçimi; equalizer animasyonu.
- ☐ Flatpak paketleme; wlroots dışı kompozitör fallback'i; collapsed input passthrough.

## Açık sorular / riskler
- **GNOME/KDE'de layer-shell yok** → ilk sürüm wlroots hedefli; sonra X11 fallback.
- **Bildirim izleme**: monitör olmak için bazı kompozitörlerde tek aktif notifier
  sınırı olabilir (DBus `Monitoring` arayüzü ile snoop daha güvenli).
- **Okunmamış sayısı**: freedesktop bildirimleri "okundu" durumu taşımaz → yalnız
  yaklaşık sayım mümkün.
- **Kapak resmi**: MPRIS `mpris:artUrl` çoğu zaman `file://`; bazı oynatıcılar
  vermez → fallback gerekir.
