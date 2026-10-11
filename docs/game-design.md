# Oyun Tasarımı

Bu doküman oynanış kurallarını tanımlar. Formüllerdeki sabitler **örnektir**; gerçek
değerler `game_content` konfigürasyonunda tutulur ve Faz 0 kalibrasyonunda ayarlanır.

## 0. Tasarım ilkesi: derinlik arka planda, yüzey sade

Simülasyon derin olacak ama **oyuncunun beynini yakmayacak**. Her yeni sistem bu kurallara uyar:

- **Akıllı varsayılanlar:** her kararın makul bir varsayılanı vardır; oyuncu hiçbir ayara dokunmadan da oynayabilir.
- **Az ama anlamlı karar:** bir ekranda birkaç önemli seçim; ince ayarlar "Gelişmiş" altında, isteğe bağlı.
- **Sayılar sonuç olarak gösterilir, girdi olarak istenmez:** oyuncu formül değil, sonuç görür
  ("Bu hafta 19,4M stream, #3 → #1").
- **Mikro yönetim yok:** tekrarlayan işler (her hafta post, her şehir için ayrı ayar) zorunlu değildir.
- Yeni bir özellik eklenmeden önce sorulur: "Bu, oyuncuya eğlenceli bir karar mı veriyor, yoksa sadece iş mi?"

### Nihai hedef
Oyuncu absürt bir geç kariyer durumuna ulaşabilmeli ve "Next Week" yine anında olmalı:
```
32 stüdyo albümü · 14 deluxe · 126 single · 41 #1 single · 29 #1 albüm
92 milyar stream · 4,8 milyar $ turne hasılatı · 2.500 hafta
```
Geçmişin büyüklüğü kariyeri daha etkileyici yapmalı, oyunu yavaşlatmamalı.

## 1. Temel döngü

