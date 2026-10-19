# Social feed wordings (docs K93): topic -> 3 x (English, Turkish).
# Placeholders: {title} (song/album), {name} (the player), {n} (a number).
# Used by gen_arb.py (ARB keys sm<Topic><i>) and gen_social.py (Dart switch).
TOPICS = {
 'releaseLove': [
  ("{title} is on repeat. I'm not okay 😭", "{title} tekrar tekrar çalıyor. İyi değilim 😭"),
  ("{name} did it again. {title} is perfect.", "{name} yine yaptı. {title} kusursuz."),
  ("Not me crying to {title} at 3am", "Gecenin üçünde {title} dinleyip ağlıyorum, normal mi"),
 ],
 'releaseMixed': [
  ("{title} is growing on me… I think?", "{title} yavaş yavaş sarıyor… sanırım?"),
  ("Okay {title} is fine but we know {name} can do better", "{title} fena değil ama {name} daha iyisini yapabilir, biliyoruz"),
  ("Third listen of {title} and the chorus finally clicked", "Üçüncü dinleyişte {title} nakaratı nihayet oturdu"),
 ],
 'releaseHate': [
  ("{title}… we need to talk, {name}", "{title}… konuşmamız lazım {name}"),
  ("Who approved {title}? Genuinely asking", "{title} için kim onay verdi? Cidden soruyorum"),
  ("Skipping {title}. Waiting for the next one.", "{title} geçiyorum. Bir sonrakini bekliyorum."),
 ],
 'numberOne': [
  ("{title} IS NUMBER ONE!!! WE DID IT", "{title} BİR NUMARA!!! BAŞARDIK"),
  ("#1. {name} deserves this so much 🥹", "#1. {name} bunu fazlasıyla hak ediyor 🥹"),
  ("Screenshotting the chart. Framing it.", "Listenin ekran görüntüsünü aldım. Çerçeveletiyorum."),
 ],
 'topTen': [
  ("{title} debuting at #{n}?? Top 10 baby", "{title} listeye #{n} sırasından girdi?? İlk 10!"),
  ("Stream {title} so we climb from #{n}!", "{title} dinleyin, #{n} sırasından yukarı çıkalım!"),
  ("Top 10 with {title}. Told you all.", "{title} ile ilk 10. Size söylemiştim."),
 ],
 'bigWeek': [
  ("{n} units in week one?! {name} is unstoppable", "İlk haftada {n} ünite mi?! {name} durdurulamıyor"),
  ("{title} first week numbers are insane", "{title} ilk hafta rakamları çılgınca"),
  ("Bought every edition of {title}. No regrets.", "{title} albümünün tüm baskılarını aldım. Pişman değilim."),
 ],
 'criticHigh': [
  ("Pitchwork gave {title} a {n}. Even the critics get it.", "Pitchwork {title} albümüne {n} verdi. Eleştirmenler bile anladı."),
  ("{n}/10 from Pitchwork?! Respect.", "Pitchwork’ten {n}/10 mu?! Saygılar."),
  ("Critics finally catching up to {name}", "Eleştirmenler nihayet {name} seviyesine yetişiyor"),
 ],
 'criticLow': [
  ("A {n} for {title}? Pitchwork doesn't know music.", "{title} albümüne {n} mi? Pitchwork müzikten anlamıyor."),
  ("Ignore the {n}, {title} is a grower", "{n} puanı boşverin, {title} dinledikçe güzelleşiyor"),
  ("Pitchwork being Pitchwork again", "Pitchwork yine Pitchwork’lük yapıyor"),
 ],
 'nominated': [
  ("{name} is a Golden Record nominee!!", "{name} Altın Plak adayı!!"),
  ("Nominated. Now let's win it.", "Aday olduk. Şimdi kazanalım."),
  ("Planning a watch party for the awards", "Ödül gecesi için izleme partisi ayarlıyorum"),
 ],
 'awardWon': [
  ("WINNER!!! {name} you deserve it all", "KAZANDI!!! {name} hepsini hak ediyorsun"),
  ("Crying at the speech. Golden Record winner {name}.", "Konuşmada ağladım. Altın Plak sahibi {name}."),
  ("The trophy looks good on you", "Ödül sana çok yakıştı"),
 ],
 'awardRobbed': [
  ("{name} was ROBBED tonight", "{name} bu gece SOYULDU"),
  ("Awards are rigged anyway. We know who won.", "Ödüller zaten ayarlı. Asıl kazananı biliyoruz."),
  ("Next year. Next year it's ours.", "Seneye. Seneye bizim."),
 ],
 'scandal': [
  ("Waiting for {name} to explain this…", "{name} bunu açıklasın bekliyorum…"),
  ("I'm not reading the comments today", "Bugün yorumları okumuyorum"),
  ("Still here, still a fan. Talk to us {name}.", "Hâlâ buradayım, hâlâ hayranım. Konuş bizimle {name}."),
 ],
 'tour': [
  ("Best night of my life. Thank you {name}.", "Hayatımın en güzel gecesiydi. Teşekkürler {name}."),
  ("My voice is gone after that show", "O konserden sonra sesim kalmadı"),
  ("Already missing the tour. Do it again?", "Turneyi şimdiden özledim. Tekrar yapalım mı?"),
 ],
 'viral': [
  ("Everyone on my feed is using {title} 😂", "Akışımdaki herkes {title} kullanıyor 😂"),
  ("The {title} trend is out of control", "{title} trendi kontrolden çıktı"),
  ("Day one fans watching {title} blow up 🥲", "İlk günden beri hayranlar {title} patlarken izliyor 🥲"),
 ],
 'flopEra': [
  ("This era was underrated and I'll die on that hill", "Bu dönem hak ettiği değeri görmedi, arkasındayım"),
  ("Numbers don't matter, the music was good", "Rakamlar önemli değil, müzik güzeldi"),
  ("Rest, {name}. Come back stronger.", "Dinlen {name}. Daha güçlü dön."),
 ],
 'hiatus': [
  ("{name} where is the new music 😐", "{name} yeni müzik nerede 😐"),
  ("Day {n} of waiting for {name}", "{name} için beklemenin {n}. günü"),
  ("Any updates? Anything? A snippet?", "Haber var mı? Bir şey? Bir parça?"),
 ],
 'battleLost': [
  ("We lost the #1 race by this much. Stream {title}!", "#1 yarışını kılpayı kaybettik. {title} dinleyin!"),
  ("Their fans buy ten copies each, how do we compete", "Onların hayranları onar kopya alıyor, nasıl yetişelim"),
  ("{title} won in our hearts", "{title} kalplerimizde kazandı"),
 ],
 'milestone': [
  ("Another milestone for {name}! So proud", "{name} için bir başarı daha! Gurur duyuyorum"),
  ("Watching {name} grow since day one 🥹", "{name} ilk günden beri büyürken izliyorum 🥹"),
  ("History in the making", "Tarih yazılıyor"),
 ],
 'replyTeaser': [
  ("WHAT IS THIS. drop it now", "BU NE. hemen yayınla"),
  ("The snippet is already on repeat", "O parçacık şimdiden tekrar tekrar çalıyor"),
  ("Release date?? please??", "Çıkış tarihi?? lütfen??"),
 ],
 'replyStudio': [
  ("Studio photos = new music soon 👀", "Stüdyo fotoğrafı = yakında yeni müzik 👀"),
  ("Look how happy you look", "Ne kadar mutlu görünüyorsun"),
  ("Zooming into the lyrics sheet…", "Söz kâğıdına zoom yapıyorum…"),
 ],
 'replyFans': [
  ("{name} replied to me!!! I'm framing this", "{name} bana cevap verdi!!! Çerçeveletiyorum"),
  ("This is why we love you", "İşte bu yüzden seni seviyoruz"),
  ("Best Q&A ever", "Gelmiş geçmiş en iyi soru-cevap"),
 ],
 'replyHotTake': [
  ("Okay but you're not wrong 💀", "Tamam ama haksız değilsin 💀"),
  ("{name} chose chaos today", "{name} bugün kaosu seçti"),
  ("Screenshotting before it gets deleted", "Silinmeden ekran görüntüsünü aldım"),
 ],
 'replyBacklash': [
  ("This was not it, {name}.", "Bu olmadı {name}."),
  ("Unfollowing. Sorry.", "Takipten çıkıyorum. Üzgünüm."),
  ("Delete this please", "Lütfen bunu sil"),
 ],
 'replyPromote': [
  ("Streaming {title} right now", "{title} şu an çalıyor"),
  ("{title} deserves way more", "{title} çok daha fazlasını hak ediyor"),
  ("Added {title} to every playlist I have", "{title} bütün çalma listelerime eklendi"),
 ],
 'postTeaser': [
  ("Something's coming… 👀", "Bir şey geliyor… 👀"),
  ("Can't stop listening to this one. Soon.", "Bunu dinlemeyi bırakamıyorum. Yakında."),
  ("15 seconds of what's next 🎧", "Sıradakinden 15 saniye 🎧"),
 ],
 'postStudio': [
  ("Late night in the studio. Worth it.", "Stüdyoda gece yarısı. Değer."),
  ("Day 12 of making something special", "Özel bir şey yapmanın 12. günü"),
  ("The team that makes it happen ❤️", "Bunu mümkün kılan ekip ❤️"),
 ],
 'postFans': [
  ("Ask me anything. Go.", "Bana istediğinizi sorun. Başlayın."),
  ("Reading your messages tonight. Thank you for everything.", "Bu gece mesajlarınızı okuyorum. Her şey için teşekkürler."),
  ("Tell me your favorite song of mine 👇", "En sevdiğiniz şarkımı yazın 👇"),
 ],
 'postHotTake': [
  ("Unpopular opinion: most hits this year are boring.", "Popüler olmayan görüş: bu yılın hitlerinin çoğu sıkıcı."),
  ("Some artists should stop pretending they write their songs.", "Bazı sanatçılar şarkılarını kendileri yazıyormuş gibi yapmayı bıraksın."),
  ("Award shows don't matter. Never did.", "Ödül törenleri önemli değil. Hiç olmadı."),
 ],
 'postPromote': [
  ("{title}. Go listen. Now.", "{title}. Gidin dinleyin. Şimdi."),
  ("If you haven't heard {title} yet, today's the day", "{title} hâlâ dinlemediysen bugün tam günü"),
  ("Thank you for the love on {title} 🙏", "{title} için gösterdiğiniz sevgiye teşekkürler 🙏"),
 ],
 'botsCaught': [
  ("Streams got removed?? {name} explain", "Stream’ler mi silindi?? {name} açıkla"),
  ("I always knew those {title} numbers were weird", "Zaten {title} rakamları tuhaftı, biliyordum"),
  ("Real fans stream for real. Disappointed.", "Gerçek hayranlar gerçekten dinler. Hayal kırıklığı."),
 ],
 'rivalPurge': [
  ("Streamify purged {title} lmao the numbers were never real", "Streamify {title} şarkısını temizledi, o rakamlar zaten hiç gerçek değildi"),
  ("Not {title} losing millions of streams overnight 💀", "{title} bir gecede milyonlarca stream kaybetti 💀"),
  ("And they said our streams were fake. Look at {title} now", "Bizim stream'lere sahte diyorlardı. {title} haline bak"),
 ],
 'postSponsored': [
  ("Proud to work with {title} ✨ #ad", "{title} ile çalışmaktan gurur duyuyorum ✨ #reklam"),
  ("A day in my life, powered by {title} #ad", "Bir günüm, {title} ile #reklam"),
  ("Big news: I'm the new face of {title} #ad", "Büyük haber: {title} markasının yeni yüzüyüm #reklam"),
 ],
 'replySponsored': [
  ("{title} really picked the right person", "{title} gerçekten doğru kişiyi seçmiş"),
  ("Buying {title} just because of this", "Sırf bunun için {title} alıyorum"),
  ("Ok this collab makes sense", "Tamam bu iş birliği çok mantıklı"),
 ],
 'replySellout': [
  ("{title}?? Really?", "{title} mı?? Cidden mi?"),
  ("The sellout era has begun", "Satılmışlık dönemi başladı"),
  ("Unfollowing until the next album", "Bir sonraki albüme kadar takipten çıkıyorum"),
 ],
 'recordBroken': [
  ("{title} just broke an ALL-TIME record. History.", "{title} TÜM ZAMANLARIN rekorunu kırdı. Tarih yazıldı."),
  ("Record broken. Say it with me: {name} is a legend.", "Rekor kırıldı. Hep beraber: {name} bir efsane."),
  ("Wikipedia editors, update the {title} page", "Vikipedi editörleri, {title} sayfasını güncelleyin"),
 ],
 'yearEndHit': [
  ("{title} at #{n} on the year-end chart!! What a year", "{title} yıl sonu listesinde #{n}!! Ne yıldı ama"),
  ("Year-end #{n}. {name} owned this year.", "Yıl sonu #{n}. Bu yıl {name} yılıydı."),
  ("Song of my year? {title}. Chart agrees (#{n}).", "Yılımın şarkısı mı? {title}. Liste de katılıyor (#{n})."),
 ],
 'musicShowWin': [
  ("{title} WON on Music Peak!! Win #{n} 🏆", "{title} Music Peak'te KAZANDI!! {n}. galibiyet 🏆"),
  ("Voting all night paid off. {title} took the trophy!", "Bütün gece oy verdik, değdi. {title} kupayı aldı!"),
  ("Encore stage of {title} had me screaming", "{title} encore sahnesinde çığlık attım"),
 ],
 'tripleCrown': [
  ("TRIPLE CROWN for {title}!!! Three in a row 👑", "{title} için TRIPLE CROWN!!! Üst üste üç 👑"),
  ("{name} with a Triple Crown. Legends only.", "{name} Triple Crown aldı. Sadece efsaneler."),
  ("{title} leaves Music Peak undefeated. Iconic.", "{title} Music Peak'ten yenilmeden ayrılıyor. İkonik."),
 ],
 'deluxeOut': [
  ("{title} DELUXE?? Bonus tracks?? I'm not ready", "{title} DELUXE mi?? Bonus parçalar mı?? Hazır değilim"),
  ("Buying {title} again for the bonus tracks. Obviously.", "Bonus parçalar için {title} albümünü tekrar alıyorum. Tabii ki."),
  ("The {title} deluxe tracks are better than some albums", "{title} deluxe parçaları bazı albümlerden iyi"),
 ],
 'catchingOn': [
  ("Everyone at my school is suddenly singing {title}", "Okulda herkes birden {title} söylemeye başladı"),
  ("{title} keeps growing. Word of mouth is real.", "{title} büyümeye devam ediyor. Kulaktan kulağa gerçekten işe yarıyor."),
  ("Months later and {title} is everywhere?? Sleeper hit", "Aylar sonra {title} her yerde mi?? Sinsi hit"),
 ],
 'topArtistNo1': [
  ("{name} is the #1 artist in the world this week 🌍", "{name} bu hafta dünyanın #1 sanatçısı 🌍"),
  ("Biggest artist on the planet: {name}. Facts.", "Gezegendeki en büyük sanatçı: {name}. Gerçek bu."),
  ("Number one artist. We built this together.", "Bir numaralı sanatçı. Bunu birlikte kurduk."),
 ],
}
