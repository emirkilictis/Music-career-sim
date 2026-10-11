# Oyun Tasarımı

Bu doküman oynanış kurallarını tanımlar. Formüllerdeki sabitler **örnektir**; gerçek
değerler `GameContent` konfigürasyonunda tutulur ve Faz 0 kalibrasyonunda ayarlanır.

## 0. Tasarım ilkesi: derinlik arka planda, yüzey sade

Simülasyon derin olacak ama **oyuncunun beynini yakmayacak**. Her yeni sistem bu kurallara uyar:

- **Akıllı varsayılanlar:** her kararın makul bir varsayılanı vardır; oyuncu hiçbir ayara dokunmadan da oynayabilir.
- **Az ama anlamlı karar:** bir ekranda birkaç önemli seçim; ince ayarlar "Gelişmiş" altında, isteğe bağlı.
- **Sayılar sonuç olarak gösterilir, girdi olarak istenmez:** oyuncu formül değil, sonuç görür
  ("Bu hafta 19,4M stream, #3 → #1").
- **Mikro yönetim yok:** tekrarlayan işler (her hafta post, her şehir için ayrı ayar) zorunlu değildir.
- Yeni bir özellik eklenmeden önce sorulur: "Bu, oyuncuya eğlenceli bir karar mı veriyor, yoksa sadece iş mi?"

## 1. Temel döngü

```
Hafta 14, 2007
→ Oyuncu karar verir (yayın planla, post at, kampanya seç, varyant ekle…)
→ "Next Week"
→ Simülasyon: stream, satış, radyo, listeler, hayran, para, olaylar
→ Bildirimler ("🔥 Mirrors #1'e yükseldi")
→ Hafta 15 başlar (otomatik kayıt yapılmıştır)
```

İleri sarma seçenekleri: 1 hafta, 4 hafta, 13 hafta, **1 yıl**, "bir sonraki planlı olaya kadar".

### 1.1 Yıl atlama
- Arka planda 52 hafta tek tek simüle edilir; geçmiş ve listeler eksiksiz kalır.
- Her hafta kaydedilir; iptal edilirse tutarlı bir haftada durur.
- **"Önemli olayda dur"** ayarları: #1 olma, planlı yayın haftası, ödül töreni, sertifika, rekor.
- Atlama sırasında oyuncu bir şey yapmadığı için sessizlik kuralları (beklenti, post etkisi) normal işler.
- Bitince **Yıl Özeti** ekranı: en çok dinlenen şarkılar, #1'ler, toplam stream/satış, kazanç, kırılan rekorlar.

## 2. Sanatçı durumu

Tek bir "popülerlik = 93" değişkeni yerine ayrı kavramlar:

| Değişken | Anlamı | Hız |
|---|---|---|
| Fame | Genel tanınırlık | Yavaş |
| Current Popularity | Şu anki kültürel gündem | Hızlı |
| Core Fans | Sadık hayranlar (her şeyi alır/dinler) | Yavaş |
| Casual Audience | Tanıyan ama bağlı olmayan kitle | Orta |
| Momentum | Kısa vadeli başarı ivmesi | Hızlı |
| Buzz | Postlar/olaylardan gelen geçici gündem | Çok hızlı (2–4 haftada söner) |
| Anticipation | Yeni proje beklentisi (bkz. §3) | Kurala bağlı |
| Legacy | Uzun vadeli katalog gücü | Çok yavaş |
| Followers | Sosyal medya takipçisi | Orta |

## 3. Era sistemi, beklenti ve ara verme

### 3.1 Era
Her albüm bir era açar: duyuru → teaser → lead single → çıkış → sonraki single'lar → deluxe → (turne) → era sonu.
Era bittiğinde (oyuncu yeni era başlatınca veya son yayından X hafta sonra) **era skoru** hesaplanır.

### 3.2 Era skoru — beklentiye göre
Başarı mutlak değil, **beklentiye göre** ölçülür. Süperstar için #5 çıkış flop, yeni sanatçı için zafer olabilir.

