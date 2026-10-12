# Geri Bildirim ve Yapılacaklar

Oyuncu geri bildirimleri (Emir, iPhone) ve test oyunlarında görülenler (Claude) tek listede.
Öncelik sırası onaylandı (README K35–K38); 1. öncelikten başlanarak uygulanıyor. Biten maddelerin
öncelik sütununa ✅ eklenir.

Kaynak: **E** = Emir'in notu, **T** = Claude'un test oyunu. Öncelik: **1** = önce, **2** = sonra,
**3** = ileride.

## A. Denge ve ilerleme

| # | Konu | Kaynak | Öncelik | Ne yapılacak |
|---|---|---|---|---|
| A1 | **İlerleme kilitli: iyi ekip şöhrete bağlı, şöhret neredeyse hiç artmıyor.** Test oyununda Hot 100 hiti ve 50M stream'e rağmen şöhret %0,8'de kaldı. Becerisi 45'in üstündeki herkes kilitliydi (beceri 60 için %25 şöhret gerekiyor). Oyunun en büyük sorunu. | T | 1 ✅ | Kilit eşiklerini şöhret yerine kariyer başarısına (hayran sayısı, liste girişi, toplam stream) bağlamak ya da eşikleri düşürmek. Kilitli kişide "X gerekli" yazsın. **Yapıldı:** kilit artık sadık hayran sayısına bağlı (K39). Yeni test oyununda bir hitten sonra (21K hayran) beceri 58 prodüktör açıldı; 39K hayranda 61. |
| A2 | **Birden fazla iş seçeneği; her biri az da olsa yaratıcı enerji götürsün.** Şu an tek iş var ($350/hafta) ve enerjiye etkisi yok (K14 değişecek). | E | 1 ✅ | Örnek işler: kafe, müzik dersi, bar/düğün sahnesi, stüdyo asistanlığı. Kazanç arttıkça enerji kaybı artsın. Bazıları küçük yan fayda versin (stüdyo asistanlığı: prodüksiyon becerisi; sahne: biraz hayran). A3 ile birlikte dengelenecek. **Yapıldı:** 5 iş + işsiz: kafe $350/−3, müzik öğretmenliği $450/−5 (vokal, sahne), stüdyo asistanlığı $500/−6 (prodüksiyon), bar/düğün $600/−8 (hayran), gece vardiyası $800/−12 (`screenshots/21_job_picker.png`). Eski kayıtlardaki iş = kafe. |
| A3 | **Tükenmişlik döngüsü.** Haftada 1 şarkı yazınca 4–5 haftada tükenmişlik geliyor (şarkı başına −20 enerji, haftalık +12 yenilenme), ardından 3 hafta yazılamıyor. Önceden uyarı yok. | T | 1 ✅ | Yenilenmeyi ~15–20'ye çıkarmak (iş enerjisi A2 ile birlikte). Enerji 30'un altına inince uyarı göstermek. "Dinlen" seçeneği eklemek. **Yapıldı:** haftalık yenilenme 14/24, "Bu hafta dinlen" +20, gelecek haftanın enerji değişimi ve düşük enerji uyarısı görünür, tükenmişlik öncesi onay (K40, `screenshots/20_energy_and_job.png`). |
| A4 | **Şarkı notları çok oynak, bütçenin etkisi hissedilmiyor.** Aynı ekiple E (24) ile C (67) arası notlar çıktı. Yüksek bütçeyle yazılan 7 şarkının 5'i E oldu. | T | 1 ✅ | Şans ve tahmin gürültüsünü azaltmak, bütçe bonusunu artırmak. Düşük enerjide kalitenin düştüğünü yazmak (şu an gizli). **Yapıldı:** oyuncunun şans payı σ 8 → 6, tahmin gürültüsü σ ~10 → ~5, bütçe bonusu 0/+3/+6 → 0/+5/+10. Yeni test oyununda beceri 58 prodüktör + söz yazarı + yüksek bütçe ile notlar çoğunlukla B/C (önce E/D). |
| A5 | **Para eğrisi: önce yokluk, sonra birden zenginlik.** İlk 4 ay $1–5K arasında. Tek viral şarkıdan sonra $300K birikti ve harcanacak yer kalmadı. | T | 2 | A1 düzelince para anlam kazanır (pahalı ekip). Ek harcama alanları: video, tur, PR, ekipman. |
| A6 | **Sadakat (devotion) erken dönemde sadece düşüyor** (%10 → %7) ve artırmanın yolu yok. | T | 3 | Sosyal medya / konser (Faz 2). Erken dönem için küçük bir araç. |