```
Hafta 14, 2007
→ Oyuncu karar verir (şarkı yaz, yayın planla, post at, kampanya seç…)
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

## 2. Kariyer başlangıcı

### 2.1 Sanatçı oluşturma (tek ekran + isteğe bağlı detay)
- İsim, profil fotoğrafı (opsiyonel), tür, başlangıç yılı, zorluk.
- **Stat dağıtımı:** her stat 25'ten başlar, oyuncu 30 puan dağıtır (başlangıçta hiçbir stat 60'ı geçemez).
  "Otomatik dağıt" butonu var.
- **Kariyer yolu** ve **başlangıç seviyesi** (aşağıda).

### 2.2 Kariyer yolu

| Yol | Para | Gelir payı | Erişim (radyo, playlist, pazarlama) | Kısıt |
|---|---|---|---|---|
| **Bağımsız** | Düşük | Kayıtlı müzik gelirinin %100'ü | Düşük | Yok, tam özgürlük |
| **Küçük plak şirketi** | Avans (peşin nakit) | %50 (avans bu paydan geri ödenir) | Orta-yüksek | Sözleşme: 2 albüm |

- Sözleşme bitince yenile veya bağımsızlaş.
- Faz 2: başarılı sanatçıya **büyük şirket teklifi** olayı gelir (net rakamlarla kabul/ret).
  Detaylı sözleşme pazarlığı yok.

### 2.3 Başlangıç seviyesi

| Seviye | Ünlülük / hayran | Statlar | Erişim |
|---|---|---|---|
| Bilinmeyen | Sıfır | Normal dağıtım | Ücretsiz |
| Yerel çıkış | Küçük yerel kitle | Normal dağıtım | Ücretsiz |
| Yükselen yıldız | Orta | +bonus | **Premium** |
| Süperstar | Çok yüksek | Yüksek | **Premium** |

| Başlangıç parası | Erişim |
|---|---|
| Düşük | Ücretsiz |
| Rahat | Ücretsiz |
| Milyoner | **Premium** |

- Ünlü başlangıçta diskografi boştur; profil "kariyer burada başlıyor" der (uydurma geçmiş yok).
- Gelir modeli için bkz. §20.

## 3. Sanatçı

### 3.1 Statlar (0–100)

| Stat | Neyi etkiler |
|---|---|
| **Söz yazarlığı** | Şarkı kalitesinin ana bileşeni |
| **Vokal** | Kalite, radyo uygunluğu |
| **Prodüksiyon** | Prodüktör tutulmazsa kaliteye katkı |
| **Sahne** | TV/ödül performansları (ileride turne) |
| **Karizma** | Sosyal medya ve promosyon etkisi |

- Statlar kullanıldıkça artar (şarkı yazdıkça söz yazarlığı, performans yaptıkça sahne…).
  100'e yaklaştıkça artış yavaşlar.
- Ekranda sade gösterilir: 5 çubuk.

### 3.2 Sanatçı durumu

Tek bir "popülerlik = 93" değişkeni yerine ayrı kavramlar:

| Değişken | Anlamı | Hız |
|---|---|---|
| Fame | Genel tanınırlık | Yavaş |
| Current Popularity | Şu anki kültürel gündem | Hızlı |
| Core Fans | Sadık hayranlar (her şeyi alır/dinler) | Yavaş |
| Casual Audience | Tanıyan ama bağlı olmayan kitle | Orta |
| Momentum | Kısa vadeli başarı ivmesi | Hızlı |
| Buzz | Postlar/olaylardan gelen geçici gündem | Çok hızlı (2–4 haftada söner) |
| Anticipation | Yeni proje beklentisi (bkz. §5) | Kurala bağlı |
| Legacy | Uzun vadeli katalog gücü | Çok yavaş |
| Followers | Sosyal medya takipçisi | Orta |
| **Hayran bağlılığı (devotion)** | Hayran kitlesinin ne kadar sadık olduğu; süperfan alımı ve koleksiyoncu talebini belirler (bkz. §10.1) | Era sonlarında değişir, zamanla hafifçe azalır |
| Yaratıcı enerji | Şarkı yazma kapasitesi (bkz. §4.4) | Haftalık toparlanır |

Oyuncuya gösterilen ana sayılar: monthly listeners (dönem uygunsa), hayran, takipçi, para,
popülerlik göstergesi. Diğerleri arka planda.

## 4. Şarkı yapma

### 4.1 Akış (tek ekran)
1. Tür / ruh hali (varsayılan: sanatçının türü)
2. Ortak söz yazarı (opsiyonel)
3. Prodüktör (opsiyonel; seçilmezse sanatçı kendisi prodükte eder)
4. Stüdyo bütçesi: Düşük / Orta / Yüksek
5. "Yaz ve kaydet" → sonuç kartı

Şarkı **kasaya** (vault) girer; daha sonra single, EP veya albüme konur.

### 4.2 Ekip (NPC'ler)
- Prodüktörler ve söz yazarları sanatçı değil, ayrı bir NPC listesidir (isimler kurgusal).
- Her birinin: beceri (0–100), uzmanlık türü, şarkı başı ücret, **minimum ünlülük şartı**
  ("Bu prodüktör seninle çalışmak için Fame ≥ 40 istiyor") vardır.
- Yıllar içinde yenileri gelir, eskileri emekli olur.
- Feat sanatçılar ekip değildir; kaliteye az, kitleye çok etki eder (bkz. §8.4).

### 4.3 Kalite: beceri + ekip + şans
```
yazım      = 0.6 × max(sanatçı.sözYazarlığı, ortakYazar) + 0.4 × min(…)
prodüksiyon= prodüktör.beceri  (yoksa sanatçı.prodüksiyon × 0.8)
beceri     = 0.45 × yazım + 0.30 × prodüksiyon + 0.25 × sanatçı.vokal

kalite = beceri
       + bütçeBonusu        (Düşük 0, Orta +3, Yüksek +6)
       + türUyumu           (prodüktör uzmanlığı eşleşirse +3)
       + şans               (normal dağılım, σ ≈ 8)
       + ilhamAnı           (%4 olasılıkla +20 — tecrübesiz biri de şaheser yazabilir)
       − enerjiCezası       (bkz. §4.4)
