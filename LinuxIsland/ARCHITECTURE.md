# LinuxIsland — Mimari

macOS sürümü yakın zamanda **katmanlı** hale getirildi
(`NotchModels` / `NotchGeometry` / `NotchInteractionMonitor` / `NotchController`).
Linux sürümü **aynı katman sınırlarını** korur; yalnızca platforma değen uçlar
değişir. Bu, ileride paylaşılan bir tasarım dili sağlar.

## Katman eşleştirmesi

| macOS katmanı | Sorumluluk | Linux karşılığı |
|---|---|---|
| `NotchModels` (durum + modeller) | `NotchState`, flash/notification/screenshot modelleri | Aynen taşınır — saf veri. Rust'ta `struct` + bir `AppState` (ör. `Rc<RefCell<…>>` veya bir kanal/`async` aktör). |
| `NotchGeometry` | Ekran dikdörtgenleri, notch tespiti, taşıma ofseti | Layer-shell **anchor + margin**'e dönüşür. "Notch genişliği" yok → sabit pill genişliği. Ofset = layer-shell margin. |
| `NotchInteractionMonitor` | Hover poll, swipe, click, collapse debounce | GTK `EventControllerMotion` (hover), `GestureClick`, `EventControllerScroll` (swipe). Poll yerine olay tabanlı. |
| `NotchController` | Orkestrasyon, özellik monitörlerini bağlama | `App` ana nesnesi: pencereyi kurar, D-Bus servislerini bağlar, durumu UI'a akıtar. |

## Önerilen modül yapısı (Rust)

```
linux-island/
├─ src/
│  ├─ main.rs              # GTK app bootstrap, layer-shell kurulumu
│  ├─ model.rs            # AppState, transient modeller (NotchModels karşılığı)
│  ├─ geometry.rs         # anchor/margin/boyut hesapları (NotchGeometry karşılığı)
│  ├─ interaction.rs      # hover/click/scroll controller'ları (InteractionMonitor)
│  ├─ ui/
│  │  ├─ island.rs        # ana widget (collapsed ↔ expanded, CSS animasyon)
│  │  ├─ now_playing.rs   # kapak, başlık, kontroller, ilerleme çubuğu
│  │  ├─ shelf.rs         # dosya rafı (DnD)
│  │  └─ screenshot.rs    # önizleme + kopyala/aç/sil
│  ├─ services/
│  │  ├─ mpris.rs         # org.mpris.MediaPlayer2 (now playing + kontrol)
│  │  ├─ battery.rs       # UPower / sysfs
│  │  ├─ notifications.rs # org.freedesktop.Notifications izleme
│  │  ├─ volume.rs        # PipeWire/PulseAudio
│  │  └─ screenshots.rs   # inotify ile dosya izleme
│  └─ settings.rs         # ayarlar (GSettings veya TOML), Settings karşılığı
└─ data/
   └─ style.css           # ada görünümü (köşe yarıçapı, blur, renkler)
```

## Platform uç eşlemeleri

| İşlev | macOS | Linux |
|---|---|---|
| Üstte/her masaüstünde panel | `NSPanel` + `collectionBehavior` | `gtk4-layer-shell` (`Layer::Overlay`, `anchor TOP`) |
| Geçirgenlik (passthrough) | `ignoresMouseEvents` + `hitTest` | layer-shell input region / `set_keyboard_mode(None)` + boş input shape |
| Hover algılama | mouse-location poll | `EventControllerMotion` |
| Tıkla/swipe | global `NSEvent` monitor | `GestureClick`, `EventControllerScroll` |
| Now playing | AppleScript (Music/Spotify) | **MPRIS** D-Bus (tüm oynatıcılar) |
| Pil | `IOKit IOPowerSources` | **UPower** D-Bus veya `/sys/class/power_supply` |
| Bildirim | Bildirim Merkezi SQLite | **org.freedesktop.Notifications** monitörü |
| Ekran görüntüsü | dizini `DispatchSource` ile izleme | `inotify` ile `~/Pictures` izleme |
| Dosya rafı DnD | `NSItemProvider` | GTK4 `DropTarget` / `DragSource` |
| Ses seviyesi | CoreAudio | PipeWire/PulseAudio |
| Ayar kalıcılığı | `UserDefaults` | `GSettings` veya `~/.config/linux-island/config.toml` |

## Davranış notları (macOS'tan taşınan kararlar)

- **Collapsed = tam geçirgen**: layer-shell'de input region'ı yalnız açıkken aktif et
  (macOS'taki `ignoresMouseEvents` mantığı).
- **Hover bölgesi görünür yüksekliği takip etmeli** (stuck-open hatasını önlemek için)
  — `geometry.rs` görünür yükseklik hesabını korur.
- **Swipe eşiği** (~50px birikim) ve **collapse debounce** (~0.18 sn) aynen taşınır.
- **Taşınabilirlik** = layer-shell margin'ini sürükleyle güncelle + ayara yaz.
