# Simülasyon Tasarımı

## 1. Temel ilkeler

1. **Haftalık tick.** İleri sarma ve yıl atlama da içeride haftalık tick'leri tek tek çalıştırır.
2. **Toplu (aggregate) simülasyon.** Bireysel dinleyici yok; nüfuslar formüllerle temsil edilir.
3. **Maliyet aktif dünyaya bağlıdır, tarihe değil.** Haftalık iş `O(aktif dünya)` olmalı,
   `O(tüm geçmiş)` asla. Hafta 2.000, hafta 50'den belirgin şekilde yavaş olmamalı.
4. **Deterministik.** Aynı durum + aynı seed → bit düzeyinde aynı sonuç (bkz. §10).
5. **Görünen sonuçları derin, görünmeyen sistemleri ucuz simüle et.**
6. **Hassasiyet görünürlükle orantılı.** Oyuncunun kataloğu (birkaç yüz şarkı) her hafta
   hesaplanabilir; O(N) tehlikesi AI dünyasının yüz binlerce şarkısından gelir.

## 2. Haftalık pipeline

`simulateWeek(state, config, seed) -> WeeklySimulationResult` saf bir fonksiyondur.

```
1. Planlı olayları çöz          (ScheduledEvent WHERE week = current)
2. AI aktivitesi                (planlanmış AI yayınları, Tier C arka plan üretimi)
3. Aktif kümeyi güncelle        (yeni yayınlar, reaktivasyonlar, demote/promote)
4. Sanatçı durumu               (buzz decay, beklenti birikimi, flop desteği decay, popülerlik)
5. Ham ilgi (attention)         aktif şarkılar için
6. Pazar normalizasyonu         → stream, indirme, fiziksel, radyo, video views (pazar başına)
7. Katalog ve dormant havuz     sanatçı bazında O(1) (bkz. §5)
8. Albüm tüketimi               saf satış + TEA + SEA (dönem kurallarıyla)
9. Listeler                     aday = aktif küme; dönem kurallarıyla puanlama ve sıralama
10. Sertifikalar                eşik geçişleri (O(1) kontrol)
11. Rekorlar                    sadece bu haftanın sonuçlarına bakarak
12. Era takibi                  era bitişi → eraScore, flop raporu faktörleri
13. Bildirimler                 sadece ilginç olaylar
→ WeeklySimulationResult → tek transaction ile kaydet
```

## 3. Pazar normalizasyonu (rekabet)

Mutlak formüller yıllar içinde enflasyona yol açar ve gerçek rekabet oluşturmaz.
Bunun yerine pazar payı modeli:

```
rawAttention_i = appeal_i × awareness_i × exposure_i × momentum_i × noise_i
share_i        = rawAttention_i / (Σ rawAttention_aktif + catalogPoolAttention)
streams_i      = marketTotalStreams(yıl) × (1 + α × hype_hafta) × share_i
```

- `marketTotalStreams(yıl)` dönem tablosundan gelir (§4).
- `α × hype` pazarın dev haftalarda biraz genişlemesine izin verir (tamamen sıfır toplamlı değil).
- Oyuncunun mega albümü rakiplerin payını gerçekten azaltır.
- Aynı model indirme, fiziksel single, radyo ve video için ayrı pazar toplamlarıyla uygulanır.

## 3.1 Bölgeler (uygulandı)

Her aktif şarkının ilgisi tek sefer hesaplanır, sonra ana sanatçının bölgesel kitle dağılımına göre
3 bölgeye bölünür. Her bölge kendi pazar büyüklüğü ve "simüle edilmeyen yerel repertuvar" payıyla
ayrı normalize edilir. Albüm satışları (süperfan, koleksiyoncu, sıradan alıcı) bölge bazında hesaplanır.
Dormant katalog ve tembel birikim bölge başına endekslerle tutulur. Bölge pazarları ABD tablosunun
yıllara göre çarpanlarıdır (`config/regions.dart`), böylece ABD kalibrasyonu korunur.

## 4. Dönem tablosu (`MarketEraConfig`)

Yıl bazlı konfigürasyon; ara yıllar interpolasyonla, son gerçek yıldan sonrası
doygunluğa giden projeksiyonla hesaplanır. Mimari 1980'den başlar.

