# Music Career Simulator — Tasarım Dokümanları

iOS için tek oyunculu, istatistik odaklı müzik kariyeri simülasyonu.
Oyuncu solo bir sanatçıyı haftalık adımlarla yönetir: single, EP, albüm, varyant,
rollout, sosyal medya, listeler, sertifikalar, rekorlar ve on yıllara yayılan bir katalog.

> "Bir albüm çıkardım. Şimdi bu hafta ona tam olarak ne olduğunu görmek istiyorum."

Bu klasör, ilk ChatGPT planının incelenip revize edilmiş halidir. İlk plandaki
genel yön (SwiftUI + saf Swift simülasyon çekirdeği + SQLite/GRDB, aktif/tarihsel
dünya ayrımı, deterministik seed, baştan stres testi) korunmuş; tespit edilen
sorunlar düzeltilmiş ve oyun tasarımı kararları eklenmiştir.

## Dokümanlar

| Dosya | İçerik |
|---|---|
| [game-design.md](game-design.md) | Oynanış: hype/beklenti, flop desteği, sosyal medya, rollout, dönemler, satış modeli, kayıt slotları, görsel yükleme, dil |
| [simulation.md](simulation.md) | Haftalık pipeline, pazar normalizasyonu, dönem tablosu, yaşam döngüsü, tembel birikim, listeler, AI katmanları, determinizm |
| [data-model.md](data-model.md) | Varlıklar (feat dahil), SQLite şeması, index'ler, geçmiş saklama stratejisi |
| [architecture.md](architecture.md) | Modüller, concurrency, persistence, UI performansı, görsel pipeline'ı, test ve benchmark |

## Karar Kaydı

Bu kararlar alınmıştır; değiştirmek için bilinçli bir revizyon gerekir.

| # | Karar |
|---|---|
| K1 | **Teknoloji:** SwiftUI + saf Swift `SimulationCore` (Swift Package, UI'dan bağımsız, Linux'ta da derlenir) + SQLite/**GRDB**. SwiftData kullanılmayacak. |
| K2 | **Kayıt:** Her slot ayrı bir kariyerdir. Her hafta otomatik kayıt. **Kayıt noktası yok, flop geri alınamaz.** |
| K3 | **Beklenti (anticipation):** Başarılı eradan sonra ara verilirse birikir, ~2–3 yılda tavana ulaşır, **sonra sabit kalır, hiç düşmez** (JT: FutureSex/LoveSounds → 7 yıl → The 20/20 Experience). Tavanı son eranın başarısı belirler. |
| K4 | **Flop:** Flop eradan sonra beklemek işe yaramaz, beklenti birikmez. Oyun "Comeback Desteği" ile oyuncuya yardım eder; destek beklendikçe azalır, oyuncuyu hızlı comeback'e iter. Sadık hayranlar alt sınır oluşturur (ölüm sarmalı yok). |
| K5 | **Sosyal medya postları hype'ı etkiler.** Uzun sessizlikten sonraki post büyük etki yapar; spam'in etkisi azalır. 2000 öncesi dönemlerde kanal "Basın & TV" olur. |
| K6 | **"Çok fazla single" yorgunluğu eklenmeyecek.** |
| K7 | **Albüm rollout planlama** oyunun çekirdeğindedir (duyuru → teaser → lead single → çıkış → sonraki single'lar → deluxe → era sonu). |
| K8 | **Kullanıcı görsel yükler:** albüm/single/EP/deluxe kapakları, sanatçı profil fotoğrafı ve banner'ı, sosyal medya profil fotoğrafı ve postları. **AI rakiplere görsel yüklenmez** (otomatik varsayılan görsel). |
| K9 | **Feat / düet** veri modelinde ilk günden vardır. |
| K10 | **Stream ve satışlar yıla göre** gelir (dönem tablosu). Mimari 1980'den itibaren destekler. |
| K11 | Streaming döneminde de **büyük saf satış mümkündür**: satış = sıradan alıcılar (dönem etkisi güçlü) + sadık hayran/koleksiyoncular (dönem etkisi zayıf). |
| K12 | **Yıl atlama** vardır: arka planda 52 hafta tek tek simüle edilir; "önemli olayda dur" seçeneği; sonunda yıl özeti ekranı. |
| K13 | **Tüm geçmiş saklanır:** oyuncunun her şarkısının haftalık stream/satış/liste geçmişi ve sanatçının kariyer özeti (yıl ve era bazında). |
| K14 | **Dil:** İngilizce (ana dil) + Türkçe. |
| K15 | **Telif:** Gerçek sanatçı görseli/kaydı/markası gönderilmez. Varsayılan sanatçılar kurgusal; platform isimleri kurgusal (Spotify/Apple Music/Billboard adları ve logoları kullanılmaz, arayüz tarzı benzer olabilir). |
| K16 | **Cihazlar:** geliştirme M2 MacBook Air (8 GB), test iPhone 16 Pro. Performans hedefleri eski cihazlar düşünülerek 3–4 kat sıkı tutulur. |

## Yol Haritası

### Faz 0 — Simülasyon prototipi (UI yok)
- `SimulationCore` Swift Package: Artist, Song (feat dahil), Album/Edition/Variant, haftalık pipeline, pazar normalizasyonu, dönem tablosu, listeler, AI rakipler, hype/beklenti/flop.
- Headless CLI: seed ile N yıl simüle et, CSV/JSON döküm al.
- **Kalibrasyon:** gerçek dünya referans tablosuna göre denge (bkz. simulation.md §12).
- Determinizm testleri, aktif küme büyüklüğü takibi, 50 yıllık stres testi.
- Bu faz Mac olmadan da (Linux'ta) geliştirilebilir.

### Faz 1 — Oynanabilir MVP
- SwiftUI arayüz, GRDB persistence, kayıt slotları + haftalık autosave.
- Sanatçı oluşturma, şarkı/single/albüm yayınlama, rollout planlama (temel).
- Kapak ve profil görseli yükleme.
- Listeler (US Songs, US Albums, Global Songs, Global Albums), istatistikler, kariyer özeti.
- İngilizce + Türkçe.
- Dönem kapsamı: önce **2000 → bugün** kalibre edilir (indirme + streaming dönemleri).

### Faz 2 — Kariyer derinliği
- Sosyal medya (post atma, takipçi, hype), flop desteği ve "Neden flop oldu?" raporu.
- Varyantlar, deluxe, sertifikalar, rekorlar, kampanyalar, müzik videoları (views), radyo.
- Feat oynanışı (teklif alma/verme).
- Yıl atlama + yıl özeti.

### Faz 3 — Endüstri derinliği
- 90'lar ve 80'ler dönemleri (Basın & TV kanalı, kaset/plak, MTV).
- Turneler, ödüller, ek ülkeler, daha derin AI kariyerleri.

### Faz 4 — Cila
- Animasyonlar, ses, onboarding/tutorial, erişilebilirlik, başarımlar, gelişmiş zorluk ayarları.

## Açık Sorular

- Zorluk seviyeleri kaç tane olacak ve flop desteği her birinde ne kadar güçlü?
- Faz 1'de hangi türler (genre) olacak?
- Kurgusal liste ve platform isimleri (örn. "Streamify", "US Top 100").
- Gelir modeli (ücretli uygulama / ücretsiz) — mimariyi etkilemiyor, sonra karar verilebilir.
