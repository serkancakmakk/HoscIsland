# HoscIsland

Mac için kendi **Dynamic Island / notch** uygulaması (Alcove · NotchNook · Boring Notch tarzı). AppKit + SwiftUI, Xcode olmadan SwiftPM ile derlenir.

## Özellikler
- 🎵 **Now Playing** — Music & Spotify: kapak, şarkı, ilerleme çubuğu (seek), ses, karıştır/tekrarla
- 💬 **WhatsApp** — gelen mesaj banner'ı (gönderen + metin) + okunmamış rozeti
- 🔋 **Şarj göstergesi** — kablo takınca pil + yüzde (Kapalı / Değişince / Her zaman)
- 📸 **Ekran görüntüsü önizleme** — kopyala / Finder / sil
- 📁 **Dosya rafı** — notch'a sürükle-bırak, dışarı sürükle
- ⚙️ **Ayarlar** — ekran seçimi + tüm özellikler aç/kapa
- Hover ile açılan ada, notch'a oturan saydam pencere, menü çubuğu geçirgen

## Derleme
```bash
./build.sh --run    # SwiftPM ile derler, .app paketler, sabit kimlikle imzalar, çalıştırır
```
Gereksinim: macOS 14+, Swift 6+ (Command Line Tools yeterli, Xcode gerekmez).

## İzinler
- **Otomasyon** (Music/Spotify) — Now Playing için
- **Tam Disk Erişimi** — WhatsApp bildirimlerini okumak için (Bildirim Merkezi DB)

Detaylar için [CHANGELOG.md](CHANGELOG.md).
