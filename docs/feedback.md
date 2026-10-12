# Geri Bildirim ve Test Oyunu Notları

Oyuncu geri bildirimleri ve test oyunlarında görülenler. Buradakiler **henüz uygulanmadı**. Hangisinin
yapılacağına birlikte karar verilir; yapılınca karar kaydına (README) ve ilgili dokümana taşınır.

## Oyuncu geri bildirimi (iPhone, ilk oynanış)

| # | Not | Durum |
|---|---|---|
| G1 | **Single (ve albüm) kapağı yüklenemiyor.** İlk şarkıyı yayınlarken fotoğraf eklemek istendi. Yol haritasında "Kapak ve profil görseli yükleme" olarak var. Yayın akışına "Kapak seç" adımı eklenecek: galeriden seçme ve kırpma, yoksa otomatik kapak. | Bekliyor |
| G2 | **Birden fazla iş seçeneği olsun; her biri az da olsa yaratıcı enerji götürsün.** Şu an tek iş var: $350/hafta, enerji etkisi yok (K14 değişecek). Örnek: garsonluk / kafe, müzik dersi, düğün-bar sahnesi, stüdyo asistanlığı. Kazanç arttıkça enerji kaybı da artar, bazı işler küçük yan faydalar verebilir (ör. stüdyo asistanlığı: prodüksiyon becerisi; bar sahnesi: biraz hayran). Enerji dengesiyle birlikte ele alınmalı (aşağıda T4). | Bekliyor |

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

### Bulgular

| # | Gözlem | Neden / öneri |
|---|---|---|
| T1 | **İlerleme kilitli: iyi ekip şöhrete bağlı, şöhret neredeyse hiç artmıyor.** Hot 100 hiti ve 50M stream'e rağmen şöhret %0,8'de kaldı. Becerisi 45'in üstündeki herkes kilitli (beceri 60 için %25 şöhret gerekiyor). Bu da kalite artışını engelliyor. Oyunun en büyük sorunu. | Şöhret, haftalık global #1'e göre hesaplanan popülerliği izliyor. Orta ölçekli bir hit bile şöhreti %2–3'te tutuyor. Öneri: kilit eşiklerini şöhret yerine hayran sayısı / kariyer başarısına (liste girişi, toplam stream) bağlamak ya da eşiği düşürmek (`minFame`). Kilitli satırda "X şöhret gerekli" yazmalı. |
| T2 | **Kalite tahmini çok oynak, bütçe etkisi hissedilmiyor.** Aynı ekip ve bütçeyle E (24) ile C (67) arası notlar çıktı. Yüksek bütçe ($15K) ile çıkan 7 şarkının 5'i E oldu. | Şans (σ 8) ile tahmin gürültüsü (σ ~10) üst üste biniyor. Ayrıca enerji 30'un altındayken yazınca kalite gizlice düşüyor. Öneri: gürültüyü azaltmak; düşük enerjide "kalite düşer" uyarısı göstermek; bütçe bonusunu artırmak. |
| T3 | **Para eğrisi: önce yokluk, sonra birden zenginlik.** İlk 4 ay $1–5K arasında sıkışık. Tek viral şarkıdan sonra $300K birikti ve paranın kullanılacak yeri kalmadı. | T1 düzelince para yine anlam kazanır (pahalı prodüktörler). Ek harcama alanları düşünülebilir: video, tur, ekipman, PR. |
| T4 | **Tükenmişlik döngüsü.** Haftada 1 şarkı yazınca 4–5 haftada tükenmişlik geliyor (şarkı başına −20, haftalık +12 enerji), ardından 3 hafta yazamama. Önceden uyarı yok. | G2 (işin enerji götürmesi) ile birlikte yeniden dengelenmeli: haftalık yenilenme ~15–20 olmalı, enerji 30'un altına inince uyarı verilmeli, bir "dinlen" seçeneği eklenebilir. |
| T5 | **Kayıt yeniden açılınca "bu hafta" stream sayıları 0 görünüyor** (bir sonraki haftaya kadar). Bir şarkının haftalık değerleri kayda yazılmıyor. | Hata. Haftalık değerler kayda eklenmeli ya da açılışta geçmişten okunmalı. |
| T6 | **Kampanya etkisi görünmüyor.** $20K'lık yoğun kampanyanın ne kazandırdığı belli değil. | Şarkı detayında "kampanya: +X stream / radyo" özeti ya da playlist'e girmeme nedeni gösterilebilir. |
| T7 | **Haberler her hafta "rakip #1" ile doluyor.** US albüm listesinde neredeyse her hafta yeni bir #1 var. | Rakip #1 haberleri tek satırda toplanmalı ya da sadece şarkı listesi için gösterilmeli. |
| T8 | **İsim çakışmaları.** Prodüktör ile söz yazarı aynı isimde olabiliyor ("Elio Laurent" iki kez). Listedeki bir yıldızla bir prodüktör aynı isimde ("Yara Castillo"). Soyadları çok tekrar ediyor. | İsim havuzu büyütülmeli; isimler dünya genelinde tekil tutulmalı. |
| T9 | **Statlar oyun içinde görünmüyor.** Beceriler şarkı yazdıkça artıyor (+0,4 / şarkı), ama oyuncu bunu göremiyor. | Kariyer ya da ana ekranda stat kartı gösterilmeli, gelişim görünmeli. |
| T10 | **Sadakat (devotion) erken dönemde sadece düşüyor** (%10 → %7) ve oyuncunun bunu artırmak için bir aracı yok. | Sosyal medya / konser gibi Faz 2 özellikleriyle çözülür. Erken dönem için küçük bir araç düşünülebilir. |

### İyi taraflar

- Kötü şarkılar da olsa bir şey yayınlamak ödüllendiriliyor: EP, işten fazla kazandırdı.
- Viral an çok heyecanlı: listeye giriş, para patlaması, albümün hemen ardından gelmesi.
- Stream'ler haftalar içinde ağızdan ağıza büyüyor, şarkılar hemen ölmüyor. Gerçekçi hissettiriyor.
- Hot 100'ün tepesindeki rakamlar (US #1 ~35–55M) ve liste hareketleri inandırıcı.

### Sıradaki test oyunları (öneri)

- Premium yükselen yıldız başlangıcı ve süperstar başlangıcı (orta ve geç oyun).
- Grup modu (vokal grubu).
- Efsane mod.
- 2005 başlangıcı (indirme dönemi).
