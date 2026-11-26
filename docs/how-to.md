# Bakım rehberi (K310)

Claude olmadan oyunu değiştirmek, dengelemek, hata bulmak ve yayınlamak için. Kısa yol:
**değiştir → `bash tools/test_all.sh` → push**. Push'tan sonra GitHub testleri tekrar çalıştırır,
geçerse siteyi günceller (K309).

## 1. Neyin nerede olduğu

| Klasör | İçinde ne var |
|---|---|
| `packages/simulation_core/lib/src/` | Oyunun kuralları ve sayıları: dinlenme, satış, listeler, rakipler, ödüller. Arayüz yok, saf Dart. |
| `packages/simulation_core/lib/src/simulator.dart` | Her haftanın hesabı (`step`). Dinlenme formülü burada. |
| `packages/simulation_core/lib/src/config/sim_config.dart` | Genel ayarlar (`SimConfig`): eğri yarı ömürleri, liste boyutları, eşikler. |
| `packages/simulation_core/lib/src/config/charts.dart` | Listeler ve kuralları (recurrent, K302). |
| `packages/persistence/` | Kayıt dosyası (SQLite): şema, okuma/yazma. |
| `packages/game/lib/src/game_session.dart` | Oyuncunun yapabildiği her şey (single çıkar, albüm planla…) ve kontrolleri. |
| `packages/game/lib/src/views.dart` | Ekranların gördüğü veriler. |
| `app/lib/screens/` | Ekranlar (Flutter). |
| `tools/l10n/` | Bütün metinler (İngilizce + Türkçe). |
| `docs/README.md` | Karar günlüğü: her değişiklik bir **K** satırı (neden, sayılar, test). |
| `docs/feedback.md` | Oyuncu geri bildirimleri: her biri bir **F** satırı ve hangi K ile çözüldüğü. |

Bir şeyin nerede olduğunu bulmanın en hızlı yolu K numarasını aramak: kod yorumlarında
`docs K295` gibi yazar. Örnek: `grep -rn "K295" packages app`.

## 2. Bir sayıyı değiştirmek (denge)

1. Sayıyı bul. Çoğu bir sınıfın içinde `static const` ya da `SimConfig`'te. Örnekler:
   - Canlı albümlerin dinlenmesi: `LiveAlbums.fanListen`, `LiveAlbums.reach` (`live_albums.dart`).
   - Single ön sipariş etkisi: `Actions.preOrderPerWeek` (`actions.dart`).
   - Hayranların bir şarkıyı dinleme süresi: `SimConfig.fanCurveHalfLifeWeeks`, `Lifecycle.fanReplay`.
   - Katalog düşüşü: `Lifecycle` içindeki `fade…`, `resurgenceChance`, `slumpChance`.