```
expected   = f(önceki eraların performansı, fame, çıkış anındaki hype)
actual     = era boyunca toplam birim + liste başarısı (zirve, #1 haftaları, Top 10 sayısı)
eraScore   = actual / expected
```

| eraScore | Sonuç |
|---|---|
| < 0.5 | **Flop** |
| 0.5 – 0.85 | Hayal kırıklığı |
| 0.85 – 1.15 | Normal |
| 1.15 – 2.0 | Başarılı |
| > 2.0 | Dev başarı (smash) |

### 3.3 Ara verme — beklenti (anticipation)

**Başarılı/normal eradan sonra** sanatçı yeni bir şey yayınlamıyorsa:

```
cap = anticipationCapBase × g(eraScore) × fameFactor      // dev era → yüksek tavan
her hafta:
    anticipation += (cap − anticipation) × buildRate      // buildRate ≈ 0.023 → ~2.5 yılda tavanın %95'i
// Tavana ulaşınca SABİT kalır. Asla düşmez.
```

- Aynı dönemde **current popularity yavaşça düşer** (monthly listeners ve katalog stream'leri azalır).
  Yani 7 yıl ara veren sanatçı gündemden düşer ama beklenti tavanda bekler.
- Comeback'te beklenti harcanır: albüm duyurusuyla birlikte rollout haftalarına yayılarak
  hype'a dönüşür; çıkış haftasında büyük ilk hafta patlaması verir.
- Örnek hedef davranış: FutureSex/LoveSounds (2006) → 7 yıl → The 20/20 Experience (2013) dev ilk hafta.

**Hayal kırıklığı eradan sonra:** tavan düşüktür.
**Flop eradan sonra:** beklenti birikmez (bkz. §4).

## 4. Flop ve Comeback Desteği

Flop'tan sonra **beklemek işe yaramaz**: beklenti birikmez, current popularity düşmeye devam eder.
Oyun oyuncuya yardım eder ve onu hızlı bir comeback'e iter.

### 4.1 Comeback Desteği
```
flop anında: supportLevel = 1.0 × difficulty.flopSupportMultiplier
her hafta (yeni yayın yoksa): supportLevel *= 0.97     // ~23 haftada yarıya iner
bir sonraki era başlayınca: destek etkileri bu eraya uygulanır ve biter
```

Etkiler (`supportLevel` ile ölçeklenir):
- **"Neden flop oldu?" raporu:** simülasyonun zaten hesapladığı faktörler kaydedilip gösterilir.
  Örnekler: "Rakip X aynı hafta albüm çıkardı", "Promosyon bütçesi düşüktü",
  "Türün bu yıl düşüşte", "Lead single zayıftı", "Çıkış tatil sezonuna denk geldi".
- **Redemption bonusu:** comeback lead single'ı makul kalitedeyse ekstra ilgi (underdog hikayesi).
- **Feat teklifleri:** rakip sanatçılardan düet teklifleri gelir.
- **Kampanya indirimi.**
- **Katalog viral şansı:** eski bir hitin yeniden gündeme gelme olasılığı artar.

### 4.2 Ölüm sarmalı koruması
- **Core fans alt sınırı:** sadık hayranlar her yayını belirli oranda dinler/satın alır.
  Bu yüzden ardışık flop'larda bile sanatçı sıfıra düşmez.
- Güçlü şarkı + iyi promosyon ile comeback her zaman mümkündür.
- Dozaj Faz 0/2 kalibrasyonunda ayarlanacak (destek çok güçlü olursa flop'un anlamı kalmaz).

## 5. Sosyal medya (2000 öncesi: Basın & TV)

### 5.1 Post atma
Oyuncu fotoğraf yükler (opsiyonel) + açıklama yazar → post atar.

```
silenceWeeks = currentWeek − max(lastPostWeek, lastReleaseWeek)
buzzGain     = basePostBuzz
             × followersFactor(followers)
             × (1 + k × log(1 + silenceWeeks))   // uzun sessizlik → büyük etki
             × postFatigue                        // spam'in etkisi azalır
postFatigue: her postta ×0.7, her hafta 1.0'a doğru toparlanır
```

- Post **buzz** üretir (2–4 haftada söner), takipçi kazandırır, beğeni/yorum sayısı gösterilir.
- Post **beklentiyi tüketmez**; beklenti sadece albüm duyurusu/rollout ile harcanır.
- Rollout içindeki teaser postlar beklentinin hype'a dönüşümünü hızlandırır.

### 5.2 Dönemlere göre kanal
Platformlar konfigürasyondan gelir (isimler kurgusal):

| Dönem | Kanal | Yüklenen fotoğraf nasıl görünür |
|---|---|---|
| 1980–1999 | Basın & TV (dergi, TV programı, müzik kanalı) | Dergi kapağı / basın fotoğrafı |
| 2003–2009 | Erken sosyal ağlar | Profil sayfası postu |
| 2010+ | Fotoğraf odaklı sosyal medya | Kare/4:5 post |
| 2018+ | Kısa video platformu (viral etkisi yüksek) | Video kapağı |

## 6. Yayınlar ve rollout

### 6.1 Yayın türleri
Single, EP, albüm, deluxe/edition, compilation. Her şarkı bir veya birden fazla
sanatçıya ait olabilir (**feat**).

### 6.2 Albüm oluşturma akışı
Başlık → kapak (yükleme) → tür → şarkı listesi → single seçimi → rollout planı →
formatlar → varyantlar → kampanya bütçesi → onay.

### 6.3 Rollout planı
Takvime planlanmış olaylar dizisi:
```
Duyuru → Teaser postlar → Lead single → Pre-save → Albüm çıkışı
       → 2./3. single → Deluxe → (Turne) → Era sonu
```
- "Çok fazla single" yorgunluğu **yoktur**.
- AI rakiplerin albüm planları da takvimde görünür; oyuncu çıkış tarihini rakiplere göre seçebilir.

### 6.4 Feat / düet
- Şarkının bir ana sanatçısı ve sıfır veya daha fazla featured sanatçısı vardır.
- Liste girişleri tüm kredili sanatçıların liste geçmişine yazılır.
- Kariyer özetinde "ana sanatçı olarak" ve "featured olarak" ayrı gösterilir
  (örn. "12 #1 single (+3 featured)").
- Faz 2'de feat teklif alma/verme oynanışı.

### 6.5 Varyantlar
- Edition (standard, deluxe, anniversary) ve fiziksel/dijital varyantlar (CD, renkli vinil, imzalı, mağaza özel…).
- Azalan getiri **talep havuzu** ile doğal oluşur: koleksiyoncu hayranların bir harcama
  kapasitesi vardır, her yeni varyant kalan talebin bir kısmını alır.
- Her varyantın ayrı çıkış haftası olabilir (albümü listede tutmak için varyantları
  haftalara yaymak oyuncu stratejisi olarak mümkündür).
- Kolay modda talep havuzu daha büyüktür.

## 7. Satış modeli — streaming döneminde de büyük satış

```
pureSales = superfanBuyers + casualBuyers

superfanBuyers = coreFans × superfanBuyRate × eraSuperfanFactor(yıl)   // dönem etkisi ZAYIF (≈0.6–1.0)
               × hype × collectorDemand(varyantlar)
casualBuyers   = casualAudience × eraCasualPurchaseRate(yıl)            // dönem etkisi GÜÇLÜ
               × interest
```

- 2000'de sıradan alıcılar da çok albüm alır; 2020'de neredeyse hiç almaz.
- Ama hayran tabanı büyük bir sanatçı 2024'te de milyonlarca saf satış yapabilir
  (sadık hayranlar + vinil + varyantlar).
- Formatlar dönemden gelir: plak, kaset, CD, dijital indirme, vinil dönüşü.

## 8. Dönemler (oyuncu açısından)

Mimari 1980'den itibaren destekler; içerik aşamalı eklenir (önce 2000+).
Her dönem farklı hissettirir:

| Dönem | Büyüme yolu |
|---|---|
| 80'ler | Radyo, plak/kaset, müzik kanalı videoları, dergi/TV |
| 90'lar | CD patlaması, radyo, müzik kanalı |
| 2000'ler | CD zirvesi → dijital indirme, erken sosyal ağlar |
| 2010'lar | Streaming yükselişi, video platformu, sosyal medya |
| 2020+ | Streaming hakimiyeti, kısa video viralleri, vinil dönüşü |

O dönemde var olmayan metrikler arayüzde gizlenir (örn. 2008'de monthly listeners yok).

## 9. Kariyer özeti ve geçmiş

Oyuncu için her şey haftalık ve kalıcı saklanır. Kariyer özeti:

- Toplam stream, video izlenmesi (views), radyo kitlesi
- Saf albüm satışı (fiziksel / dijital ayrı), dijital single satışı, fiziksel single
- Albüm birimleri (SEA/TEA dahil, dönem kurallarına göre)
- Sertifikalar (Gold / Platinum / Multi-Platinum / Diamond)
- #1 single, #1 albüm, #1'de kalınan haftalar, Top 10 sayısı (ana + featured)
- Kazanç ve gider

Görünümler: **tüm kariyer**, **yıl bazında**, **era bazında**, şarkı/albüm detayında haftalık grafik ve liste geçmişi.

## 10. Kayıt slotları

- Her slot **ayrı bir kariyerdir**.
- Her hafta otomatik kayıt; çökme olursa en fazla son hafta kaybolur, önceki hafta geçerli kalır.
- **Kayıt noktası yok, geri alma yok** — flop'un dönüşü yoktur.
- Simülasyon deterministik olduğundan, sonucu görmeden uygulamayı kapatıp açmak aynı haftayı
  aynı sonuçla tekrar üretir; hile ile sonuç değiştirilemez.
- Slot silme ve (ileride) dışa aktarma/yedek.

## 11. Kullanıcı görselleri

| Görsel | Kırpma |
|---|---|
| Albüm / single / EP / edition kapağı | Kare 1:1 |
| Sanatçı profil fotoğrafı | Yuvarlak |
| Sanatçı banner/header | ~16:9 |
| Sosyal medya profil fotoğrafı | Yuvarlak |
| Sosyal medya postu | Kare veya 4:5 |

- Galeriden seçilir (`PhotosPicker`), kırpma ekranında ayarlanır.
- **AI rakiplere görsel yüklenmez.** AI sanatçılar ve görselsiz yayınlar otomatik varsayılan
  görsel alır (isim + renk paletinden üretilen gradient).
- Görseller sadece cihazda kalır; oyun telifli içerik dağıtmaz.
- Arayüz "streaming uygulaması tarzında" olabilir; gerçek platform isimleri ve logoları kullanılmaz.
- Oyun görselin kalitesini değerlendirmez (satışa etkisi yok).

## 12. Zorluk

Ayrı motor yok; `DifficultyConfig` çarpanları:
pazarlama etkisi, hayran dönüşümü, hit şansı, decay, varyant talep havuzu, turne talebi,
**flop desteği gücü**, beklenti tavanı. Kolay mod ("Domination") güç fantezisine izin verir.

## 13. Dil

- Ana dil İngilizce, ek dil Türkçe.
- Kullanıcının girdiği isimler (albüm/şarkı adı) çevrilmez.
- Sayılar ve tarihler dile göre biçimlenir: "Week 14, 2007" / "2007, 14. Hafta"; "1.2M" / "1,2 Mn".

## 14. MVP dışı (sonraki fazlar)

Detaylı turne, ödül törenleri, ilişkiler, skandallar, plak şirketi sözleşmeleri, röportajlar, çok ülke.
