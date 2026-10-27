# Oyunu tarayıcıda çalıştırma (web sürümü, K218)

Web sürümü, oyunun telefon sürümüyle aynı kodudur. Tarayıcıda WebAssembly olarak çalışır.
Kayıtlar tarayıcının içinde (IndexedDB) tutulur; sunucu ya da hesap gerekmez.

## Desteklenen tarayıcılar

Chrome / Edge 119+, Firefox 120+, Safari 18.2+ (iPhone'da iOS 18.2+). Daha eski bir tarayıcıda
oyun açılmaz, "tarayıcı desteklenmiyor" ekranı çıkar. Oyunun 64 bit sayıları JavaScript'e
düşen eski yolda çalışmıyor.

## Yayın (GitHub Pages)

Her push'ta `.github/workflows/web.yml` oyunu derler ve
<https://emirkilictis.github.io/Music-career-sim/> adresine koyar. Repo ayarlarında bir kez
**Settings → Pages → Build and deployment → Source: GitHub Actions** seçili olmalı.

## Derleme

```
cd app
flutter build web --wasm
```

Çıktı `app/build/web/` klasörüne yazılır. Bu klasör olduğu gibi herhangi bir statik
sunucuya konabilir: GitHub Pages, Netlify, Cloudflare Pages ya da kendi sunucun.
`sqlite3.wasm` dosyası `app/web/` içinde durur ve derlemeyle birlikte kopyalanır.

- **Alt klasörde yayınlanacaksa** (ör. GitHub Pages'te `kullanici.github.io/Music-career-sim/`),
  yolu derleme sırasında ver: `flutter build web --wasm --base-href /Music-career-sim/`.
- **Yerelde denemek için:** `cd app/build/web && python3 -m http.server 8765`, sonra
  <http://localhost:8765>. Dosyayı çift tıklayarak (`file://`) açmak çalışmaz.
- **İsteğe bağlı:** Sunucu `Cross-Origin-Opener-Policy: same-origin` ve
  `Cross-Origin-Embedder-Policy: require-corp` başlıklarını gönderirse çizim çok iş parçacıklı
  çalışır. Bu başlıklar olmadan da oyun sorunsuz çalışır.

## Telefondan farkları

- **Oyun arayüzle aynı iş parçacığında çalışır** (tarayıcıda isolate yok).
  - Uzun işler bölünerek ilerler: dünya kurulumu, zaman atlama.
  - Ekran donmaz, ilerleme çubuğu akar.
  - Sekmeler ilk açıldıklarında yüklenir.
- **Kayıtlar tarayıcıya ve siteye bağlıdır:** başka tarayıcıda ya da cihazda görünmez.
  "Site verilerini temizle" kayıtları siler.
  - Kayıt dosyası bellekte tutulur.
  - Her kayıttan ~2 sn sonra ve sekme gizlenince ya da kapanırken bütün olarak IndexedDB'ye
    yazılır.
- **Paylaşım kartları** tarayıcının paylaşım ya da indirme penceresiyle paylaşılır.