```

Kalite tek başına hit demek değildir. Her şarkının ayrıca kaliteyle kısmen ilişkili, kısmen
rastgele özellikleri vardır: ticari çekicilik, radyo uygunluğu, streaming uygunluğu,
viral potansiyel, kalıcılık. Böylece farklı hit türleri doğar:
- Dev giriş yapıp hızla düşen şarkı
- #38'den girip yavaşça #1'e tırmanan şarkı
- Hiç büyük single olmayan ama katalogda yıllarca dinlenen şarkı

**Gösterim:** oyuncu kesin kaliteyi görmez; ekibin tahmini bir not görür (örn. "B+").
İyi prodüktörün tahmini daha isabetlidir. Gerçek potansiyel yayından sonra ortaya çıkar.

Şans deterministiktir: aynı seed ve aynı hafta aynı sonucu verir; uygulamayı kapatıp açarak
yeniden zar atılamaz.

### 4.4 Yaratıcı enerji ve burnout
- Tek bir çubuk (0–100). Her şarkı ~20 enerji harcar; yazılmayan her hafta ~12 toparlanır.
- Haftada en fazla 3 şarkı yazılabilir.
- Enerji 30'un altındaysa kalite cezası artar.
- Enerji 0'a düşerse **burnout**: 3 hafta şarkı yazılamaz (bildirim gelir).
- Sade tutulur: başka yorgunluk sistemi yok.

### 4.5 Kasa (vault)
- Yayınlanmamış şarkılar kasada bekler.
- Eski kasa şarkıları ileride deluxe veya yıldönümü edition'ına "From the Vault" olarak konabilir.

## 5. Era sistemi, beklenti ve ara verme

### 5.1 Era
Her albüm bir era açar: duyuru → teaser → lead single → çıkış → sonraki single'lar → deluxe → (turne) → era sonu.
Aktif eralar daha güçlü gündem üretir; eski eralar kataloğa dönüşür.
Era bittiğinde (oyuncu yeni era başlatınca veya son yayından X hafta sonra) **era skoru** hesaplanır.

### 5.2 Era skoru — beklentiye göre
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

### 5.3 Ara verme — beklenti (anticipation)

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
- Örnek hedef davranış: FutureSex/LoveSounds (2006) → 7 yıl → The 20/20 Experience (2013), ilk hafta 968k.

**Hayal kırıklığı eradan sonra:** tavan düşüktür.
**Flop eradan sonra:** beklenti birikmez (bkz. §6).

## 6. Flop ve Comeback Desteği

Flop'tan sonra **beklemek işe yaramaz**: beklenti birikmez, current popularity düşmeye devam eder.
Oyun oyuncuya yardım eder ve onu hızlı bir comeback'e iter.

### 6.1 Comeback Desteği
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

### 6.2 Ölüm sarmalı koruması
- **Core fans alt sınırı:** sadık hayranlar her yayını belirli oranda dinler/satın alır.
  Bu yüzden ardışık flop'larda bile sanatçı sıfıra düşmez.
- Güçlü şarkı + iyi promosyon ile comeback her zaman mümkündür.
- Dozaj Faz 0/2 kalibrasyonunda ayarlanacak (destek çok güçlü olursa flop'un anlamı kalmaz).

## 7. Sosyal medya (2000 öncesi: Basın & TV)

### 7.1 Post atma
Oyuncu fotoğraf yükler (opsiyonel) + açıklama yazar → post atar.

```
silenceWeeks = currentWeek − max(lastPostWeek, lastReleaseWeek)
buzzGain     = basePostBuzz
             × followersFactor(followers)
             × karizmaFactor(sanatçı.karizma)
             × (1 + k × log(1 + silenceWeeks))   // uzun sessizlik → büyük etki
             × postFatigue                        // spam'in etkisi azalır
postFatigue: her postta ×0.7, her hafta 1.0'a doğru toparlanır
```

- Post **buzz** üretir (2–4 haftada söner), takipçi kazandırır, beğeni/yorum sayısı gösterilir.
- Post **beklentiyi tüketmez**; beklenti sadece albüm duyurusu/rollout ile harcanır.
- Rollout içindeki teaser postlar beklentinin hype'a dönüşümünü hızlandırır.

### 7.2 Dönemlere göre kanal
Platformlar konfigürasyondan gelir (isimler kurgusal):

| Dönem | Kanal | Yüklenen fotoğraf nasıl görünür |
|---|---|---|
| 1980–1999 | Basın & TV (dergi, TV programı, müzik kanalı) | Dergi kapağı / basın fotoğrafı |
| 2003–2009 | Erken sosyal ağlar | Profil sayfası postu |
| 2010+ | Fotoğraf odaklı sosyal medya | Kare/4:5 post |
| 2018+ | Kısa video platformu (viral etkisi yüksek) | Video kapağı |

## 8. Yayınlar ve rollout

### 8.1 Yayın türleri
Single, EP, albüm, deluxe/edition, compilation. Her şarkı bir veya birden fazla
sanatçıya ait olabilir (**feat**).

### 8.2 Albüm oluşturma akışı
Başlık → kapak (yükleme) → tür → şarkı listesi (kasadan) → single seçimi → rollout planı →
formatlar → varyantlar → kampanya → onay. Her adımın akıllı varsayılanı vardır.

### 8.3 Rollout planı
Takvime planlanmış olaylar dizisi:
```
Duyuru → Teaser postlar → Lead single → Pre-save → Albüm çıkışı
       → 2./3. single → Deluxe → (Turne) → Era sonu
