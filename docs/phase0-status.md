# Faz 0 Durumu

Simülasyon motorunun ilk çalışan sürümü. Arayüz ve veritabanı yok; amaç mimarinin
çalıştığını ve rakamların inandırıcı olduğunu kanıtlamak.

## Ne var

`packages/simulation_core` (saf Dart, Flutter/DB bağımlılığı yok):

| Dosya | İçerik |
|---|---|
| `rng.dart` | Counter-tabanlı deterministik rastgelelik: `(seed, hafta, varlık, amaç)` |
| `time.dart` | Mutlak hafta indeksi (oyun yılı = 52 hafta) |
| `config/era_table.dart` | 2000–2026 ABD pazar tablosu + liste kuralları (indirme 2005+, streaming 2007+/2012+, albüm birimleri 2015+) |
| `config/sim_config.dart` | Tüm denge sabitleri tek yerde |
| `model.dart` | Sanatçı (statlar, beklenti, era, enerji), şarkı (feat dahil), albüm, ekip, liste girişi |
| `actions.dart` | Şarkı yazma (statlar + ekip + şans + ilham anı + enerji/burnout), single/albüm yayınlama, era skoru ve beklenti |
| `lifecycle.dart` | ACTIVE ↔ DORMANT geçişleri, tembel birikim (lazy accrual) |
| `simulator.dart` | Haftalık pipeline: pazar normalizasyonu, stream/indirme/radyo/fiziksel, albüm satışı + TEA + SEA, US Songs (100) ve US Albums (200), recurrent kuralı, hayran/popülerlik |
| `ai.dart` | AI rakiplerin era planları (lead single → albüm → single'lar), feat, nüfus kontrolü, tier sıralaması |
| `bot.dart` | Kalibrasyon için basit bot oyuncu (aynı `Actions` API'si) |
| `world_hash.dart` | Determinizm testleri için durum hash'i |

`packages/persistence` (SQLite, `sqlite3` paketi):

| Dosya | İçerik |
|---|---|
| `schema.dart` | v1 şeması, numaralı migrasyonlar |
| `codec.dart` | Sanatçı/şarkı/albüm ↔ satır eşlemesi (tüm simülasyon alanları birebir) |
| `binary.dart` | Sıcak dünya bloğu için kompakt ikili satır kodlayıcı |
| `save_store.dart` | `SaveStore` (oluştur, yükle, haftalık atomik kayıt, flush, checkpoint) ve `SaveSlots` (slot klasörleri + `summary.json`) |

`tools/sim_cli`: N yıl simüle edip yıllık rapor basar; `--save dosya.sqlite` ile her hafta kaydeder ve
kayıt süresini ölçer.

```bash
cd tools/sim_cli
dart run bin/sim_cli.dart --start 2005 --years 20 --seed 42
dart run bin/sim_cli.dart --start 2005 --years 50 --seed 7 --quiet   # performans
dart run bin/sim_cli.dart --start 2005 --years 50 --seed 7 --quiet --save /tmp/c.sqlite   # + kayıt
```

## Testler (simülasyon 35/35, kayıt 8/8 geçiyor)

- Aynı seed → bit düzeyinde aynı dünya; farklı seed → farklı dünya
- Sanatçının kariyer stream toplamı = şarkılarının toplamı (aktif + tembel birikimli dormant)
  — bu test emekli sanatçıların sayaç hatasını yakaladı
- Aktif küme tarih büyürken sınırlı kalıyor
- Şarkı yazma: kalite sınırları, haftada en fazla 3 şarkı, burnout, ünlü prodüktör reddi
- Başarılı eradan sonra beklenti birikiyor ve **hiç düşmüyor**; flop'tan sonra birikmiyor
- Albüm şekli: iyi albüm satışını zayıftan en az 1,5 kat daha iyi koruyor; 40 şarkı ilk haftayı
  %15–80 arası artırıyor (4 kat değil)
- **Kayıt:** oluştur + yükle birebir aynı dünya; **kesintisiz oynamak = her 13 haftada kapatıp kayıttan
  açmak** (oyuncu hamleleriyle birlikte, bit düzeyinde aynı hash); kayıt ortasında çökme önceki haftayı
  bozmuyor; liste ve haftalık geçmiş sorgulanabiliyor; slot oluştur/listele/aç/sil
- Ücretsiz başlangıç $5K ile; **iş sadece para kazandırıyor** (enerji, şarkı hakkı, burnout, hayran
  aynı kalıyor); ödüllü reklam her hafta açık, haftada en fazla 3; Premium günlük bonus hesap başına
  günde bir kez (yeniden açınca da)
- Zorluk: Normal = kalibre edilmiş denge (çarpanlar 1); Kolay > Normal > Zor oyuncu hayranı,
  AI etkilenmiyor; zorluk ve iş/reklam sayaçları kayıttan aynen dönüyor
- Mega çıkış: doğru hamlelerle 2025'te 3M+ saf satış; aynı süperstar hamlesiz çok daha düşük;
  varyantları haftalara yaymak ikinci haftayı güçlendiriyor

## Performans (bu sunucu, AOT derleme)

50 yıllık simülasyon (2005–2054), seed 7: 78 bin şarkı, 7,7 bin albüm, 1.900 sanatçı.

| On yıl | ms/hafta | Aktif şarkı |
|---|---|---|
| 2005–2014 | 0,90 | 916 |
| 2015–2024 | 0,89 | 923 |
| 2025–2034 | 1,00 | 958 |
| 2035–2044 | 1,10 | 958 |
| 2045–2054 | 1,16 | 968 |

Aktif küme düz. Hafta maliyeti tarih uzunluğundan neredeyse bağımsız
(küçük artış, emekli sanatçıların katalog döngüsünden; ileride optimize edilebilir).
Bulunan ve düzeltilen büyüme kaynakları: AI nüfusunun şişmesi (nüfus kontrolü eklendi),
listeye giremeyen eski hitlerin aktif kalması (dormant eşiği yükseltildi).

## Bölgeler ve listeler (yapıldı)

3 bölge (Kuzey Amerika, Avrupa, Diğer) ve 9 liste (ABD/İngiltere/Global şarkı+albüm, platform
Global/Kuzey Amerika/Avrupa Top 50). Kalibrasyon (seed 42, 2024 medyan #1 haftalık stream):

| Liste | Gerçek (yaklaşık) | Simülasyon |
|---|---|---|
| ABD #1 şarkı | 40–60M | 68M (biraz yüksek) |
| İngiltere #1 şarkı | ~8–12M | 13M |
| Global #1 şarkı | ~100–150M | 138M |

Bilinen: İngiltere listesinde bir şarkı bir yılda 20 hafta #1 kalabildi (rekor ~16) — rekabet az,
ayarlanacak. Listeler artık quickselect ile sadece ilk N'yi sıralıyor (sonuç birebir aynı, ~%30 daha hızlı).

## Kayıt performansı (bu sunucu, 50 yıl, her hafta kayıt)

Bölgeler ve 9 listeyle birlikte (seed 7):

| On yıl | Simülasyon ms/hafta | Aktif şarkı / albüm | Kayıt ms/hafta |
|---|---|---|---|
| 2005–2014 | 1,8 | 1.034 / 299 | 26 |
| 2025–2034 | 2,1 | 1.078 / 391 | 34 |
| 2045–2054 | 2,9 | 1.154 / 435 | 40 |

Son 5 yılın kayıt dağılımı (ms/hafta): değişenler 2,8 · sıcak blok 10,3 · flush 2,1 · geçmiş 9,8 ·
commit 3,4 · checkpoint 13,6 (bu sunucuda fsync yavaş). Veritabanı 50 yılda 162 MB (9 listenin tam
geçmişi; ayrıntılı haftalık istatistikler yalnızca oyuncunun şarkı/albümleri için).

Albüm listeleri 100 sıraya indirildikten sonra (ABD ve Global): aktif albüm 207→313, simülasyon
1,7→2,4 ms/hafta (50 yıl).

Bölgesiz sürümde (karşılaştırma için) simülasyon ~1,0 ms, kayıt ~24 ms, DB 107 MB idi.
**Bilinen:** aktif şarkı/albüm sayısı 50 yılda %12 / %45 artıyor (global listelerin düşük
eşiklerine yakın katalog); süre de buna bağlı olarak artıyor. 100 yılda bile hedefin çok altında
ama sıkılaştırılmalı.

Bulunan ve düzeltilen: her hafta tüm aktif satırları `INSERT OR REPLACE` ile yazmak 50 ms'ye çıkıyordu
→ sıcak blok + değişenler + elle checkpoint ile ~24 ms. Emekli sanatçıların her hafta yazılmasını
önlemek için katalog hesapları tembel hale getirildi.

## Kalibrasyon (`dart run bin/calibrate.dart`, seed 42)

Yıllık medyanlar (haftalık), en uzun #1 serisi ve yılın en büyük ABD albüm çıkışı (AI dünyası):

| Yıl | ABD #1 stream | İng. #1 stream | Global #1 stream | ABD #1 albüm | ABD #100 albüm | En uzun #1 (ABD/İng./Global) | En büyük ABD çıkış |
|---|---|---|---|---|---|---|---|
| 2005 | 715K | 75K | 1,0M | 346K | 6K | 9/9/8 | 1,7M |
| 2010 | 2,6M | 692K | 4,5M | 115K | 3K | 6/9/6 | 488K |
| 2015 | 15,5M | 3,9M | 23,7M | 116K | 4K | 12/8/12 | 351K |
| 2020 | 39,2M | 9,7M | 70,6M | 121K | 9K | 15/8/11 | 489K |
| 2024 | 59,1M | 11,3M | 125,1M | 141K | 12K | 11/10/8 | 684K |
| 2025 | 59,0M | 10,1M | 119,8M | 160K | 12K | 15/9/12 | 1,1M |

Gerçek referanslar (yaklaşık): 2020'lerde ABD #1 40–60M, İngiltere #1 8–12M, global #1 100–150M;
uzun #1 serileri 2020'lerde 15–19 hafta. AI rakipler bilerek "mega era" kurmadığı için yılın en büyük
çıkışı gerçeğin biraz altında (karar: AI çok güçlü olmasın).

Oyuncu senaryoları (2025, süperstar başlangıç, ABD ilk hafta):

| Senaryo | ABD | Global |
|---|---|---|
| Hamlesiz (bağlılık 0,4, hype yok, tek edition) | 483K birim / 236K saf | 826K |
| İyi hamleler | 1,6M / 1,3M | 2,7M |
| Her şey doğru | **4,0M / 3,6M** (gerçek rekor ~4,0M / 3,5M) | 6,8M |

Bu turda yapılan ayarlar: albüm şarkılarına (single olmayan) hayran ilgisinin %60'ı; liste geri
beslemesi listede kalınan süreyle zayıflıyor; İngiltere "hızlandırılmış düşüş" (2017+, 10+ hafta →
stream yarım); Kuzey Amerika'da simüle edilmeyen repertuvar payı artırıldı; katalog seviyesi 10 yıllık
zaman sabitiyle çok yavaş azalıyor; süperstar başlangıç hayranları düşürüldü, koleksiyoncu etkisi artırıldı;
isim listeleri genişletildi.

**Oyuncunun şarkıları** AI ile aynı kurala göre kataloğa geçer (adalet: aksi halde oyuncunun eski
şarkıları bugünkü ünüyle tam hesaplanıp haksız avantaj sağlıyordu). Ama her şarkının "bu hafta"
rakamı katalog formülünden O(1) hesaplanır ve oyuncunun tüm yayınlanmış şarkıları için haftalık geçmiş
satırı yazılır — oyuncu her şarkısının haftalık grafiğini görür.

Performans (50 yıl, her hafta kayıtla): aktif şarkı 1.045 → 1.087 (düz), aktif albüm 206 → 354
(doyuma yaklaşıyor), simülasyon 2,5 → 3,5 ms/hafta, kayıt 24 → 41 ms/hafta, DB 171 MB.

## Kısa video viralleri (yapıldı)

Eski katalog şarkıları rastgele viral olup listelere tırmanabiliyor (game-design §7.3). Viral etki
şarkının yaşından bağımsız ayrı bir terim; trend 3 hafta büyüyüp söner; %12'si "dev viral". Test:
2016–2025 arasında 50'den fazla eski şarkı canlanıyor ve en az biri ABD Top 40'a giriyor.

## Zorluk ve ücretsiz başlangıç (yapıldı)

Mevcut kalibrasyon **Normal ("Gerçekçi")** zorluk olarak kabul edildi. `Difficulty` (Kolay / Normal / Zor)
sadece oyuncunun erişimini, hayran dönüşümünü ve şarkı kalitesini ölçekler; değer kayıt meta'sında.
Ücretsiz başlangıç $5K (`StartMoney.basic`); `Actions.setJob` (haftalık $350, başka etkisi yok) ve
`Actions.claimAdReward` (haftada en fazla 3 × $250). Premium günlük bonus: `SaveSlots.claimDailyBonus`
(gerçek gün, hesap başına, `account.json`) + `Actions.grantDailyBonus` ($5K). Bot oyuncu $5K'dan iş +
reklamla başlıyor (2015–2021 bot koşusu: 5 albüm, ~$4.6M). Başlangıç statları: `StartingStats`
(ücretsiz 30 puan / tavan 60, Premium 55 puan / tavan 70; `auto` ve `isValid`).

## Grup modu (yapıldı)

`ArtistKind` (solo / band / vocalGroup) ve üye listesi; oyuncu ve AI için. Tür; şarkı kalitesindeki stat
ağırlıklarını, otomatik stat dağıtımını, sadakat kazanımını/azalmasını ve hayran kaybını belirler.
Solo değerleri eski formülle birebir aynı. AI'nin ~%20'si grup. Kalibrasyon sonrası referanslar yerinde
(2025 süperstar: hamlesiz ABD 472K, max hamle 4.0M / 3.6M saf). Testler: üye sayısı kuralları, türe göre
otomatik statlar, AI grupları, vokal grubun daha hızlı sadakat kazanması, kayıttan aynen dönme.

## Kampanyalar ve playlist kayması (yapıldı)

`Campaign` (none / standard / intensive / global; $0 / $2K / $20K / $250K) `releaseSingle` ve
`releaseAlbum`'da seçilir, oyuncu peşin öder. Standart = 1 (AI ve kalibrasyon değişmedi). Güç
`playlistShare(yıl)` ile radyodan stream erişimine kayar. Editör playlist eklemeleri (orta/büyük) yayında
zarlanır, `WeekResult.playlistAdds` bildirir. `tools/sim_cli/bin/campaign_probe.dart` etkileri ölçer
(8 seed medyanı). Kalibrasyon referansları yerinde: 2025 süperstar max hamle + dev kampanya ABD 3.8M /
3.5M saf, hamlesiz 462K; ABD #1 2021 49M. Bot artık parasının %5'ini aşmayan en büyük kampanyayı seçiyor.

## Katalog derinliği düzeltmesi (yapıldı)

Dünya artık başlangıç yılı ne olursa olsun en geç 2002'den simüle edilir (`SimConfig.catalogStartYear`).
Önceden sadece 3 yıl önceden başlıyordu; streaming döneminde başlayan kariyerlerde eski şarkı kataloğu
olmadığından pazar az sayıda şarkıya bölünüyor, ABD #1 haftada ~350M stream alıyordu (gerçek ~40–55M).
Şimdi 2022'de ABD #1 ≈ 55M, global #1 ≈ 120M. Yeni kariyer kurulumu ~3–4 sn (ilerleme çubuklu).
Kalibrasyon (seed 42): 2025 süperstar hamlesiz ABD 272K birim / 221K saf, iyi hamle 1.2M,
max hamle + dev kampanya 3.5M / 3.4M saf.

## Albüm listesi dengesi (yapıldı)

Sebep: AI'nin orta seviye sanatçıları ortalama ~1,5 yılda bir albüm çıkarıyordu (yılda ~140 albüm/EP);
ilk haftası 60K+ olan albüm azdı, uzun soluklu hitler #1'de 15–20 hafta kalıyordu. Değişiklikler:
B grubu albümsüz döngü %35 → %20, albüm arası 50–130 → 30–90 hafta, vokal gruplar %40 daha sık;
süperstarlar aynı (2–4 yıl). Daha çok çıkış dinlenmeleri daha çok şarkıya böldüğü için liste geri
bildirimi (hitlerin playlist/radyo ivmesi) 0.04 → 0.10.

Sonuç (seed 42 ve 7, 2015–2025, `dart run bin/chart_churn.dart <seed> 2015 2025`):

| | Simülasyon | Gerçek (yaklaşık) |
|---|---|---|
| Yılda farklı #1 albüm | 22–37 (çoğu ~30) | 30–45 |
| En uzun #1 serisi | çoğu yıl 5–12 hf | 6–13 hf |
| Yılda farklı #1 şarkı | 11–19 | 10–19 |
| ABD / UK / Global #1 şarkı, haftalık (2020'ler) | 36–54M / 10–13M / 68–90M | 40–55M / ~10M / 70–125M |
| 2025 süperstar ABD ilk hafta (hamlesiz / iyi / max) | 279K / 1.4M / 3.9M | — / — / ~4.0M |

## Bilinen eksikler / sıradaki adımlar

1. Flop desteğinin etkileri (rapor, redemption, feat teklifleri), sosyal medya postları, kampanyalar:
   Faz 2'de (şu an sadece durum değişkenleri var).
2. Kolay/Zor çarpanlarının kalibrasyonu ve diğer zorluk çarpanları (flop desteği, beklenti tavanı vb.): Faz 2.
3. Katalog (dormant) şarkılar kalıcı seviyede kalıyor; on yıllar içinde çok yavaş azalma ileride
   dönüşümlü uzlaştırma ile eklenebilir.
4. Veritabanı boyutu (50 yılda ~170 MB) ve kayıt süresinin yavaş artışı: eski geçmişin aylık
   özetlere sıkıştırılması ileride.
5. Checkpoint'ler uygulamada boşta/arka planda yapılmalı (Faz 1).
6. ~~Albüm listesi fazla durağan~~ → düzeltildi (aşağıda).