2. Değişikliğin etkisini bir **probe** ile ölç (aşağıda). Önce eski sayıyla çalıştır, sonra yenisiyle.
3. Testleri çalıştır. Bir test kırılırsa iki ihtimal var: ya gerçekten bir şeyi bozdun, ya da test
   eski dengeye göre bir eşik bekliyordu. İkincisiyse eşiği güncelle ve nedenini test yorumuna yaz
   (K306'da yapıldığı gibi).
4. `docs/README.md`'ye bir K satırı ekle: ne değişti, neden, ölçüm.

**Kural:** Dünya rastgele değil, tohumludur (`RandomStream.keyed`). Aynı tohum aynı dünyayı verir.
Yeni bir rastgelelik eklersen `RngPurpose`'a yeni bir numara ekle (var olanları değiştirme).

## 3. Probe'lar (ölçüm araçları)

`packages/game/tool/` içinde. Çalıştırma: `cd packages/game && dart run tool/ADI.dart`.
Her dosyanın ilk satırı ne ölçtüğünü söyler. Sık kullanılanlar:

| Araç | Ne ölçer |
|---|---|
| `decline_probe.dart [yıl] [seviye] [tohum]` | Yeni sanatçının single'ları hafta hafta (sayaçtaki günlük dinlenme ve % değişim). |
| `stream_bug_scan.dart` | Birkaç kariyerde: 0'a düşen şarkı, aynı oranla düşen şarkılar, açılışlar. |
| `newcomer_probe.dart` | Yeni bir sanatçı listeye girebiliyor mu. |
| `debut_probe.dart` | Büyük bir single nereden girip nerede zirve yapıyor. |
| `catalog_rank_probe.dart` | Bir katalog yıllar içinde nasıl değişiyor. |
| `stability_probe.dart` | Haftalık dinlenmeler ne kadar oynak. |
| `top_streams_probe.dart` | En büyük şarkıların haftalık dinlenmesi. |
| `career_probe.dart` | Makul oynayan biri için kariyer ne kadar zor. |
| `fuzz.dart` | Rastgele hamlelerle kariyer oynar, çöken bir şey var mı bakar. |
| `play.dart` | Terminalden gerçek bir kayıt üzerinde oynama. |

## 4. Metin eklemek ya da değiştirmek

1. `tools/l10n/gen_arb.py` içinde `def write(lang, idx):` satırının **üstüne** ekle:
   `k('anahtarAdi','English text','Türkçe metin')`
   (yer tutucu varsa: `k('x','{n} songs','{n} şarkı', n='int')`).
2. Üret: `cd app && python3 ../tools/l10n/gen_arb.py && flutter gen-l10n`
3. Kodda kullan: `context.l10n.anahtarAdi`.

Sosyal medya postlarının metinleri ayrı: `tools/l10n/social_texts.py` (her konu 3 varyant), sonra
`python3 tools/l10n/gen_social.py` ve yukarıdaki iki komut.

Oyunun reddettiği hamlelerin Türkçesi `app/lib/core/action_errors.dart`'ta; yeni bir hata mesajı
eklersen oraya da ekle (`action_errors_test` eksikleri yakalar).

## 5. Testler

- Hepsi: `bash tools/test_all.sh` (yarım saat kadar; en uzun kısım game).
- Tek paket: `cd packages/game && dart test -r failures-only`
- Tek test: `dart test test/game_test.dart -N "testin adı"`
- Uygulama: `cd app && flutter test`
- Kod kontrolü: `flutter analyze` (app) ve `dart analyze` (paketler). "No issues found" olmalı.

## 6. Yayın

- `claude/nifty-archimedes-pceuh4` dalına push → GitHub Actions'ta **Web** iş akışı: önce üç test
  işi (simülasyon+kayıtlar, oyun, uygulama) yan yana, hepsi geçerse derleme ve yayın.
  Durumu: GitHub'da repo → Actions → Web.
- Test kırmızıysa site **güncellenmez**; eski sürüm yayında kalır. Hangi testin kırıldığı iş
  akışının kaydında yazar.
- **Acil durum:** Actions → Web → *Run workflow* → "Publish without running the tests" kutusu.
  Sadece yayındaki bir hatayı hemen kapatmak için.
- Site her yeni sürümde oyunculara "yeni sürüm var" diye yenilemeyi önerir (K242).

## 7. Kayıt dosyasını değiştirmek (dikkat)

Oyuncuların kayıtları bozulmasın diye:
- Yeni bir alan saklanacaksa `packages/persistence/lib/src/schema.dart`'ta listenin sonuna yeni bir
  göç (`_v62` …) ekle: `ALTER TABLE song ADD COLUMN …`. **Yayınlanmış bir göçü asla değiştirme.**
- Alanı `codec.dart`'ta yaz ve oku; eski kayıtta yoksa makul bir varsayılan ver.
- Kayıtta indeksiyle saklanan enum'lara (ör. `FanTopic`, `LegacyTitle`) **sadece sona ekle**,
  sırayı değiştirme, silme.
- Bir alan sadece aynı hafta içinde kullanılıyorsa kayda gerek yok (ör. `Song.preOrderLift`, K305).

## 8. Oyuncu hata bildirdiğinde

1. Oyuncudan oyunun içindeki **böcek simgesiyle** bildirim yapmasını iste (K307). Bir `.mcsave`
   dosyası verir.
2. Oku: `python3 tools/bug_report.py "bug-report Ad.mcsave"` → oyuncunun yazdığı, oyun haftası,
   sürüm, platform ve son hatalar ekrana gelir; `career.sqlite` çıkarılır.
3. Oyunda *Yedekten geri yükle* ile aynı dosyayı aç: kariyer, oyuncunun kaldığı yerden açılır.
   Hatayı orada tekrar et.
4. Düzelt, mümkünse hatayı yakalayan bir test ekle, F ve K satırlarını yaz.

Ekranda koyu kırmızı "Burada bir şey ters gitti" paneli görülüyorsa (K308), o parçanın kodu
bir hata atıyor demektir; bildirimin "Last errors" kısmı hatanın yerini gösterir.

## 9. Telefon sürümleri

- iPhone: `docs/mac-setup.md`.
- Android: imza anahtarı (`upload-keystore.jks`, `key.properties`) **git'e girmez, kimseyle
  paylaşılmaz**; kaybedilirse Play Store'daki uygulama güncellenemez.

## 10. Yerelde çalıştırma

```
flutter pub get
cd app
flutter run -d chrome        # tarayıcıda
flutter run                  # bağlı telefonda
```
