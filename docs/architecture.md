# Mimari ve Performans

Platform: **Flutter (Dart)** — iOS ve Android tek kod tabanından. Önce iOS'ta (iPhone 16 Pro)
test edilir; Android aynı koddan derlenir.

## 1. Modüller (monorepo)

```
music-career-sim/
├── app/                      Flutter uygulaması: ekranlar, state (Riverpod), yerelleştirme
├── packages/
│   ├── simulation_core/      SAF Dart — Flutter'a ve veritabanına bağımlı değil.
│   │                         Linux/macOS'ta `dart test` ile çalışır.
│   ├── game_content/         JSON konfigürasyon + yükleyici (türler, dönem tablosu, listeler,
│   │                         zorluk, sertifika eşikleri)
│   └── persistence/          SQLite (`sqlite3` paketi, elle SQL): şema, migrasyonlar, kayıt slotları, geçmiş
└── tools/
    └── sim_cli/              headless komut satırı: seed ile N yıl simüle et, CSV/JSON döküm, benchmark
```

- `simulation_core` soğuk veriye (örn. "X sanatçısının kataloğu") bir `WorldStore` arayüzü üzerinden
  ulaşır. Uygulamada SQLite implementasyonu, testlerde bellek içi implementasyon kullanılır.
- Konfigürasyon değişmez değer nesneleridir; sıcak yolda string anahtarlı arama yok
  (tür/pazar/format → integer ID veya enum, liste indeksiyle erişim).

## 2. Concurrency — uzun ömürlü simülasyon isolate'i

```
UI isolate (Flutter)                         Simülasyon isolate'i (uygulama açıkken hep yaşar)
  GameController ──(komut mesajı)──────────▶   • sıcak dünya durumu BELLEKTE (açılışta bir kez yüklenir)
   (Riverpod)                                  • simulateWeek() senkron, saf fonksiyon
                                               • sonuç → SQLite yazma bağlantısı (tek transaction)
                                               • commit başarılıysa bellekteki durumu ilerlet
  ◀──(WeekSummary mesajı: küçük, sadece özet)──
  Ekranlar kendi okuma bağlantısıyla sorgular (WAL sayesinde yazma sırasında okuma serbest)
```

- Isolate'ler bellek paylaşmaz; UI'a büyük nesne grafiği gönderilmez, sadece özet ve ID'ler.
- **Çift tıklama koruması:** UI'da açık durum makinesi (`idle` / `simulating`); simülasyon isolate'i
  komutları sırayla işler.
- İleri sarma / yıl atlama: her hafta ayrı commit; haftalar arasında iptal kontrolü;
  UI sadece ilerleme göstergesini günceller.

## 3. Persistence

