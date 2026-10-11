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

`tools/sim_cli`: N yıl simüle edip yıllık rapor basar.

```bash
cd tools/sim_cli
dart run bin/sim_cli.dart --start 2005 --years 20 --seed 42
dart run bin/sim_cli.dart --start 2005 --years 50 --seed 7 --quiet   # performans
```

## Testler (`dart test`, 14/14 geçiyor)

- Aynı seed → bit düzeyinde aynı dünya; farklı seed → farklı dünya
- Sanatçının kariyer stream toplamı = şarkılarının toplamı (aktif + tembel birikimli dormant)
  — bu test emekli sanatçıların sayaç hatasını yakaladı
- Aktif küme tarih büyürken sınırlı kalıyor
- Şarkı yazma: kalite sınırları, haftada en fazla 3 şarkı, burnout, ünlü prodüktör reddi
- Başarılı eradan sonra beklenti birikiyor ve **hiç düşmüyor**; flop'tan sonra birikmiyor
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

## Kalibrasyon (seed 42, 2005–2024)

| Ölçüt | Gerçek (yaklaşık) | Simülasyon | Durum |
|---|---|---|---|
| #1 şarkı haftalık stream, 2023–24 | 40–60M | 54–58M | ✓ |
| #100 şarkı haftalık stream, 2024 | ~2–4M | 1,9M | ~ |
| #1 şarkı haftalık indirme, 2008–12 | ~200–400K | 295–390K | ✓ |
| #1 albüm medyan haftalık, 2005 | ~250K | 295K | ✓ |
| #1 albüm medyan haftalık, 2020'ler | ~150–250K | 140–180K | ✓ |
| Yılın en büyük çıkışı, 2005–08 | ~1,0–1,2M | 1,03–1,34M | ✓ |
| Yılın en büyük çıkışı (AI dünyası), 2009–14 | ~0,8–1,3M | 0,35–0,95M | ~ biraz düşük |
| Yılın en büyük çıkışı (AI dünyası), 2015–25 | 0,6–4M | 0,5–1,5M | ~ AI mega çıkış nadiren yapıyor |
| **Oyuncu, 2025, her hamle doğru** | rekor ~4,0M birim / 3,5M saf | **4,24M / 3,71M** | ✓ |
| Oyuncu, 2025, hamle yok (süperstar) | — | 0,62M | ✓ mantıklı |
| #200 albüm haftalık birim, 2005–14 | ~3–7K | 0,8–1,2K | ✗ düşük |
| #200 albüm haftalık birim, 2020'ler | ~4–6K | 6,7–11,5K | ~ biraz yüksek |
| Yılda farklı #1 şarkı sayısı | ~10–15 | ~15 | ✓ |

## Bilinen eksikler / sıradaki adımlar

1. ~~Mega çıkışlar~~ → **çözüldü:** hayran bağlılığı (konveks), varyantlar (koleksiyon kültürü,
   azalan getiri, haftalara yayma) ve beklenti birlikte doğru hamlelerle 4M'lik çıkışlara izin veriyor
   (game-design §10.1). AI rakipler bu stratejiyi bilinçli kurmadığı için onların zirveleri gerçeğin biraz
   altında; istenirse Tier A için "büyük era" planlaması eklenebilir.
2. **Albüm listesi kuyruğu** satış döneminde ince (katalog albüm satışları).
3. Oyuncu şarkıları da dormant'a düşüyor; dokümana göre en az CATALOG kalmalı.
4. Flop desteğinin etkileri (redemption, feat teklifleri vb.), sosyal medya postları,
   kampanyalar henüz yok (sadece durum değişkenleri var).
5. Global listeler yok (sadece US).
6. Persistence (SQLite/drift) yok → "sürekli = kaydet-yükle" testi bekliyor.
7. İsim çeşitliliği az (aynı şarkı isimleri sık tekrar ediyor).
8. Bot oyuncu 20 yılda fame 0,43'e ulaşıyor, #1 yok — oyuncu dengesi zorluk ayarlarıyla birlikte ele alınacak.
