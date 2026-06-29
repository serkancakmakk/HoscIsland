# LinuxIsland — Tasarım & Planlama

> HoscIsland'ın (macOS Dynamic Island) **Linux karşılığı** için ayrı proje planı.
> Bu klasör henüz kod değil; mevcut macOS sürümünün özelliklerini Linux'a taşımak
> için **mimari + yol haritası** içerir.

## Neden ayrı proje?

macOS sürümü baştan sona Apple'a özgü API'lere dayanıyor — `AppKit`, `SwiftUI`,
`IOKit`, AppleScript/MediaRemote, Bildirim Merkezi DB'si. Bunların hiçbiri Linux'ta
yok. Dolayısıyla "port" değil, **aynı ürün fikrinin Linux-yerel yeniden inşası**
gerekiyor. İyi haber: Linux'un D-Bus ekosistemi çoğu entegrasyonu macOS'tan **daha
temiz ve daha geniş kapsamlı** sunar (örn. MPRIS ile *tüm* oynatıcılar, sadece
Music/Spotify değil).

## Hedef

Ekranın üst-ortasında duran, her zaman üstte, hover/tıkla ile genişleyen bir
"ada": now-playing, pil, bildirim, ekran görüntüsü önizleme, dosya rafı — macOS
sürümüyle aynı his.

## Önerilen teknoloji yığını

| Katman | Seçim | Gerekçe |
|---|---|---|
| Dil | **Rust** (`gtk4-rs`) | Dağıtılabilir tek binary, güçlü D-Bus (`zbus`) ekosistemi. Hızlı prototip isteyen Python + PyGObject ile başlayabilir. |
| UI | **GTK4** + `libadwaita` | Olgun, çoğu masaüstünde mevcut, CSS ile şekillendirilebilir. |
| Overlay yerleşimi | **`gtk4-layer-shell`** (Wayland `wlr-layer-shell`) | Panel/overlay'i ekran kenarına sabitler. wlroots tabanlı kompozitörler (Sway, Hyprland, river) destekler. |
| D-Bus | **`zbus`** | MPRIS, UPower, bildirimler, logind için async D-Bus. |
| Ses | **PipeWire** (`pipewire-rs`) / PulseAudio fallback | Sistem ses seviyesi. |

### ⚠️ Kompozitör kısıtı (önemli)
`wlr-layer-shell` **wlroots** tabanlı kompozitörlerde çalışır (Sway, Hyprland,
river, Wayfire). **GNOME (Mutter) ve KDE** layer-shell'i tam desteklemez →
oralarda X11 fallback (`_NET_WM_STATE_ABOVE` + override-redirect) veya
masaüstüne özel uzantı gerekir. İlk hedef: **wlroots kompozitörleri**.

## Durum

**M0 iskeleti başladı** (kod mevcut). Üst-ortada, üstte duran, hover ile genişleyen
pill + katmanlı modül yapısı (`model`/`geometry`/`interaction`/`ui`/`main`).
Now-playing/pil/bildirim servisleri henüz stub (bkz. [ROADMAP.md](ROADMAP.md)).

> ⚠️ Bu kod **Linux/Wayland'da** derlenip çalıştırılmalı. macOS makinesinde
> derlenemez (GTK4 + wlr-layer-shell yok). Aşağıdaki adımlar bir wlroots
> kompozitörde (Sway, Hyprland, river) içindir.

## Çalıştırma (hazır binary)

En kolayı: **[GitHub Releases](https://github.com/serkancakmakk/HoscIsland/releases)**
sayfasından `linux-island-linux-x86_64.tar.gz` indir.

```bash
tar -xzf linux-island-linux-x86_64.tar.gz
cd linux-island
./linux-island
```

Binary tek başına çalışır (CSS gömülü). Gerekli **çalışma zamanı** koşulları:

- **GTK4 ≥ 4.12** ve **gtk4-layer-shell** kurulu olmalı:
  ```bash
  # Arch / Manjaro
  sudo pacman -S gtk4 gtk4-layer-shell
  # Fedora
  sudo dnf install gtk4 gtk4-layer-shell
  # Debian / Ubuntu (yeterince yeni GTK gerekir)
  sudo apt install libgtk-4-1 libgtk4-layer-shell0
  ```
- Bir **wlroots kompozitör** oturumu (Sway / Hyprland / river / Wayfire).
  **GNOME ve KDE'de layer-shell çalışmaz** (yukarıdaki kısıt notu).
- Opsiyonel (özelliklere göre, yoksa o özellik sessizce atlanır): `wpctl`
  (ses), `hyprctl`/`swaymsg` (pencere geçişi), `wl-clipboard` (pano),
  `xdg-utils` (`xdg-open`/`xdg-email`), `libcanberra`/`pulseaudio-utils`
  (Pomodoro bitiş sesi).

> Binary `x86_64` Linux içindir. ARM ya da farklı libc için kaynaktan derlemek
> gerekir (aşağı bkz.).

## Geliştirme

Gerekenler: Rust (rustup), GTK4 ≥ 4.12 geliştirme paketleri ve
`gtk4-layer-shell` kütüphanesi.

```bash
# Arch / Manjaro
sudo pacman -S rust gtk4 gtk4-layer-shell

# Fedora
sudo dnf install rust cargo gtk4-devel gtk4-layer-shell-devel

# Debian / Ubuntu (yeterince yeni GTK gerekir)
sudo apt install cargo libgtk-4-dev libgtk4-layer-shell-dev

# Derle & çalıştır (bir wlroots kompozitör oturumunda)
cd LinuxIsland
cargo run
```

## Dosyalar

- [ARCHITECTURE.md](ARCHITECTURE.md) — katmanlı mimari (macOS katmanlarının Linux karşılıkları).
- [ROADMAP.md](ROADMAP.md) — özellik-özellik port planı + kilometre taşları.
- `src/` — `main.rs` (orkestrasyon), `model.rs`, `geometry.rs`, `interaction.rs`, `ui/island.rs`.
- `data/style.css` — ada görünümü + collapse/expand animasyonu.