- SQLite, `sqlite3` paketiyle doğrudan (Flutter'da `sqlite3_flutter_libs`). Drift kullanılmadı:
  kod üretimi istemiyor ve sıcak yazma yolunda tam kontrol veriyor. Migrasyonlar `PRAGMA user_version`
  ile numaralı SQL listesi (`packages/persistence/lib/src/schema.dart`).
- **Haftalık kayıt = sıcak dünya bloğu + değişenler + geçmiş** (uygulandı):
  - Aktif sanatçı/şarkı/albümler tek bir ikili blok (`hotState`) olarak yazılır — dağınık binlerce
    satır güncellemesi yerine tek ardışık yazım.
  - Durumu değişen veya yeni varlıklar (dirty) ilişkisel tablolara yazılır.
  - Aktif varlıkların ilişkisel satırları 13 haftada bir ve `flushActive()` ile (uygulama arka plana
    geçerken) tazelenir; arayüz güncel değerleri zaten bellekten alır.
  - Yüklemede ilişkisel satırlar okunur, sıcak blok üzerine uygulanır → bit düzeyinde aynı dünya.
  - WAL checkpoint'i otomatik değil, 13 haftada bir ve kapanışta yapılır (her checkpoint dosyayı senkronlar).
- PRAGMA: `journal_mode=WAL`, `synchronous=NORMAL` (uygulama çökmesinde veri kaybı yok;
  elektrik kesintisinde en fazla son hafta, önceki hafta geçerli kalır).
- Haftalık yazım **tek transaction**; `meta.currentWeek` güncellemesi aynı transaction'da.
- Hazırlanmış statement'lar tekrar kullanılır; sadece değişen satırlar yazılır.
- Hafta içinde oyuncunun verdiği kararlar (yayın planlama, post) anında kaydedilir.

### 3.1 Kayıt slotları
```
<uygulama destek klasörü>/Saves/
  <slotID>/career.sqlite (+ -wal, -shm)
  <slotID>/Assets/<hash>.jpg, <hash>_thumb.jpg
  <slotID>/summary.json      ← slot listesi ekranı için (sanatçı adı, yıl, hafta, avatar);
                               her hafta güncellenir, slot listesi büyük DB'leri açmaz
```
- Her slot ayrı kariyer; kayıt noktası yok.
- Canlı DB bulut senkronizasyon klasörüne konmaz (WAL bozulma riski). Cihaz yedekleri uygulama destek
  klasörünü kapsar; ileride dışa aktarma `VACUUM INTO` ile.

## 4. Görsel pipeline'ı

1. Galeriden seçim (`image_picker`) → kırpma ekranı (`image_cropper`; kare / yuvarlak / 16:9 / 4:5).
2. Küçültme arka planda (isolate), orijinal görsel UI belleğine tam açılmaz.
3. İki boyut kaydedilir: büyük (~1024 px, detay) ve küçük thumbnail (~200 px, liste satırları).
4. Dosya adı = içerik hash'i (aynı görsel bir kez saklanır); DB'de `asset` satırı + `refCount`.
5. `refCount` sıfıra düşen dosyalar silinir.
6. Görsel yoksa: isim + paletten deterministik gradient kapak (AI sanatçılar hep bununla).
7. Liste satırları her zaman thumbnail ve `cacheWidth` ile çizilir; görsel önbelleği sınırlıdır.

## 5. Arayüz performansı

- Dev, tek parça bir oyun durumu nesnesi yok; her ekranın kendi küçük provider'ı ve sorgusu var.
- Haftalık yenileme tek "hafta değişti" sinyaliyle; ekranlar sadece ihtiyaç duyduğu veriyi yeniden sorgular.
- Uzun listeler `ListView.builder` (tembel); satırlarda kararlı `Key` olarak DB ID'si; mümkün olan
  her yerde `const` widget.
- Sayı biçimlendiriciler (`NumberFormat`) önbelleğe alınır, `build` içinde oluşturulmaz.
- Stream/abonelik ve controller'lar `dispose` edilir (bellek sızıntısı).
- Sayfalama keyset ile (`WHERE week < ? ORDER BY week DESC LIMIT 50`), `OFFSET` değil.
- Grafikler (`fl_chart`) ay/yıl toplama tablolarından okunur; liste pozisyonunda bucket'ın en iyi
  değeri gösterilir.
- Arayüz kendi tasarım dilinde olur (istatistik kartları, listeler); iOS'ta Cupertino davranışları
  (geri kaydırma, kaydırma fiziği) korunur.

## 6. Yerelleştirme

- Flutter `gen-l10n` + ARB dosyaları; şablon dil İngilizce (`app_en.arb`), ek dil Türkçe (`app_tr.arb`).
- Konfigürasyondaki görünen isimler (türler, platformlar, formatlar) yerelleştirme anahtarıyla.
- Sayı/tarih: `intl` (`NumberFormat.compact(locale:)`); hafta gösterimi yerelleştirilmiş format.

## 7. Performans hedefleri (iPhone 16 Pro)

Hedefler eski ve ucuz Android cihazlar düşünülerek 3–4 kat sıkı tutulur. Ölçüm **profile/release
modunda ve gerçek cihazda** yapılır (Flutter debug modu JIT ile çalışır ve çok yavaştır).

| Senaryo | Hedef (iPhone 16 Pro) |
|---|---|
| Normal hafta (hesap + kayıt) | ≤ 50 ms |
| Yoğun çıkış haftası | ≤ 150 ms |
| 50 yıllık kayıtta normal hafta | ≤ 75 ms |
| 1 yıl atlama (52 hafta) | ≤ 4 s |
| Kayıt slotu açılışı | ≤ 1 s |

Bütçenin çoğu DB yazımı ve UI yenilemesine gider; 1.500 şarkının matematiği milisaniyenin altındadır.

## 8. Test ve benchmark (ilk günden)

1. **Altın determinizm testi:** seed X ile 520 hafta → final durum hash'i. Hash değişirse ya kasıtlıdır
   (`simulationVersion` artırılır) ya hatadır.
2. **Sürekli = kaydet-yükle testi:** 100 haftayı kesintisiz ve her hafta kaydet-yükle yaparak çalıştır;
   hash'ler birebir aynı olmalı.
3. **Stres testi (MegaCareer):** sentetik veri yazılmaz; gerçek simülasyon headless olarak sabit seed ve
   oto-oyuncu botuyla 2.600 hafta çalıştırılarak üretilir (binary dosya git'e konmaz, seed'den yeniden üretilir).
   İzlenen metrikler:
   - hafta numarasına göre **aktif küme boyutu → düz çizgi olmalı**
   - hafta numarasına göre simülasyon süresi → düz olmalı
   - DB boyutu → doğrusal, eğimi bilinen
   - bellek kullanımı, kayıt süresi, açılış süresi
4. **Regresyon eşiği:** N koşunun medyanı, göreli fark; belirgin yavaşlama inceleme olmadan birleştirilmez.
5. **Sorgu planı testi:** sıcak sorgularda `EXPLAIN QUERY PLAN` → büyük tablolarda `SCAN` yasak.
6. **Kalibrasyon raporu:** sim_cli ile dönem referanslarına karşı dağılımlar (simulation.md §14).

## 9. Debug ekranı ve log

- Faz süreleri `Stopwatch` ile; fazlar `dart:developer` `Timeline` ile işaretlenir (DevTools'ta görünür).
- Gösterilenler: toplam hafta süresi ve faz kırılımı, aktif şarkı sayısı, liste adayı sayısı,
  yazılan satır sayısı, dormant uzlaştırma sayısı, bellek.
- "Toplamları yeniden hesapla ve doğrula" aracı.
- Log sadece debug/profile modunda; release'te kapalı.

## 10. Geliştirme ortamı

- Geliştirme: M2 MacBook Air 8 GB + Flutter SDK + Xcode (iOS derlemesi için şart) + Android SDK.
- Test: iPhone 16 Pro. Android için ileride ucuz bir Android telefon önerilir (emülatör 8 GB RAM'de ağır).
- `simulation_core` ve `sim_cli` saf Dart olduğu için Mac olmadan da (Linux'ta) geliştirilip test
  edilebilir; Faz 0 buna uygundur.
- Mağazalar: App Store (yıllık geliştirici ücreti), Google Play (tek seferlik kayıt ücreti).

## 11. Uygulama içi satın alma (Premium)

- Flutter `in_app_purchase` eklentisi (App Store ve Google Play): aylık/yıllık abonelik + ömür boyu (tek seferlik) ürün.
- Abonelik bitişi çevrimdışıyken de doğru işlenmeli (son bilinen bitiş tarihi + kısa tolerans süresi).
- Kural: hak kaybı sadece **yeni** Premium kariyer/slot oluşturmayı engeller; mevcut kariyerler asla kilitlenmez.
- Haklar (entitlement) **kayıt dosyasında değil**, uygulama düzeyinde tutulur; açılışta mağazadan doğrulanır,
  çevrimdışıyken yerel önbellekten okunur. Sunucu yok.
- "Satın alımları geri yükle" butonu zorunlu.
- Premium kontrolü sadece kariyer oluşturma (başlangıç seçenekleri) ve slot sayısında yapılır;
  simülasyon çekirdeği Premium'dan habersizdir.

## 12. En önemli 10 performans kuralı

1. Tarihsel haftaları asla yeniden hesaplama.
2. Sadece aktif yayınları tam simüle et.
3. Liste adaylarını sırala, tarihteki her şarkıyı değil.
4. Kariyer toplamlarını artımlı tut.
5. İndeksli tarihsel sorgular için tasarlanmış veritabanı kullan.
6. Haftalık yazımları tek transaction'da topla.
7. Simülasyon çekirdeğini arayüzden bağımsız tut.
8. Arka plan AI sanatçılar için basitleştirilmiş simülasyon kullan.
9. Arayüz verisini tembel yükle; kariyerin tamamını belleğe alma.
10. Dev kariyerleri ilk günden benchmark et.

**Mevcut dünya** (küçük, aktif hesaplanan: aktif yayınlar, ilgili sanatçılar, yaklaşan olaylar, listeler)
ile **tarihsel dünya** (devasa, SQLite'ta, çoğunlukla değişmez, sadece istenince sorgulanır) ayrımı,
50 yıllık bir kariyerin 5 yıllık bir kariyer kadar hızlı çalışmasını sağlar.