## B. Hafta akışı ve bildirimler

| # | Konu | Kaynak | Öncelik | Ne yapılacak |
|---|---|---|---|---|
| B1 | **Hafta atlarken çok hızlı geçiyor, atladığı belli olmuyor.** | E | 1 ✅ | Kısa bir geçiş ekranı (~0,6–1 sn): takvim yaprağı / "Hafta 12 → 13" animasyonu, altında haftanın para farkı ve stream özeti. Hızlı oynamak isteyenler için Ayarlar'da kapatılabilir. **Yapıldı:** ~1 sn'lik "Hafta 31 → 32" kartı, para farkıyla; Ayarlar'dan kapatılabilir (`screenshots/03a_week_transition.png`). |
| B2 | **Çoklu hafta atlama seçeneği.** Şu an "Sonraki hafta" ve "Yıl atla" var. | E | 1 ✅ | "Hafta atla" menüsü: 1 / 2 / 4 / 8 hafta, ayrıca "önemli bir şey olana kadar" (listeye giriş, #1, viral, tükenmişliğin bitmesi). İlerleme çubuğu ve sonunda kısa özet (yıl atlamadaki gibi). **Yapıldı:** "Atla" menüsü: 2 / 4 / 8 hafta (büyük olayda durur), "Bir şey olana kadar" (bir sonraki haberinde durur), "Bütün bir yıl"; sonunda özet (`screenshots/15b_skip_menu.png`). |
| B3 | **Bildirimler sinir bozucu; sadece bizim şarkılarımız listelere girince gelsin.** Test oyununda da haberler her hafta "rakip #1" ile doluydu (US albüm listesinde neredeyse her hafta yeni bir #1 var). Önemli bir şey olmayan haftada ilk satır alt bildirim olarak gösteriliyor, o da çoğunlukla rakip #1 oluyor. | E + T | 1 ✅ | Rakip #1 haberleri bildirim olarak gösterilmesin; sadece Listeler ekranında ya da haber listesinin en altında soluk görünsün. Bildirim (açılır pencere / alt bildirim) yalnızca oyuncunun kendi olaylarında: liste girişi, yeni zirve, #1, albüm ilk hafta, viral, playlist, dönem sonu. **Yapıldı:** rakip #1 haberleri artık haber listesinde ve bildirimlerde yok; gazete ekranı gelince orada olacak. |

## C. Bilgi ve ekranlar

| # | Konu | Kaynak | Öncelik | Ne yapılacak |
|---|---|---|---|---|
| C1 | **Kariyer özetinde single satışları da olsun.** 2002 başlangıçlı kariyerde şarkı listesinde hep 0 stream görünüyor; kaç satış yaptığını görmek için tek tek şarkıya tıklamak gerekiyor. 0 stream o yıl için doğru (streaming 2005'te başlıyor, 2007'ye kadar listelere sayılmıyor), ama ekran o dönemde işe yaramayan bir sayı gösteriyor. 2002'de asıl ölçüler **radyo dinleyicisi** ve **CD single satışı**, indirme de 2003'ten sonra geliyor. CD single satışı şu an simülasyonda var, ama ekranda hiç gösterilmiyor. | E | 1 ✅ | Kariyer toplamlarına "Single satışları" (CD + indirme) ve radyo eklenecek. Şarkı listelerinde ve şarkı detayında yılın ana ölçüsü önce gelecek: 2000–2004 radyo + CD single, 2005–2011 indirme, sonrası stream. Hiç olmayan ölçü (ör. 2002'de stream) gizlenecek. **Yapıldı:** kariyer özetinde single satışı ve radyo; şarkı listelerinde yılın ana ölçüsü ("1,2M satış" / "1,2M stream"); şarkı detayında CD single, indirme ve haftalık satış grafiği; 0 olan stream sütunları gizli. Ekran görüntüleri: `screenshots/18_career_2002.png`, `19_song_2002.png`. |
| C2 | **Kayıt yeniden açılınca "bu hafta" stream sayıları 0 görünüyor** (bir sonraki haftaya kadar). Şarkının haftalık değerleri kayda yazılmıyor. C1'deki "hep 0 stream" görüntüsünü de artırıyor olabilir. | T | 1 ✅ | Hata. Haftalık değerler kayda eklenecek ya da açılışta geçmişten okunacak. **Yapıldı:** haftalık değerler kayda yazılıyor (kayıt şeması v2); eski kayıtlar sorunsuz açılıyor. |
| C3 | **Statlar oyun içinde görünmüyor.** Beceriler şarkı yazdıkça artıyor (+0,4 / şarkı) ama oyuncu bunu göremiyor. | T | 2 | Kariyer ya da ana ekranda stat kartı, artışlar görünür olsun. |
| C4 | **Kampanya etkisi görünmüyor.** $20K'lık yoğun kampanyanın ne kazandırdığı belli değil. | T | 2 | Şarkı detayında kampanya özeti (ek stream / radyo, playlist'e neden girmedi). |
| C5 | **Kapak ve sanatçı fotoğrafları yüklenemiyor.** Single / albüm kapağı, ayrıca **sanatçı profil fotoğrafı** (genel; Streamify profili; listelerde şarkının yanında görünen sanatçı fotoğrafı; her platform için ayrı ayrı seçilebilsin). | E | 2 ✅ | Yayın akışına "Kapak seç" adımı: galeriden seç ve kırp, seçilmezse otomatik kapak. Sanatçı için bir **genel fotoğraf** ve isteğe bağlı **platforma özel** fotoğraflar (Streamify profili + banner, listeler/dergi, ileride sosyal medya ve video platformu); platforma özel seçilmemişse genel fotoğraf kullanılır. Görseller cihazda kalır (K8). **Yapıldı:** single yayınlarken kampanya penceresinde "Kapak ekle"; albüm/EP kurarken kapak seçimi; şarkı ve albüm sayfasında kapağa dokununca değiştir / otomatik kapağa dön; Kariyer sekmesinde "Sanatçı fotoğrafları": profil fotoğrafı + Streamify fotoğrafı (seçilmezse profil fotoğrafı). Görseller kariyerin kayıt klasöründe tutulur, kariyer silinince silinir. Listeler (dergi) ekranında sanatçı fotoğrafı yeri yok; sosyal medya gelince oraya da platforma özel fotoğraf eklenecek. |
| C6 | **İsim çakışmaları.** Prodüktör ile söz yazarı aynı isimde olabiliyor ("Elio Laurent" iki kez), listedeki bir yıldızla bir prodüktör aynı isimde ("Yara Castillo"). Soyadları çok tekrar ediyor. | T | 2 | İsim havuzunu büyütmek, isimleri dünya genelinde tekil tutmak. |

## D. Platformlar

| # | Konu | Kaynak | Öncelik | Ne yapılacak |
|---|---|---|---|---|
| D1 | **Müzik platformları gerçek hayattaki çıkış yıllarına göre gelsin.** Şu an Streamify kutusu ana ekranda her yıl görünüyor; listeleri 2009 (global/Avrupa) ve 2011'den (Kuzey Amerika) itibaren var. | E | 2 | Kurgusal isimlerle, gerçekteki çıkış yıllarına göre: **dijital indirme mağazası** 2003 (ABD; Avrupa 2004), **video platformu** 2005 (klip izlenmeleri, 2006'dan büyüme), **ses paylaşım platformu** 2008 (bağımsız sanatçılar, keşfedilme), **Streamify** 2008 Avrupa / 2011 ABD, **ikinci büyük streaming servisi** 2015, **kısa video uygulaması** 2017–2018 (viral şarkılar). Çıkmadan önce Platformlar bölümünde görünmesin (ya da "20XX'te geliyor" diye kilitli dursun). Çıkış yılı gelince haber: "Yeni bir platform çıktı". Platformlar haftalık simülasyonda zaten var olan stream / indirme / video paylarına bağlanacak; dönem tablosu (era table) aynı yılları kullanıyor. **İlk adım yapıldı:** Streamify 2009'dan önce görünmüyor (Ana ekranda "Streaming platformları 2000'lerin sonunda gelecek", listelerden rakip sayfası açılmıyor); 2009'da "Streamify yayına girdi", 2011'de "Kuzey Amerika'ya geldi" haberi. Diğer platformlar (indirme mağazası, video, ses paylaşım, ikinci streaming servisi, kısa video) kendi özellikleriyle gelecek. |

## E. Arayüz (Claude'un ekran incelemesi)

| # | Konu | Kaynak | Öncelik | Ne yapılacak |
|---|---|---|---|---|
| E1 | **Ana ekran "her şey eşit" sorunu.** Kahraman kartı ekranın yarısını statik sayılarla kaplıyor; asıl önemli olanlar (haftanın haberleri, enerji, yapılacaklar) aşağıda kalıyor. Groove Journey'de eleştirdiğimiz hatanın hafif hali. | T | 1 ✅ | Kahraman kartı küçülsün (avatar + isim + 3 küçük çubuk). En üstte haftanın haberi ve **"sıradaki adım" önerisi** ("Kasanda 3 şarkı var, birini single yap", "Enerjin düşük, dinlen"). Sayılar haftalık değişimle (+2.1K hayran). **Yapıldı:** Emir de aynı şeyi söyledi ("dikkatim önemli şeylere gitmedi", "çok şey görüyor gibiydim"). Ana ekran artık: haftanın haberi (en büyük haber büyük, değişimler yeşil/kırmızı), tek bir "Sıradaki adım" önerisi, 3 küçük durum kutusu (hayran, ünlülük, enerji; dokununca enerji ayrıntısı ve dinlen); iş, reklam, platformlar sade satırlar halinde aşağıda. Bölüm başlıkları ve büyük sayılar daha sakin (`screenshots/04_home.png`). |
| E2 | **Stüdyo ekranında 21 tür çipi ekranı kaplıyor**; asıl kararlar (prodüktör, söz yazarı, bütçe) ve "Yaz" düğmesi aşağıda kalıyor. | T | 1 ✅ | Ana tür hazır seçili gelsin, "+ tür ekle" küçük bir pencere açsın. Ekip seçimi kart olsun (beceri çubuğu, ücret, kilitliyse "X hayran gerekli"). Maliyet ve tahmini kalite aralığı "Yaz" düğmesinin yanında sabit dursun. **Yapıldı:** tür, prodüktör ve söz yazarı tek satırlık seçimler; listeler alttan açılan pencerede (beceri çubuğu, ücret, "X hayran gerekli"); şarkı adı küçük ve en altta (`screenshots/05_studio.png`, `05b_producer_picker.png`). |
| E3 | **İsim ve avatar iki kez görünüyor** (üst çubuk + kahraman kartı). | T | 2 ✅ | E1 ile birlikte: üst çubukta sadece hafta ve para. **Yapıldı:** büyük kahraman kartı kalktı; isim ve avatar sadece üst çubukta. |
| E4 | **Alt kısım kalabalık:** "Sonraki hafta / Atla" şeridi + sekme çubuğu ekranın ~%20'si. | T | 2 | Şerit biraz incelsin; Listeler ekranında içerik daha çok yer alsın. |
| E5 | **Otomatik kapaklar birbirine çok benziyor** (aynı degrade + daire); oyuncunun yayınları ayırt edilemiyor. | T | 2 | Daha çeşitli otomatik kapak desenleri (şekil, doku, tipografi) + kapak yükleme (C5). |
| E6 | **Kutlama anları yok.** #1, ilk liste girişi, sertifika gibi büyük anlar sadece bir alt pencere. | T | 2 ✅ | Tam ekran kısa kutlama (konfeti, büyük "#1"), paylaşım kartı (R1) ile birlikte. **Yapıldı:** bir yayının bir listede ilk kez #1 olması ve kariyerin ilk liste girişi tam ekran kutlama (konfeti) ile geliyor; üzerinde paylaşılabilir kart var: kapak, sıra, şarkı, sanatçı, liste, hafta, mod. "Paylaş" kartı görsel olarak telefonun paylaşım menüsüne gönderir (R1'in ilk adımı). (`screenshots/24_celebration_no1.png`, `25_celebration_first_chart.png`) |
| E7 | **Sayılar bağlamsız.** "Ünlülük %30" ne demek, artıyor mu azalıyor mu belli değil. | T | 2 | Değişim okları ve kısa açıklama ("i"): ne işe yarar, nasıl artar. |
| E8 | **Yazı ağırlığı her yerde çok kalın** (w800–w900); başlık ile içerik ayrışmıyor. | T | 3 | Tipografi ölçeğini sadeleştirmek: başlıklar kalın, içerik normal. |
| E9 | **Kariyer listesi boş ve çöp kutusu fazla göz önünde.** | T | 3 | Kartta son hit / son albüm kapağı; silme uzun basma veya menüde. |

İyi olanlar: tutarlı koyu tema ve pastel renkler, dergi tarzı liste ekranı, Streamify sayfası, hafta geçiş kartı ve alt pencereler.

## Test oyunu 3 — Gerçek kariyer tekrarı (JT, Gerçekçi mod)

`packages/game/tool/jt_scenario.dart`: 2002'de yükselen yıldız (NSYNC sonrası), büyük şirket
bütçesi yerine Milyoner başlangıcı, gerçek takvim (single → albüm → single'lar; 2007–2013 ve
2018–2024 arası uzun molalar). 3 farklı dünya (tohum 2002, 7, 42). Hiç flop yok.

| Albüm | Gerçek ilk hafta (ABD) | Oyun ilk hafta | Gerçek zirve | Oyun zirve |
|---|---|---|---|---|
| Justified (2002) | 439K | 209–304K | #2 | #3–4 |
| FutureSex/LoveSounds (2006) | 684K | 594–706K | #1 | #1 (2–9 hafta) |
| The 20/20 Experience (2013) | 968K | 257–419K | #1 | #1 (4–7 hafta) |
| 20/20 – 2 of 2 (2013) | 350K | 162–170K | #1 | #2–3 |
| Man of the Woods (2018) | 293K | 139–156K | #1 | #1 |
| Everything I Thought It Was (2024) | ~31K | ~205K | #4 | #1–2 |

| # | Gözlem | Durum |
|---|---|---|
| T14 | **Uzun moladan sonraki dönüş albümü zayıf.** 7 yıllık beklenti (K3) 20/20'yi gerçekteki 968K'ya yaklaştırmıyor (257–419K). 2 of 2 ve Man of the Woods da gerçeğin yarısı kadar. | Ayar önerisi: tavandaki beklentinin ilk hafta etkisini artırmak. |
| T15 | **Geç kariyer single'ları:** Selfish (2024) 6–16 hafta #1 (gerçekte #19), Filthy #1–3 (gerçekte #9). Emir'in kararı (K42): şarkı kaliteliyse (Selfish'in notu 92–94) bu **doğru davranış**, oyuncu iyi müzik yaptığı sürece zirvede kalabilmeli. | Değişiklik yok. İleride sadece: düşük kalite / kendini tekrar / boşa harcanan beklenti düşüşe yol açsın, yaş ve dönem tek başına değil. |
| T16 | **Birikimli albüm satışları ~2 kat.** Justified 19–23M birim (gerçek ~7M dünya), FS/LS 20–23M (gerçek ~10M). İlk hafta doğru, ama katalog satışları yıllarca fazla sürüyor. | Ayar önerisi: albüm katalog düşüş hızını artırmak. |
| T17 | **İngiltere listesinde çok zayıf.** ABD'de #1 olan şarkılar İngiltere'de #12–#96 (gerçekte JT İngiltere'de de hep ilk 5). ABD'li sanatçının Avrupa payı düşük. | Ayar önerisi: ABD'li pop yıldızlarının Avrupa payını yükseltmek (memleket bonusunu yumuşatmak). |
| T18 | **Büyük şirket kariyeri için bütçe yok.** "Küçük plak şirketi" sadece $25K avans veriyor; 2002'de stream geliri olmadığı için yükselen yıldız bile ilk albümü bitiremiyor. Senaryo Milyoner başlangıcıyla oynandı. | Faz 2'deki büyük şirket teklifleri (R5) çözecek; yükselen yıldız + şirket yolunda avans büyüklüğe göre artabilir. |

| T19 | **Sahne ve karizma hiç gelişmiyor.** 22 yılda söz yazarlığı 47 → 68, vokal 43 → 50 oldu (şarkı yazdıkça); sahne performansı ve karizma 29'da kaldı, çünkü onları geliştiren bir şey yok. | Turne/konser, pratik (rakip incelemesi ✅ listesi) ve sosyal medya gelince bu ikisi de gelişmeli. |
| T20 | **Streaming çağında yıllık stream'ler yüksek.** 2018'de 4,3 milyar, 2024'te 7,8 milyar (gerçek JT'nin tüm platformlardaki yıllığı muhtemelen 2–3 milyar). T16 ile aynı kökten (katalog çok uzun ve güçlü yaşıyor) olabilir. | T16 ile birlikte bakılacak. |

Ayrıntılı döküm: [playtests/jt_2002.md](playtests/jt_2002.md).

İyi taraflar: kariyerin şekli doğru (2006 ve 2013 en büyük dönemler, molalar beklenti yaratıyor),
SexyBack 4–12 hafta #1 (gerçek 7), FutureSex/LoveSounds ilk haftası neredeyse birebir, Can't Stop
the Feeling! #1 oldu, dönem sonu sonuçları hep "başarı".

## Test oyunu 2 — Claude (yeni dengeyle, 2025, ücretsiz başlangıç)

Aynı başlangıç, ~70 hafta. Notlar ve kilitler belirgin şekilde daha iyi (yukarıda A1–A4). Yeni bulgular:

| # | Gözlem | Durum |
|---|---|---|
| T11 | **Katalog şarkıları para kazandırmıyordu.** Aktif listeden düşen şarkılar haftada yüz binlerce stream alıyordu ama gelir $0 görünüyordu. | ✅ Düzeltildi: katalog stream'leri de ödeniyor (test eklendi). |
| T12 | **Viral olmak çok sık.** İki test oyununda da ilk 20–40 haftada bir şarkı viral oldu (bu sefer bir EP şarkısı, D notuyla) ve para birkaç haftada $300K'ya çıktı. Haftalık viral şansı şarkı başına ~%0,6; oyuncunun 6–10 aktif şarkısı olunca yılda neredeyse kesin. | Karar bekliyor: tanınmamış sanatçılar için şansı azaltmak ya da viral etkisini hayran sayısına bağlamak. AI kalibrasyonunu da etkiler. |
| T13 | **İlk şarkılar hâlâ çoğunlukla E.** Ücretsiz statlarla (≈33), yardımsız ve düşük bütçeyle yazınca kalite ≈35. Gerçekçi ama moral bozucu olabilir. | Karar bekliyor: harf eşiklerini yumuşatmak (ör. D 35'ten başlasın) ya da ilk şarkılara küçük bir "ilk kayıt heyecanı" bonusu. |

## Test oyunu 1 — Claude (normal mod, 2025, ücretsiz başlangıç)

Pop şarkıcısı, 30 stat puanı, $5K, Premium yok. Motor üzerinden oynandı (kurallar uygulamayla aynı;
`packages/game/tool/play.dart` aracıyla). 2025'in 1. haftasından 2026'nın 19. haftasına kadar,
yaklaşık 70 hafta. Sırayla olanlar:

1. **İlk aylar:** tek başına yazılan şarkılar hep E. Ucuz prodüktörle (beceri 44) bir D. Gelir:
   iş + reklam + az stream ≈ $600–1.300/hafta. Para $1K ile $5K arasında gidip geldi.
2. **16. hafta:** E/D şarkılardan oluşan bir EP çıktı. Liste yok, ama stream geliri işi geçti
   (~$1.500/hafta).
3. **23. hafta:** ilk C single (orta bütçe, prodüktör ve söz yazarıyla), standart kampanyayla.
   Haftada 300K stream'e kadar çıktı.
4. **39. hafta:** ikinci C single **viral oldu**. Hot 100'de #98'den girip #62'ye kadar yükseldi,
   toplam 50M stream. Ardından albüm (ilk hafta 2,9K birim). Para 7 haftada $10K'dan $260K'ya
   çıktı (haftada $40K).
5. **2026:** yüksek bütçeyle çıkan şarkılar yine çoğunlukla E/D, bir tane B oldu. B şarkı, $20K'lık
   yoğun kampanyayla haftada ~350K stream yaptı, listeye girmedi.
6. **Sonuç:** 70 haftada şöhret %0,8, 26K sadık hayran, $296K para. Paranın harcanacak yeri yok.

İyi taraflar:

- Kötü şarkılar da olsa bir şey yayınlamak ödüllendiriliyor: EP, işten fazla kazandırdı.
- Viral an çok heyecanlı: listeye giriş, para patlaması, albümün hemen ardından gelmesi.
- Stream'ler haftalar içinde ağızdan ağıza büyüyor, şarkılar hemen ölmüyor. Gerçekçi hissettiriyor.
- Hot 100'ün tepesindeki rakamlar (US #1 ~35–55M) ve liste hareketleri inandırıcı.

## Sıradaki test oyunları (öneri)

- Premium yükselen yıldız başlangıcı ve süperstar başlangıcı (orta ve geç oyun).
- Grup modu (vokal grubu).
- Efsane mod.
- 2005 başlangıcı (indirme dönemi; C1 ve D1 için önemli).
