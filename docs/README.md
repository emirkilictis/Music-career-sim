# Music Career Simulator — Tasarım Dokümanları

iOS ve Android için tek oyunculu, istatistik odaklı müzik kariyeri simülasyonu.
Oyuncu solo bir sanatçıyı haftalık adımlarla yönetir: single, EP, albüm, varyant,
rollout, sosyal medya, listeler, sertifikalar, rekorlar ve on yıllara yayılan bir katalog.

> "Bir albüm çıkardım. Şimdi bu hafta ona tam olarak ne olduğunu görmek istiyorum."

Bu klasör, ilk ChatGPT planının incelenip revize edilmiş halidir. İlk plandaki
genel yön (UI'dan bağımsız simülasyon çekirdeği + SQLite, aktif/tarihsel
dünya ayrımı, deterministik seed, baştan stres testi) korunmuş; tespit edilen
sorunlar düzeltilmiş ve oyun tasarımı kararları eklenmiştir.

## Dokümanlar

| Dosya | İçerik |
|---|---|
| [game-design.md](game-design.md) | Oynanış: kariyer başlangıcı, statlar, şarkı yapma, hype/beklenti, flop desteği, sosyal medya, rollout, kampanyalar, satış, finans, rekorlar, ekranlar, kayıt slotları, görseller, zorluk, gelir modeli |
| [simulation.md](simulation.md) | Haftalık pipeline, pazar normalizasyonu, dönem tablosu, yaşam döngüsü, tembel birikim, listeler, AI katmanları, determinizm |
| [data-model.md](data-model.md) | Varlıklar (feat, statlar, ekip, plak şirketi dahil), SQLite şeması, index'ler, geçmiş saklama stratejisi |
| [architecture.md](architecture.md) | Modüller, concurrency, persistence, UI performansı, görsel pipeline'ı, test ve benchmark |
| [phase0-status.md](phase0-status.md) | **Faz 0 durumu:** ne yapıldı, testler, performans, kalibrasyon sonuçları, bilinen eksikler |
| [feedback.md](feedback.md) | Oyuncu geri bildirimleri ve test oyunu notları (henüz uygulanmayanlar) |
| [competitors.md](competitors.md) | Rakip oyunlar (Groove Journey vb.): neyi alalım, neden kaçınalım |

## Karar Kaydı

Bu kararlar alınmıştır; değiştirmek için bilinçli bir revizyon gerekir.

