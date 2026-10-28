# Oyunu tarayıcıda çalıştırma (web sürümü, K218)

Web sürümü, oyunun telefon sürümüyle aynı kodudur. Tarayıcıda WebAssembly olarak çalışır.
Kayıtlar tarayıcının içinde (IndexedDB) tutulur; sunucu ya da hesap gerekmez.

## Desteklenen tarayıcılar

- **Hızlı yol (WebAssembly):** Chrome / Edge 119+, Firefox 120+, Safari 18.2+ (iPhone'da iOS 18.2+).
- **Eski tarayıcılar (K236):** Daha eski Safari ve Chrome oyunun JavaScript sürümünü açar. Oyun
  ve kayıtlar aynıdır, yalnız daha yavaştır: yeni kariyer yaklaşık 2 kat uzun sürer.
  - Oyunun 64 bit sayıları (rastgele sayılar, kayıt dosyası, kapak çizimi) orada iki 32 bitlik
    yarımla hesaplanır (`Word64`, `simulation_core/lib/src/rng.dart`). Sonuçlar bit bit aynıdır:
    `dart run tool/rng_digest.dart` ile `dart compile js` çıktısı karşılaştırılabilir.
- WebAssembly'yi hiç tanımayan çok eski bir tarayıcıda yükleme ekranında "Bu tarayıcı oyun için
  çok eski" yazar.

Açılışta bir hata olursa yükleme ekranında "Oyun açılamadı" ve hatanın metni çıkar (K235).
Arkadaşın bu metni gönderirse sorun bulunabilir.

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
  - İlk kaydedilmemiş değişiklikten en geç ~1 sn sonra (oyuncu durmadan hafta geçse de) ve
    sekme gizlenince ya da kapanırken bütün olarak IndexedDB'ye yazılır. Yazma başarısız olursa
    tekrar denenir.
  - Uygulama içi tarayıcılar (X, Instagram, TikTok…) kapanınca site verisini silebilir. Oyun
    böyle bir tarayıcıda açıldığında kariyer listesinin üstünde "Safari ya da Chrome'da aç"
    uyarısı çıkar.
- **Yedek (K219):** Kariyer listesinde ⋮ → Yedekle bir `.mcsave` dosyası indirir; ↺ ile (iPhone'da seçicide "Dosya Seç", F109) başka bir
  tarayıcıda, ana ekran uygulamasında ya da telefon uygulamasında geri yüklenir. iPhone'da
  tarayıcıdayken "Ana ekrana ekle" ipucu çıkar (Safari 7 gün açılmayan sitenin verisini
  silebilir; ana ekran uygulamasının deposu ayrıdır).
- **Paylaşım kartları** tarayıcının paylaşım ya da indirme penceresiyle paylaşılır.
