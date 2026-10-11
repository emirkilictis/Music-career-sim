# Mimari ve Performans

## 1. Modüller

```
MusicCareerApp (Xcode projesi)
├── App            SwiftUI ekranları, view model'ler (@MainActor)
├── Persistence    GRDB: şema, migrasyonlar, sorgular, kayıt slotları, görsel deposu
├── GameContent    JSON konfigürasyon + yükleyici (türler, dönem tablosu, listeler, zorluk, sertifika eşikleri)
└── SimulationCore Swift Package — saf Swift, Foundation dışında bağımlılık yok,
                   SwiftUI ve GRDB bilmez, macOS/Linux'ta da derlenir ve test edilir
    └── SimCLI     headless komut satırı: seed ile N yıl simüle et, CSV/JSON döküm, benchmark
```

- `SimulationCore` soğuk veriye (örn. "X sanatçısının kataloğu") bir `WorldStore` protokolü
  üzerinden ulaşır. Uygulamada GRDB implementasyonu, testlerde bellek içi implementasyon kullanılır.
- Konfigürasyon değişmez değer tipleridir; sıcak yolda string anahtarlı arama yok
  (tür/pazar/format → integer ID veya enum, dizi indeksiyle erişim).

## 2. Concurrency (Swift 6 strict concurrency ilk günden açık)

```
@MainActor GameViewModel ──(Sendable komut)──▶ actor SimulationEngine
                                                 • sıcak dünya durumu BELLEKTE (açılışta bir kez yüklenir)
                                                 • simulateWeek() senkron, saf fonksiyon (içinde await yok)
                                                 • sonuç → DatabasePool.write (tek transaction)
                                                 • commit başarılıysa bellekteki durumu ilerlet
◀──(Sendable WeekSummary)────────────────────────
```

- **Actor reentrancy:** actor metodunda `await` olursa iki "Next Week" araya girebilir.
  Simülasyon actor içinde `await`'siz çalışır; UI'da açık durum makinesi (`idle` / `simulating`) tutulur.
- `DatabasePool` + WAL: yazma sürerken UI geçen haftayı okumaya devam eder.
- İleri sarma / yıl atlama: her hafta ayrı commit, haftalar arasında `Task.isCancelled` kontrolü,
  UI sadece ilerleme göstergesini günceller (her hafta ekranlar yeniden çizilmez).

## 3. Persistence

- PRAGMA: `journal_mode=WAL`, `synchronous=NORMAL` (uygulama çökmesinde veri kaybı yok;
  elektrik kesintisinde en fazla son hafta, önceki hafta geçerli kalır).
- Haftalık yazım **tek transaction**; `meta.currentWeek` güncellemesi aynı transaction'da.
- Hazırlanmış statement'lar tekrar kullanılır (GRDB önbelleği); sadece değişen satırlar yazılır.
- Hafta içinde oyuncunun verdiği kararlar (yayın planlama, post) anında kaydedilir.

### 3.1 Kayıt slotları
```
Application Support/Saves/
  <slotID>/career.sqlite (+ -wal, -shm)
  <slotID>/Assets/<hash>.heic, <hash>_thumb.heic
  <slotID>/summary.json      ← slot listesi ekranı için (sanatçı adı, yıl, hafta, avatar);
                               her hafta güncellenir, slot listesi büyük DB'leri açmaz
```
- Her slot ayrı kariyer; kayıt noktası yok.
- Canlı DB iCloud Documents ile senkronize edilmez (WAL bozulma riski).
  Cihazın kendi iCloud yedeği Application Support'u kapsar; ileride dışa aktarma `VACUUM INTO` ile.

## 4. Görsel pipeline'ı

1. `PhotosPicker` → kırpma ekranı (kare / yuvarlak / 16:9 / 4:5).
2. **ImageIO** ile küçültme (`CGImageSourceCreateThumbnailAtIndex`): orijinal belleğe tam açılmaz.
3. İki boyut kaydedilir: büyük (~1024 px, detay) ve küçük thumbnail (~200 px, liste satırları).
4. Dosya adı = içerik hash'i (aynı görsel bir kez saklanır); DB'de `asset` satırı + `refCount`.
5. `refCount` sıfıra düşen dosyalar silinir.
6. Görsel yoksa: isim + paletten deterministik gradient kapak (AI sanatçılar hep bununla).
7. Liste satırları her zaman thumbnail kullanır; görseller bellek içi küçük bir LRU önbellekte tutulur.

## 5. SwiftUI performansı

- Dev bir `@Observable GameState` yok; her ekranın kendi küçük view model'i ve sorgusu var.
- Haftalık yenileme tek "hafta değişti" sinyaliyle; geniş tablolarda GRDB `ValueObservation` yok.
- `Identifiable` için her zaman DB ID'si (`id: UUID()` üreten init'ler listeyi her seferinde sıfırdan çizdirir).
- Sayı biçimlendirme `.formatted()` / önbelleğe alınmış formatter ile; `body` içinde formatter oluşturulmaz.
- Uzun süreli `Task`'larda `[weak self]` veya iptal; view model'ler task'lar tarafından tutulmaz.
- Sayfalama keyset ile (`WHERE week < ? ORDER BY week DESC LIMIT 50`), `OFFSET` değil.
- Grafikler ay/yıl toplama tablolarından okunur; liste pozisyonunda bucket'ın en iyi değeri gösterilir.

## 6. Yerelleştirme

- String Catalog (`.xcstrings`), kaynak dil İngilizce, ek dil Türkçe.
- Konfigürasyondaki görünen isimler (türler, platformlar, formatlar) yerelleştirme anahtarıyla.
- Sayı/tarih: `FormatStyle` (compact notation dile göre); hafta gösterimi yerelleştirilmiş format.

## 7. Performans hedefleri (iPhone 16 Pro)

Hedefler eski cihazlar düşünülerek 3–4 kat sıkı tutulur. Ölçüm **Release (-O) build'de ve gerçek cihazda**
yapılır (Debug Swift sayısal kodda 10–100 kat yavaştır).

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
6. **Kalibrasyon raporu:** SimCLI ile dönem referanslarına karşı dağılımlar (simulation.md §12).

## 9. Debug ekranı ve log

- Faz süreleri `ContinuousClock` ile; fazlar `OSSignposter` ile işaretlenir (Instruments'ta görünür).
- Gösterilenler: toplam hafta süresi ve faz kırılımı, aktif şarkı sayısı, liste adayı sayısı,
  yazılan satır sayısı, dormant uzlaştırma sayısı, bellek.
- "Toplamları yeniden hesapla ve doğrula" aracı.
- Log: `os.Logger` kategorileriyle (debug seviyesi release'te kalıcı yazılmaz).

## 10. Geliştirme ortamı

- Geliştirme: M2 MacBook Air 8 GB + Xcode. Simülatör az kullanılır; test iPhone 16 Pro'da.
- `SimulationCore` ve `SimCLI` Mac olmadan da (Linux'ta) geliştirilip test edilebilir; Faz 0 buna uygundur.
- İleride TestFlight ile eski iPhone'lu test kullanıcıları.