Her yıl için:
- Pazar büyüklükleri: on-demand streaming, dijital indirme (albüm/single), fiziksel (plak/kaset/CD/vinil), radyo kitlesi, video izlenmesi
- `eraCasualPurchaseRate`, `eraSuperfanFactor` (bkz. game-design §10)
- Aktif formatlar ve fiyatlar
- Aktif sosyal kanallar
- **Liste kuralları versiyonu**
- Gösterilecek metrikler (örn. monthly listeners 2011+)

Liste kurallarındaki önemli dönüm noktaları (gerçek dünya, kalibrasyon için):

| Yıl | Değişiklik |
|---|---|
| 1991 | Satışlar perakende tarama verisiyle, radyo elektronik izlemeyle ölçülmeye başlar |
| 1998 | Single listesine sadece radyoda olan (ticari single'ı olmayan) şarkılar girebilir |
| 2005 | Dijital indirmeler single listesine dahil |
| 2007 | İlk (sınırlı) streaming verileri single listesine dahil |
| 2012–2013 | On-demand audio streaming ve video izlenmeleri single listesine dahil |
| 2014 | Albüm listesi albüm-eşdeğer birimlere geçer (TEA + SEA) |
| 2020 | Video verisi albüm birimlerine dahil, paket (bundle) kuralları sıkılaşır |

Dönem değerleri Faz 0'da doğrulanıp kalibre edilecektir.

## 5. Yaşam döngüsü ve tembel birikim

### 5.1 Durumlar

| Durum | Hesaplama | Kim |
|---|---|---|
| **ACTIVE** | Tam simülasyon, haftalık geçmiş satırı | Yeni, listede, promosyonda, viral, turne etkili |
| **CATALOG** | Ucuz formül, her hafta | Eski ama hâlâ anlamlı |
| **DORMANT** | Sanatçı bazında O(1), şarkı başına haftalık iş yok | Düşük aktivite |
| **FROZEN** | Hiç dokunulmaz (reaktive edilmedikçe) | Pratikte sıfır dinlenen AI şarkıları |

- **Oyuncunun şarkıları DORMANT/FROZEN'a düşmez**; en az CATALOG düzeyinde her hafta hesaplanır
  (oyuncu her şarkısı için "bu hafta X stream" görür).
- Geçişler **sadece aktif/katalog kümesinde** değerlendirilir; dormant şarkılar taranmaz.
- **Histerezis:** örn. 8 hafta eşiğin altında → düş; eşiğin 2 katını geç → yüksel.

### 5.2 Reaktivasyon — tamamen olay tabanlı
- **Yıldönümü:** yayın anında 10./20./25. yıldönümü için `ScheduledEvent` oluşturulur.
- **Sanatçı olayı** (comeback, ödül, turne, ölüm): `artistID` ile o sanatçının kataloğu sorgulanır.
- **Viral:** önce sanatçı legacy ağırlığıyla, sonra o sanatçının şarkılarından rastgele seçilir.
  Tüm şarkılar puanlanmaz.

### 5.3 Tembel birikim (lazy accrual)
Dormant şarkıların lifetime değeri her hafta yazılmaz.

```
// Sanatçı başına, her hafta O(1):
artist.catalogIndex       += artistCatalogStrength(w) × seasonal(w) × marketScale(w)
artist.weeklyDormantStreams = artist.sumDormantRate × artistFactor(w)

// Şarkı DORMANT'a geçerken (bir kez):
song.dormantRate       = sonHaftaStream / oHaftakiArtistFactor     // süreklilik: sıçrama yok
song.indexAtSettle     = artist.catalogIndex
song.lifetimeAtSettle  = song.lifetimeStreams
artist.sumDormantRate += song.dormantRate

// Okurken (yazmadan):
lifetime = lifetimeAtSettle + dormantRate × (artist.catalogIndex − indexAtSettle)
```

- **Dönüşümlü uzlaştırma:** her hafta `songID % 52 == week % 52` olan dormant şarkılar
  uzlaştırılır (lifetime yazılır, yavaş decay uygulanır, sertifika kontrol edilir).
  Bilinçli ve sınırlı bir `O(N_dormant / 52)` iş; FROZEN şarkılar dahil değildir.
- Reaktivasyonda şarkı önce uzlaştırılır, sonra ACTIVE olur.

## 6. Aktif küme ve albüm şarkıları

- Albüm **çıkış haftasında** tüm şarkıları tam simüle edilir (büyük albümün birçok şarkısının
  aynı anda listeye girmesi oyunun en heyecanlı anlarından).
- Sonrasında single olmayan şarkılar **albüm havuzuna** toplanır: albüm toplam stream'i
  hesaplanır, sabit ağırlıklarla şarkılara dağıtılır. Eşiği geçen şarkı havuzdan ayrılır.
- Hedef aktif küme: ~500–1.500 şarkı, oyun uzunluğundan bağımsız sabit.

## 7. Listeler

İlk listeler: US Songs (100), US Albums (200), Global Songs (200), Global Albums (200).
İsimler kurgusaldır.

### 7.1 Aday = aktif küme
İki ayrı sistem yerine tek kural:
**Puanı geçen haftaki son sıradaki girişin puanına yaklaşabilecek her şarkı aktif kümededir.**
- Kesme puanının %50'sinin altında N hafta kalan → CATALOG'a düşer.
- CATALOG tahmini kesmenin %70'ini geçerse → ACTIVE.
- DORMANT şarkı olay olmadan kesmeyi geçemez.

### 7.2 Kurallar
- Puanlama dönem kuralları versiyonuna göre (satış/indirme/stream/radyo/video ağırlıkları).
- **Recurrent kuralı:** uzun süredir listede ve alt sıralarda olan şarkılar düşer
  (örn. 20+ hafta ve #50 altı). Hem gerçekçi hem listeyi tıkamaz.
- Remix ve orijinal aynı şarkı olarak birleştirilir (Song seviyesi).
- Deluxe/edition'lar aynı albüm olarak sayılır (Album seviyesi).
- Eşitlik: önce puan, sonra ID (deterministik).

### 7.3 Saklama
Hesaplanan liste **asla yeniden hesaplanmaz**; satırlar değişmezdir (bkz. data-model).

## 8. AI sanatçılar

| Katman | Sayı | Simülasyon |
|---|---|---|
| Tier A — Büyük rakipler | 20–50 | Tam: eralar, rollout, katalog, kariyer, beklenti/flop |
| Tier B — Endüstri | 200–500 | Basitleştirilmiş: popülerlik, tür, yayın takvimi, yaklaşık hayran |
| Tier C — Arka plan | İstatistiksel | Bireysel değil; haftalık dağılımdan üretilen yayınlar |

- **Nüfus kontrolü:** emeklilik ve yeni sanatçı doğuşu konfigürasyonla dengelenir;
  aktif sanatçı sayısı sabit tavanda kalır (100 yıllık kariyerde dünya şişmez).
- Tier A'ya biri girince biri düşer.
- **Tier C yayınları kalıcı değildir**; sadece listeye girenler materyalize edilir
  (isimleri seed'den deterministik türetilir). Materyalizasyonda doğrulanabilir geçmiş
  (liste geçmişi) uydurulmaz.
- **AI albüm planları önceden takvime yazılır** → oyuncu rakip çıkışlarını görür.
- AI sanatçılara görsel yüklenmez (otomatik varsayılan görsel).
- UI'da açılabilen her bilgi ya saklanır ya seed'den türetilebilir
  (Tier B profili açılıyorsa Tier B'nin artımlı toplamları vardır).

## 9. Hype, beklenti, buzz, flop
Kurallar game-design.md §5–§7'dedir. Simülasyon tarafında hepsi sanatçı başına O(1) güncellemedir.
Flop raporu için era boyunca katkı faktörleri (rakip çakışması, promosyon, tür trendi,
şarkı kalitesi, sezon) sanatçı-era başına küçük bir tabloda biriktirilir.

## 10. Determinizm

- **Counter-tabanlı RNG:** `rng(seed, week, entityID, purpose)` — örn. SplitMix64 hash.
  Saklanacak tek RNG durumu seed'dir; paralelleştirme sonucu değiştirmez.
- **Hash tabanlı koleksiyonların (`HashMap`/`HashSet`) iterasyon sırasına asla güvenme.**
  RNG tüketen veya sıralama yapan döngüler ID'ye göre sıralı listelerle çalışır.
- Sayımlar 64-bit `int`, paralar `int` cent (web hedefi yok; native'de `int` 64-bit). Paralel float toplamaları deterministik sırada yapılır.
- **Sürekli = kaydet-yükle:** simülasyon için gereken her durum DB'dedir; bellekte sadece
  türetilmiş önbellek tutulabilir.
- Kayıtta `simulationVersion` ve `contentVersion` saklanır.

## 11. Oyuncu aksiyonları: şarkı yazma ve stat gelişimi

Şarkı yazma haftalık tick'in parçası değildir; oyuncu aksiyonu olarak anında çözülür ve kaydedilir
(kurallar game-design §4).

- Kalite zarı deterministiktir: `rng(seed, week, artistID, "song", buHaftaYazılanSıra)`.
  Uygulamayı kapatıp açmak aynı sonucu verir.
- Kalite ve çekicilik özellikleri (ticari, radyo, streaming, viral, kalıcılık) yazım anında belirlenir
  ve değişmez; yayından sonraki performansı bunlar + pazar belirler.
- Stat gelişimi: ilgili aksiyon başına küçük artış, `artış = taban × (1 − stat/100)` (100'e yaklaştıkça yavaşlar).
- Yaratıcı enerji haftalık tick'te sanatçı başına O(1) toparlanır; burnout bitişi `burnoutUntilWeek` ile tutulur.
- AI sanatçılar şarkı yazma ekranını kullanmaz; yayınları kendi kalite dağılımlarından üretilir.

## 12. Decay ve legacy

```
momentumNextWeek = momentum × decayFactor(şarkı.kalıcılık, zorluk)
                 + promosyon + viralBoost + (ileride) turneBoost
```
- Promosyon = kampanya çarpanları (`SimConfig.campaignExposure/campaignRadio`): Standart = 1;
  güç `playlistShare(yıl)`'a göre erişim (stream) ile radyo arasında bölünür. Editör playlist eklemesi
  yayında bir kez zarlanır (`playlistBoost`, haftalık ×0,85 söner).
- Her şarkının decay davranışı farklıdır (kalıcılık özelliği).
- Yayın yaşlandıkça performansı giderek **legacy**'ye bağlanır. Legacy: kariyer başarısı, liste ömrü,
  hayran tabanı, kültürel etki, (ileride) ödüller. Eski şarkılar tam hit simülasyonu gerektirmeden
  gerçekçi şekilde stream toplamaya devam eder (katalog ve dormant formülleri).

## 13. Zorluk
`DifficultyConfig` çarpanları; ayrı motor yoktur.

## 14. Kalibrasyon referans tablosu (Faz 0)

Rakamlar inandırıcı olmazsa istatistik odaklı oyun çalışmaz. Simülasyon dönemlere göre
gerçek dünya referanslarına ayarlanır. Aşağıdaki değerler **yaklaşıktır ve Faz 0'da
doğrulanacaktır**:

| Referans | Yaklaşık değer |
|---|---|
| 2000, süperstar pop albüm ilk hafta (saf satış) | ~2,4M |
| 2006, büyük pop albüm ilk hafta | ~0,7M |
| 2013, uzun aradan sonra dev comeback albüm ilk hafta (The 20/20 Experience) | 968k (doğrulandı) |
| 2014, süperstar albüm ilk hafta | ~1,3M |
| 2015, rekor albüm ilk hafta | ~3,4M |
| 2024, süperstar albüm ilk hafta (birim) | ~2,6M (büyük kısmı saf satış) |
| 2020'ler, US #1 şarkı haftalık on-demand stream | onlarca milyon (doğrulanacak) |
| 2020'ler, US Top 100 son sıra haftalık stream | doğrulanacak |

Kalibrasyon araçları: headless CLI ile seed başına N yıl simülasyon, CSV döküm, dağılım grafikleri
(ilk hafta birimleri, liste ömrü, #1 hafta sayısı dağılımı, era skoru dağılımı).