```
- "Çok fazla single" yorgunluğu **yoktur**.
- AI rakiplerin albüm planları da takvimde görünür; oyuncu çıkış tarihini rakiplere göre seçebilir.

### 8.4 Feat / düet
- Şarkının bir ana sanatçısı ve sıfır veya daha fazla featured sanatçısı vardır.
- Feat sanatçının kitlesi şarkıya erişim kazandırır; kaliteye etkisi küçüktür.
- Liste girişleri tüm kredili sanatçıların liste geçmişine yazılır.
- Kariyer özetinde "ana sanatçı olarak" ve "featured olarak" ayrı gösterilir
  (örn. "12 #1 single (+3 featured)").
- Faz 2'de feat teklif alma/verme oynanışı.

### 8.5 Varyantlar
- Edition (standard, deluxe, anniversary) ve fiziksel/dijital varyantlar (CD, renkli vinil, imzalı, mağaza özel…).
- Her varyant etkiler: koleksiyoncu talebi, saf satış, üretim maliyeti, kâr.
- Azalan getiri **talep havuzu** ile doğal oluşur: koleksiyoncu hayranların bir harcama
  kapasitesi vardır, her yeni varyant kalan talebin bir kısmını alır.
- Her varyantın ayrı çıkış haftası olabilir (albümü listede tutmak için varyantları
  haftalara yaymak oyuncu stratejisi olarak mümkündür).
- Kolay modda talep havuzu daha büyüktür.

## 9. Kampanyalar

Tek seçim + isteğe bağlı aksiyonlar:

| Seviye | Maliyet | Etki |
|---|---|---|
| Promosyonsuz | 0 | — |
| Standart | Düşük | Orta |
| Yoğun | Yüksek | Yüksek |
| Dev global kampanya | Çok yüksek | Çok yüksek |

İsteğe bağlı aksiyonlar (dönemde mevcutsa): müzik videosu, TV performansı, ödül töreni performansı,
radyo kampanyası, playlist kampanyası, sosyal medya kampanyası, indirim, remix.
Plak şirketindeyse erişim çarpanı kampanyaları güçlendirir.

## 10. Satış modeli — streaming döneminde de büyük satış

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

### 10.1 Mega çıkışlar: doğru hamleler

Streaming döneminde de milyonlarca ilk hafta satışı mümkündür, ama sadece doğru hamlelerle.
Üç kaldıraç birlikte çalışır:

1. **Hayran bağlılığı (devotion, 0–1).** Başarılı eralar bağlılığı artırır
   (dev başarı > başarı > normal), hayal kırıklığı ve flop azaltır; zamanla hafifçe aşınır.
   Etkisi **konvekstir**: orta bağlılık normal satış verir, sadece en sadık kitleler mega çıkış yapar.
   Bağlılık arttıkça beklenti çıtası da yükselir — sadık kitleyi tatmin etmek zorlaşır.
2. **Beklenti / hype.** Başarılı eradan sonra ara verip beklentiyi biriktirmek (§5.3).
3. **Varyantlar.** Her ek varyant sadık hayranlara ekstra kopya satar; her yeni varyant bir
   öncekinin ~%60'ı kadar etkilidir. Etki koleksiyon kültürüne bağlıdır: CD döneminde düşük,
   vinil dönüşüyle (2015+) yüksek. Varyantları haftalara yaymak sonraki haftaları güçlendirir.

Kalibrasyon (2025, süperstar, testlerle doğrulandı):

| Senaryo | İlk hafta |
|---|---|
| Hiçbir hamle yok (bağlılık 0,4, hype yok, tek edition) | ~0,6M birim |
| İyi hamleler (bağlılık 0,7, biraz hype, 4 edition) | ~1,7M birim |
| Her şey doğru (bağlılık 1,0, büyük hype, 8 edition, yayılmış) | ~4,2M birim / 3,7M saf |

Gerçek referans: 2025'te rekor ilk hafta ~4,0M birim / ~3,5M saf satış.

## 11. Dönemler (oyuncu açısından)

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

## 12. Finans

| Gelir | Gider |
|---|---|
| Streaming | Kayıt (stüdyo bütçesi, prodüktör/söz yazarı ücreti) |
| Satış (fiziksel, dijital) | Müzik videoları |
| Radyo/yayın hakları (basit) | Pazarlama/kampanya |
| Merch | Üretim (fiziksel varyantlar) |
| (İleride) turne | (İleride) turne |

- Plak şirketindeyse kayıtlı müzik gelirinin payı ve avans geri ödemesi otomatik uygulanır.
- Karmaşık telif/royalty hesapları yok.

## 13. Kariyer özeti ve geçmiş

Oyuncu için her şey haftalık ve kalıcı saklanır. Kariyer özeti:

- Toplam stream, video izlenmesi (views), radyo kitlesi
- Saf albüm satışı (fiziksel / dijital ayrı), dijital single satışı, fiziksel single
- Albüm birimleri (SEA/TEA dahil, dönem kurallarına göre)
- Sertifikalar (Gold / Platinum / Multi-Platinum / Diamond)
- #1 single, #1 albüm, #1'de kalınan haftalar, Top 10 sayısı (ana + featured)
- Aktif yıl, albüm/single sayısı, ödüller (ileride), turne hasılatı (ileride)
- Kazanç ve gider

Görünümler: **tüm kariyer**, **yıl bazında**, **era bazında**, şarkı/albüm detayında haftalık grafik ve liste geçmişi.

**Monthly listeners** bireysel dinleyici saklamadan, benzersiz dinleyici formülüyle yaklaşık hesaplanır
(güncel stream aktivitesi, aktif şarkı sayısı, dinleyici örtüşmesi, katalog gücü). Sadece inandırıcı davranması yeterli.

## 14. Rekorlar ve sertifikalar

Oyun dünyası genelinde (oyuncu + AI) artımlı tutulan rekorlar:
- #1'de en çok hafta
- En büyük ilk hafta albüm satışı / albüm birimi
- En büyük streaming haftası
- Listede en uzun kalan şarkı
- Aynı anda en çok Top 10 şarkı / Top 10 albüm
- En çok #1 albüm, en çok #1 single
- En çok monthly listeners
- En çok kariyer stream'i
- (İleride) en yüksek hasılatlı turne

Rekor kırıldığında bildirim + rekor geçmişi (kim, ne zaman, kaç). Her hafta tüm geçmiş taranmaz.

## 15. Bildirimler

Hafta sonunda sadece ilginç olaylar gösterilir:
```
🔥 Mirrors #1'e yükseldi.
📈 Albüm satışları %34 arttı.
🏆 Streaming rekorunu kırdın.
💿 FutureSex/LoveSounds Top 10'a geri döndü.
📉 Single #3'ten #8'e düştü.
💿 Albümün Platinum oldu.
😮‍💨 Burnout: 3 hafta şarkı yazamazsın.
```

## 16. Ana ekranlar

| Ekran | İçerik |
|---|---|
| **Ana sayfa** | Mevcut hafta, popülerlik, monthly listeners, hayran, para, şu anki en büyük şarkı, güncel albüm, yaklaşan olaylar, "Next Week" |
| **Stüdyo** | Şarkı yaz (§4), kasa, yaratıcı enerji |
| **Diskografi** | Albüm / EP / single kartları (kapaklarla) |
| **Yayın detayı** | Çıkış tarihi, zirve, listede hafta, #1'de hafta, bu hafta stream, toplam stream, saf satış, sertifika; grafikler: haftalık stream, liste geçmişi, satış, radyo |
| **Listeler** | Sekmeler: US Songs, US Albums, Global Songs, Global Albums, Sanatçı sıralaması |
| **Takvim** | Planlı yayınlar, videolar, performanslar, rakip çıkışları, (ileride) turne ve ödüller |
| **Sosyal** | Profil, postlar, takipçi |
| **Kariyer** | Kariyer özeti (§13), yıl/era görünümleri, rekorlar |
| **Sanatçı profili** | Streaming uygulaması tarzı profil: banner, fotoğraf, monthly listeners, popüler şarkılar, diskografi |

Örnek yayın detayı:
```
MIRRORS
Çıkış: Hafta 11, 2013 · Zirve: #1 · Listede: 68 hafta · #1'de: 14 hafta
Bu hafta: 19,4M stream · Toplam: 2,31B stream · Saf satış: 5,2M
```

## 17. Kayıt slotları

- Her slot **ayrı bir kariyerdir**.
- Her hafta otomatik kayıt; çökme olursa en fazla son hafta kaybolur, önceki hafta geçerli kalır.
- **Kayıt noktası yok, geri alma yok** — flop'un dönüşü yoktur.
- Simülasyon deterministik olduğundan, sonucu görmeden uygulamayı kapatıp açmak aynı haftayı
  aynı sonuçla tekrar üretir; hile ile sonuç değiştirilemez.
- Ücretsiz sürümde sınırlı slot (örn. 3), Premium'da sınırsız.
- Slot silme ve (ileride) dışa aktarma/yedek.

## 18. Kullanıcı görselleri

| Görsel | Kırpma |
|---|---|
| Albüm / single / EP / edition kapağı | Kare 1:1 |
| Sanatçı profil fotoğrafı | Yuvarlak |
| Sanatçı banner/header | ~16:9 |
| Sosyal medya profil fotoğrafı | Yuvarlak |
| Sosyal medya postu | Kare veya 4:5 |

- Galeriden seçilir, kırpma ekranında ayarlanır.
- **AI rakiplere görsel yüklenmez.** AI sanatçılar ve görselsiz yayınlar otomatik varsayılan
  görsel alır (isim + renk paletinden üretilen gradient).
- Görseller sadece cihazda kalır; oyun telifli içerik dağıtmaz.
- Arayüz "streaming uygulaması tarzında" olabilir; gerçek platform isimleri ve logoları kullanılmaz.
- Oyun görselin kalitesini değerlendirmez (satışa etkisi yok).

## 19. Zorluk

Ayrı motor yok; `DifficultyConfig` çarpanları:
pazarlama etkisi, hayran dönüşümü, hit şansı, decay, varyant talep havuzu, radyo/playlist kabulü,
**flop desteği gücü**, beklenti tavanı, (ileride) turne talebi.

**Kolay — "Domination" modu** güç fantezisine bilerek izin verir (örnek yönler, değerler kalibre edilecek):
pazarlama etkisi +%50, hayran dönüşümü +%35, çıkış momentumu +%25, daha yavaş decay,
daha güçlü varyantlar, daha kolay radyo/playlist kabulü, daha güçlü flop desteği.

## 20. Gelir modeli

- Oyun **ücretsiz indirilir ve tek başına eksiksiz oynanır.**
- **Premium üyelik** üç şekilde satılır: **aylık**, **yıllık** ve **ömür boyu** (tek seferlik).
  Rakip oyunlarda aylık üyelik kabul görmüş bir model; ömür boyu seçeneği aboneliği sevmeyen oyuncular için.
- Premium şunları açar: Yükselen yıldız ve Süperstar başlangıcı, Milyoner başlangıcı,
  sınırsız kayıt slotu. Üyeliğin değerini sürdürmek için yeni içerikler (dönemler, özellikler)
  ilk olarak veya sadece Premium'a gelebilir.
- **Üyelik bitince hiçbir kariyer kilitlenmez.** Premium ile başlatılmış kariyerler ve mevcut slotlar
  oynanmaya devam eder; sadece **yeni** Premium başlangıç ve ücretsiz limitin üstünde **yeni** slot açılamaz.
- Simülasyonun kendisi (zorluk, formüller) Premium'dan etkilenmez; para ile oyun içi güç satılmaz,
  sadece başlangıç seçenekleri ve kolaylıklar.
- Satın alımları geri yükleme (restore) zorunludur.
- Reklam yok (karar verilmedi).

## 21. Dil

- Ana dil İngilizce, ek dil Türkçe.
- Kullanıcının girdiği isimler (albüm/şarkı adı) çevrilmez.
- Sayılar ve tarihler dile göre biçimlenir: "Week 14, 2007" / "2007, 14. Hafta"; "1.2M" / "1,2 Mn".

## 22. Sonraki fazlar

- **Turne (Faz 3, sade):** birkaç bölge + mekan büyüklüğü + bilet fiyatı; setlist isteğe bağlı.
  Albüm/katalog stream'lerini, bölgesel popülerliği ve hayran dönüşümünü artırır. Beklentiyi bozmaz.
- **Ödüller (Faz 3):** yıllık; Yılın Albümü, Yılın Kaydı, Yılın Şarkısı, En İyi Pop Albüm,
  En İyi Pop Performans, Yılın Sanatçısı. Uygunluk verisi yıl boyunca biriktirilir; tören anında tüm
  yayınlar taranmaz.
- Büyük şirket teklifleri (Faz 2), ek ülkeler, endüstri trendleri.
- **Kapsam dışı (şimdilik):** ilişkiler, skandallar, detaylı sözleşme pazarlığı, röportajlar.