| # | Karar |
|---|---|
| K1 | **Teknoloji:** **Flutter (Dart)** — iOS ve Android tek kod tabanı. Saf Dart `simulation_core` paketi (UI'dan ve DB'den bağımsız, Linux'ta da çalışır) + SQLite (`sqlite3` paketi, elle yazılmış SQL; ORM/kod üretimi yok). Önce iOS'ta test, Android aynı koddan. (İlk plandaki SwiftUI, Android isteği nedeniyle değiştirildi.) |
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
| K17 | **Oyuncuyu boğma:** derinlik arka planda, yüzey sade (bkz. game-design §0). Akıllı varsayılanlar, az ama anlamlı karar, mikro yönetim yok. |
| K18 | **Turne şimdilik yok** (Faz 3). Geldiğinde sade olacak: birkaç ayak + mekan büyüklüğü + bilet fiyatı; setlist ve detaylar isteğe bağlı. Turne beklentiyi bozmaz. Hazırlık olarak sanatçının bölgesel hayran dağılımı baştan basit bir değer olarak tutulur. |
| K19 | **Şarkı kalitesi = sanatçı statları + ekip (prodüktör, söz yazarı) + şans.** Tecrübesiz biri de "ilham anı" ile şaheser yazabilir. Kesin kalite gizli, tahmini not gösterilir. |
| K20 | **Yaratıcı enerji ve burnout:** tek çubuk; art arda çok şarkı yazınca burnout (birkaç hafta yazamama). |
| K21 | **Kariyer yolu:** Bağımsız veya küçük plak şirketi (sade: avans, gelir payı, 2 albümlük sözleşme). Büyük şirket teklifleri Faz 2. |
| K22 | **Başlangıç seviyesi ve parası seçilebilir;** Süperstar/Yükselen yıldız ile Rahat/Milyoner para başlangıcı Premium (ücretsizde $5K, bkz. K27). Oyun ücretsiz ve tek başına eksiksiz. Premium: **aylık / yıllık üyelik + ömür boyu** seçeneği. Üyelik bitince hiçbir kariyer kilitlenmez. |
| K24 | **Bölgeler:** Kuzey Amerika, Avrupa, Diğer (Latin Amerika + Asya + Okyanusya + Afrika). Konfigürasyondan genişletilebilir. Stream, indirme, satış ve radyo bölge bazında hesaplanır; sanatçının kitlesi memleketi, türü ve ünlülüğüne göre bölgelere dağılır. |
| K25 | **Listeler:** ABD, İngiltere ve Global (şarkı + albüm; hepsi 100 sıra, Global şarkı listesinin adı "Global Songs"), ayrıca streaming platformunun Global / Kuzey Amerika / Avrupa Top 50'si. Ülke listeleri, bölgenin bir payıdır (memleket bonusu ile). İsimler kurgusal. |
| K26 | **Zorluk:** **Efsane** (oyuncu güçlü, AI biraz geri çekilir; doğru hamlelerle haftada 5M+) / **Gerçekçi** (gerçek dünya rakamları, herkes aynı kurallarla; en iyi hafta ~4M) / Zor. Kariyer başında seçilir. |
| K27 | **Ücretsiz başlangıç $5.000 ile;** fazlası gündelik işle ($350/hafta, sadece maaş öder, hiçbir şeyi etkilemez) ve ödüllü reklamla (her zaman, haftada en fazla 3 × $250) kazanılır. Rahat/Milyoner başlangıcı Premium. |
| K28 | **Premium günlük giriş bonusu:** her gerçek gün ilk girişte $5.000, hesap başına günde bir kez. |
| K30 | **Grup modu:** Solo / Band / Vokal grup (boyband, girlband). Grup tek sanatçı gibi oynanır (tek stat seti), 2–7 üye (isim, ileride fotoğraf). Türler ceza değil farklı güç verir (band: sadık uzun kariyer; vokal grup: hızlı ve sadık fandom). AI'de de gruplar var. Dağılma/reunion/solo çıkış/kadro değişikliği Faz 2–3. |
| K31 | **Kampanya seviyesi** (Promosyonsuz / Standart / Yoğun / Dev global) her yayında seçilir; Standart = kalibre edilmiş temel. Etkisi döneme göre **radyodan playlistlere kayar**; playlist döneminde editör playlist eklemeleri (bildirimli). Müzik videosu, radyo/TV aksiyonları Faz 2. |
| K32 | **Türler:** 21 ana tür; bir şarkının 1–3 türü olabilir (ilki ana tür). Sanatçının bir ana türü vardır. |
| K33 | **Kayıt slotu herkes için sınırsız** (ücretsiz sürüm dahil). |
| K34 | **Görsel dil:** sade ama sıcak koyu tema (pastel vurgu, göz yormayan kontrast). Listeler ekranı müzik dergisi listesi gibi (kâğıt beyazı, büyük sıra numaraları, GH/ZİRVE/HAFTA); Streamify ekranları büyük streaming uygulamalarının düzenine benzer (sanatçı sayfası, aylık dinleyici, popüler şarkılar, Top 50 playlistleri). Gerçek marka adı, logo ve renk kimliği birebir kopyalanmaz. |
| K29 | **Premium bilerek güçlü (satması için):** daha yüksek başlangıç statları (55 puan, tavan 70; ücretsiz 30 puan, tavan 60) + ünlü/zengin başlangıçlar + günlük bonus. Formüller ve zorluk herkes için aynı; ücretsiz sürüm eksiksiz kalır. |
| K35 | **Özellik seçimi rakip incelemesine göre:** [competitors.md](competitors.md)'deki ✅ / 🕒 / ❌ listesi onaylandı. Oyun gerçekçi bir müzik kariyerinde derinleşir; hayat simülasyonu (güvenlik, personel, ilişkiler), film/gişe, aynı kariyerde ikinci sanatçı ve çevrimiçi lider tablosu yok. Yeni özellikler mevcut sekmelere yerleşir, gerçek markaya yakın parodi isim kullanılmaz. |
| K36 | **İş seçenekleri** (K27'yi günceller): birden fazla gündelik iş; her biri biraz yaratıcı enerji götürür, kazanç arttıkça enerji kaybı artar. Enerji dengesi ve "dinlen / tatil" seçeneğiyle birlikte ayarlanır. |
| K37 | **Bildirimler sadece oyuncunun kendi olayları için** (liste girişi, zirve, #1, albüm ilk hafta, viral, playlist, dönem sonu). Sektör haberleri (rakiplerin #1'leri vb.) ileride gazete ekranında. |
| K38 | **Platformlar gerçek çıkış yıllarında gelir** (kurgusal isimlerle): indirme mağazası 2003, video 2005, ses paylaşım 2008, Streamify 2008 Avrupa / 2011 ABD, ikinci streaming servisi 2015, kısa video 2017–2018. Ekranlar o yılın asıl ölçüsünü öne çıkarır (2000–2004 radyo + CD single, sonra indirme, sonra stream). |
| K39 | **Ekip kilidi hayran sayısına bağlı** (A1): becerisi 45'e kadar olan herkes çalışır; üstü her 7 beceri puanında iki katı sadık hayran ister (beceri 52 → 10K, 73 → 80K, 94 → ~650K). Yeterince ünlü olan da çalışabilir. Kilitli kişide "X hayran gerekli" yazar. |
| K40 | **Enerji** (K20'yi günceller): şarkı −20; hafta sonunda şarkı yazılan haftada +14, yazılmayan haftada +24; "Bu hafta dinlen" +20 ek (o hafta şarkı yazılmaz); iş kendi enerji maliyetini düşer. Enerji 30'un altında şarkılar zayıflar (uyarı gösterilir); tükenmişlik yaratacak şarkıdan önce onay sorulur. Oyuncunun stüdyo bütçe bonusu 0 / +5 / +10, şans payı biraz dar (AI kalibrasyonu değişmedi). |
| K41 | **Renkler** (K34'ü günceller): varsayılan tema **canlı lacivert** (koyu lacivert zemin, doygun pembe / turuncu / yeşil vurgular; eski mor-siyah pastel tema "uyku getiriyor" bulunduğu için bırakıldı). Ayarlar'dan **Aydınlık** tema seçilebilir; değişiklik açık ekranda hemen uygulanır. Renk sadece anlam taşırken kullanılır (artış yeşil, düşüş kırmızı, #1 altın). Listeler (dergi) ve Streamify kendi görünümlerini korur. |
| K42 | **Kalite kraldır:** iyi müzik yapan oyuncu kariyerinin her döneminde çok satabilir ve zirvede kalabilir. Yaş ya da dönem değişimi tek başına cezalandırmaz; düşüş ancak kalite düştüğünde, kendini tekrar ettiğinde ya da uzun süre sessiz kalıp beklentiyi boşa harcadığında gelir. |
| K43 | **Yetenek puanı:** oyuncu her hafta 1 yetenek puanı kazanır ve Kariyer sekmesinde istediği yeteneğe (söz yazarlığı, vokal, prodüksiyon, sahne, karizma) harcar; her yetenek 100'e kadar çıkar. Şarkı yazdıkça gelen küçük artışlar sürer. 5+ harcanmamış puan varsa Ana sayfa "Sıradaki adım" bunu hatırlatır. Karizma artık işe yarar: dinleyicinin hayrana dönüşmesini %80–120 arası etkiler. |
| K44 | **Zirve kalıcıdır, hitler çok satar:** (1) Ünlülük (tanınırlık) hiç düşmez, sadece popülerlik düşer. (2) Lead single'lar birikmiş beklentiyi tüketmez, hype'ı ona kadar yükseltir; beklentiyi albümün kendisi kullanır (uzun moladan dönüş albümü "smash" açılır). (3) Dijital satışlar hitlerde yoğunlaşır: şarkının indirme talebi (dikkat / ortalama)^(γ−1) ile ölçeklenir; γ iTunes patlamasında (2005–2008) 1,45, katalog derinleşip streaming yayıldıkça 2014'e kadar 1,15'e iner. Yılın en çok satan şarkısı 2005–2011'de dünyada ~10–20M. (4) Albüm birimi = saf satış + indirme ÷ 10 + stream ÷ 1500 (2015'ten itibaren, albümün şarkıları için); dönemi kapanmış albümler de stream'den birim kazanmaya devam eder. Single ünitesi = single satışı (CD + dijital) + stream ÷ 150. |
| K23 | ChatGPT planındaki ekranlar, rekorlar, kampanyalar, finans, bildirimler, ödüller, Kolay mod ve 10 performans kuralı dokümanlara taşındı. |

## Yol Haritası

### Faz 0 — Simülasyon prototipi (UI yok) — *devam ediyor, bkz. phase0-status.md*
- `simulation_core` saf Dart paketi: Artist (statlar dahil), Song (feat dahil), Album/Edition/Variant, haftalık pipeline, pazar normalizasyonu, dönem tablosu, listeler, AI rakipler, hype/beklenti/flop, şarkı kalitesi formülü.
- Oyuncu yerine basit bir "bot oyuncu" (şarkı yazar, albüm çıkarır) — kalibrasyon için.
- Headless CLI: seed ile N yıl simüle et, CSV/JSON döküm al.
- **Kalibrasyon:** gerçek dünya referans tablosuna göre denge (bkz. simulation.md §14).
- Determinizm testleri, aktif küme büyüklüğü takibi, 50 yıllık stres testi.
- Bu faz Mac olmadan da (Linux'ta) geliştirilebilir.

### Faz 1 — Oynanabilir MVP — *devam ediyor*

Yapıldı: oyun katmanı (`packages/game`), Flutter uygulamasının ilk sürümü (`app/`): kariyer listesi,
yeni kariyer (grup modu, türler, zorluk, Premium kilitleri, stat dağıtımı), ana ekran (haberler, iş,
reklam, günlük bonus), stüdyo, yayınlar (single + albüm/EP kurucu, kampanya, versiyonlar), listeler,
kariyer özeti, şarkı/albüm detayı (grafikler), ayarlar (dil, Premium test modu), EN/TR. Ekran
görüntüleri: [screenshots/](screenshots/). iPhone'da çalıştırma: [mac-setup.md](mac-setup.md).

Görsel tasarım (K34): yumuşak koyu tema + pastel vurgular, Figtree / Barlow Condensed yazı tipleri,
otomatik kapak görselleri; listeler dergi (Billboard benzeri) görünümünde, Streamify sekmesi büyük bir
streaming uygulaması (Spotify benzeri) görünümünde; alt barda değil, ana ekrandaki **Platformlar** bölümünden açılır (ileride video ve diğer müzik servisleri de oraya eklenecek). Marka adı/logosu kullanılmaz.

Sırada: görsel yükleme (kapak/profil), gerçek satın alma ve reklam SDK'ları, rollout planlama ekranı,
kayıt/yıl atlama sırasında iptal, ilk açılış rehberi, ikonlar ve cilalar.
- Flutter arayüz (önce iOS'ta test, Android derlemesi de), SQLite persistence, kayıt slotları + haftalık autosave.
- Sanatçı oluşturma (statlar, kariyer yolu: bağımsız / küçük şirket, başlangıç seviyesi).
- Şarkı yazma (ekip, kalite, şans, yaratıcı enerji, kasa), single/albüm yayınlama, rollout planlama (temel), kampanya seviyesi.
- Kapak ve profil görseli yükleme.
- Listeler (US Songs, US Albums, Global Songs, Global Albums), istatistikler, kariyer özeti.
- İngilizce + Türkçe.
- Dönem kapsamı: önce **2000 → bugün** kalibre edilir (indirme + streaming dönemleri).

### Faz 2 — Kariyer derinliği
- Sosyal medya (post atma, takipçi, hype), flop desteği ve "Neden flop oldu?" raporu.
- Varyantlar, deluxe, sertifikalar, rekorlar, kampanyalar, müzik videoları (views), radyo.
- Feat oynanışı (teklif alma/verme), büyük şirket teklifleri.
- Grup olayları: ara verme / dağılma / reunion, üyelerin solo çıkışı, kadro değişikliği.
- Yıl atlama + yıl özeti.

### Faz 3 — Endüstri derinliği
- 90'lar ve 80'ler dönemleri (Basın & TV kanalı, kaset/plak, MTV).
- Turneler (sade versiyon, bkz. K18), ödüller, ek ülkeler, daha derin AI kariyerleri.

### Faz 4 — Cila ve yayın
- Premium (uygulama içi satın alma).
- Animasyonlar, ses, onboarding/tutorial, erişilebilirlik, başarımlar, gelişmiş zorluk ayarları.

## Açık Sorular

- Kolay/Zor çarpanlarının kesin değerleri ve flop desteği her birinde ne kadar güçlü?
- Faz 1'de hangi türler (genre) olacak?
- Kurgusal liste ve platform isimleri (örn. "Streamify", "US Top 100") — henüz düşünülmedi; öneri listesi hazırlanacak.
- Premium fiyatları (aylık / yıllık / ömür boyu).
