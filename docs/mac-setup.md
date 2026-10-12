# Oyunu iPhone'da çalıştırma (M2 MacBook Air + iPhone 16 Pro)

Bir kez kurulur, sonra her seferinde sadece "Çalıştırma" adımı yapılır. Ücretli Apple Developer
hesabı **gerekmez**: ücretsiz Apple ID ile kendi telefonuna yükleyebilirsin (uygulama 7 günde bir
yeniden yüklenmek ister; ücretli hesapta bu sınır yok).

## 1. Kurulum (bir kez, ~1 saat, çoğu indirme süresi)

1. **Xcode:** App Store → "Xcode" → Yükle (büyük indirme). Bitince bir kez aç, lisansı kabul et,
   ek bileşenleri kurmasına izin ver. Sonra Terminal'de:
   ```
   sudo xcodebuild -runFirstLaunch
   ```
2. **Homebrew** (yoksa): <https://brew.sh> sayfasındaki tek satırlık komutu Terminal'e yapıştır.
3. **Flutter ve CocoaPods:**
   ```
   brew install --cask flutter
   brew install cocoapods
   flutter doctor
   ```
   `flutter doctor` iOS/Xcode satırlarında ✓ göstermeli (Android satırları şimdilik önemsiz).
4. **Projeyi indir:**
   ```
   git clone https://github.com/emirkilictis/Music-career-sim.git
   cd Music-career-sim
   git checkout claude/nifty-archimedes-pceuh4
   flutter pub get
   ```

## 2. iPhone'u hazırla (bir kez)

1. iPhone'u kabloyla Mac'e bağla, telefonda **"Bu bilgisayara güven"** de.
2. iPhone: **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu → Aç** (telefon yeniden başlar).
3. İmza: `open app/ios/Runner.xcworkspace` ile Xcode'da projeyi aç → soldan **Runner** →
   **Signing & Capabilities** → **Team** kısmında Apple ID'ni ekle/seç. "Bundle Identifier" başkasıyla
   çakışırsa sonuna bir şey ekle (örn. `com.musiccareersim.musicCareerSim.emir`).

## 3. Çalıştırma

```
cd Music-career-sim/app
flutter run
```
Birden fazla cihaz varsa listeden iPhone'u seç. İlk kurulumdan sonra telefonda
**Ayarlar → Genel → VPN ve Cihaz Yönetimi →** Apple ID'ne **güven** demen gerekebilir.

- Kod değişince: Terminal'de `r` (hızlı yenile) veya `R` (yeniden başlat).
- Yeni sürümü almak için: `git pull` → `flutter pub get` → `flutter run`.
- Simülatörde denemek istersen: `open -a Simulator` → `flutter run`.

## Test sürümüne özel notlar

- **Premium (test modu):** ana ekrandaki ⚙️ Ayarlar'dan açılır. Uygulama içi satın alma eklenene kadar
  Premium özelliklerini denemek için.
- **Reklam:** gerçek reklam yerine 3 saniyelik bir test penceresi çıkar; ödül aynı şekilde verilir.
- **Dil:** Ayarlar'dan Cihaz dili / English / Türkçe.

## Sorun çıkarsa

- `flutter doctor` çıktısındaki ✗ satırları ne yapılacağını söyler.
- "CocoaPods not installed" → `brew install cocoapods`, sonra `cd app/ios && pod install`.
- "Untrusted developer" → yukarıdaki VPN ve Cihaz Yönetimi adımı.
- Hata mesajını bana yapıştırman yeterli.
