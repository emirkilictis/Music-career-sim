/// Why an action was refused, in the player's language (docs K281).
///
/// The game rules refuse an action with a short English reason (an
/// `ActionException`, or a `GameException` whose code has no message of
/// its own). These used to show as "Something went wrong"; now the
/// reason is shown, in Turkish where the game is in Turkish. A reason
/// missing here shows in English, never as the generic error.
String actionError(String message, {required bool turkish}) {
  final exact = _exact[message];
  if (exact != null) return turkish ? exact.$2 : exact.$1;
  for (final (prefix, en, tr) in _prefixes) {
    if (message.startsWith(prefix)) return turkish ? tr : en;
  }
  return message;
}

/// Reasons with a number or a name in them, by how they start.
const _prefixes = <(String, String, String)>[
  (
    'Cannot go solo',
    'You cannot go solo right now.',
    'Şu an solo kariyere geçemezsin.'
  ),
  ('Cannot make it', 'This cannot be made right now.', 'Bu şu an yapılamaz.'),
  (
    'Cannot re-record',
    'This song cannot be re-recorded right now.',
    'Bu şarkı şu an yeniden kaydedilemez.'
  ),
  (
    'No diss',
    'You cannot release a diss track right now.',
    'Şu an diss parçası çıkaramazsın.'
  ),
  ('No doc', 'No documentary right now.', 'Şu an belgesel yapılamaz.'),
  (
    'No new version',
    'This song cannot get a new version right now.',
    'Bu şarkıya şu an yeni versiyon yapılamaz.'
  ),
  (
    'No price cut',
    'This album cannot get a price cut right now.',
    'Bu albümde şu an indirim yapılamaz.'
  ),
  ('No reunion', 'No reunion right now.', 'Şu an yeniden birleşme olmaz.'),
  ('No session', 'No session right now.', 'Şu an oturum yapılamaz.'),
  ('Blocked', 'Not possible right now.', 'Şu an mümkün değil.'),
  (
    'No collaborator',
    'That collaborator is no longer available.',
    'Bu çalışma arkadaşı artık yok.'
  ),
  ('No song', 'That song is no longer there.', 'Bu şarkı artık yok.'),
  (
    'Song ',
    'That song is not yours or was scrapped.',
    'Bu şarkı senin değil ya da silindi.'
  ),
  ('Unknown genre', 'Unknown genre.', 'Bilinmeyen tür.'),
  ('Up to ', 'Too many songs.', 'Çok fazla şarkı.'),
  ('1–', 'Pick fewer bonus tracks.', 'Daha az bonus şarkı seç.'),
];

/// Reasons as written, with the text shown for them (English, Turkish).
const _exact = <String, (String, String)>{
  // Money, energy, fans.
  'Not enough money': ('Not enough money.', 'Yeterli para yok.'),
  'Not enough money for the campaign': (
    'Not enough money for the campaign.',
    'Kampanya için yeterli para yok.'
  ),
  'Not enough creativity': (
    'Not enough creativity. It refills every week.',
    'Yeterli yaratıcılık yok. Her hafta dolar.'
  ),
  'Not enough fans': ('Not enough fans yet.', 'Henüz yeterli hayran yok.'),
  'Needs more fans': ('Not enough fans yet.', 'Henüz yeterli hayran yok.'),
  'Not known enough': (
    'You are not known enough yet.',
    'Henüz yeterince tanınmıyorsun.'
  ),
  'Not big enough yet': (
    'You are not big enough yet.',
    'Henüz yeterince büyük değilsin.'
  ),
  'Too tired': (
    'Too tired. Rest for a week.',
    'Çok yorgunsun. Bir hafta dinlen.'
  ),
  'No skill points': (
    'No skill points left. You get one every week.',
    'Yetenek puanın kalmadı. Her hafta bir tane kazanırsın.'
  ),
  'Skill is maxed': (
    'This skill is already at its best.',
    'Bu yetenek zaten en üst seviyede.'
  ),
  'Out of reach': ('Out of reach for now.', 'Şimdilik ulaşılamaz.'),
  'Not eligible': ('Not eligible.', 'Uygun değil.'),
  // Timing.
  'Too soon': ('Too soon. Wait a few weeks.', 'Çok erken. Birkaç hafta bekle.'),
  'Not now': ('Not possible right now.', 'Şu an mümkün değil.'),
  'Not the season': ('Not the season for it.', 'Bunun mevsimi değil.'),
  'Pick a week ahead': ('Pick a week ahead.', 'İleri bir hafta seç.'),
  'Release week out of range': (
    'That release week is too far or already past.',
    'Bu çıkış haftası çok uzak ya da geçti.'
  ),
  'Announce week out of range': (
    'That announcement week is too far or already past.',
    'Bu duyuru haftası çok uzak ya da geçti.'
  ),
  'Already wrote this week': (
    'You already wrote this week.',
    'Bu hafta zaten yazdın.'
  ),
  'Ad limit reached for this week': (
    'No more ads this week.',
    'Bu hafta başka reklam yok.'
  ),
  'Posted enough this week': (
    'You posted enough this week.',
    'Bu hafta yeterince paylaştın.'
  ),
  'Replied enough this week': (
    'You replied enough this week.',
    'Bu hafta yeterince cevap verdin.'
  ),
  'No posts left': (
    'No posts left this week.',
    'Bu hafta paylaşım hakkın kalmadı.'
  ),
  'Submissions are closed': ('Submissions are closed.', 'Başvurular kapandı.'),
  'The crisis has passed': ('The crisis has passed.', 'Kriz geçti.'),
  // Already done.
  'Already done': ('Already done.', 'Zaten yapıldı.'),
  'Already caught': ('Already caught.', 'Zaten yakalandı.'),
  'Already founded': ('Already founded.', 'Zaten kuruldu.'),
  'Already has a video': (
    'This song already has a video.',
    'Bu şarkının zaten klibi var.'
  ),
  'Already have one': ('You already have one.', 'Zaten bir tane var.'),
  'Already on it': ('Already on it.', 'Zaten üzerinde.'),
  'Already open': ('Already open.', 'Zaten açık.'),
  'Already replied': ('Already replied.', 'Zaten cevap verdin.'),
  'Already running': ('Already running.', 'Zaten sürüyor.'),
  'Already booked': ('Already booked.', 'Zaten anlaşma yapıldı.'),
  'Already has a date': (
    'This release already has a date.',
    'Bu çıkışın zaten tarihi var.'
  ),
  'Already with this label': (
    'You are already with this label.',
    'Zaten bu plak şirketindesin.'
  ),
  'Already your manager': ('Already your manager.', 'Zaten menajerin.'),
  'Bots already running': (
    'Bots are already running.',
    'Botlar zaten çalışıyor.'
  ),
  'One is set already': ('One is already set.', 'Zaten bir tane ayarlı.'),
  'That edition is already out': (
    'That edition is already out.',
    'Bu baskı zaten çıktı.'
  ),
  'That version is already out': (
    'That version is already out.',
    'Bu versiyon zaten çıktı.'
  ),
  'Twice': ('Not twice.', 'İki kez olmaz.'),
  'A song is listed twice': (
    'A song is listed twice.',
    'Bir şarkı iki kez seçilmiş.'
  ),
  // Limits.
  'Enough features': (
    'This song has enough features.',
    'Bu şarkıda yeterince konuk var.'
  ),
  'Full': ('Full.', 'Dolu.'),
  'Roster full': ('The roster is full.', 'Kadro dolu.'),
  'Too many': ('Too many.', 'Çok fazla.'),
  'Too many genres': ('Too many genres.', 'Çok fazla tür.'),
  // Songs and records.
  'No song': ('That song is no longer there.', 'Bu şarkı artık yok.'),
  'No such song': ('That song is no longer there.', 'Bu şarkı artık yok.'),
  'No album': ('No album.', 'Albüm yok.'),
  'No such album': ('That record is no longer there.', 'Bu kayıt artık yok.'),
  'Not yours': ('That is not yours.', 'Bu senin değil.'),
  'Not your album': ('That is not your record.', 'Bu senin kaydın değil.'),
  'Not this song': ('Not this song.', 'Bu şarkı olmaz.'),
  'Not this version': ('Not this version.', 'Bu versiyon olmaz.'),
  'Not that cover': ('Not that cover.', 'Bu kapak olmaz.'),
  'Not a hit': ('Only a hit can do that.', 'Bunu sadece bir hit yapabilir.'),
  'Not out': ('Not out yet.', 'Henüz çıkmadı.'),
  'Not released': ('Not released yet.', 'Henüz yayınlanmadı.'),
  'Only released songs': (
    'Only released songs.',
    'Sadece yayınlanmış şarkılar.'
  ),
  'Only released songs get versions': (
    'Only released songs get versions.',
    'Sadece yayınlanmış şarkılara versiyon yapılır.'
  ),
  'Only your released songs': (
    'Only your released songs.',
    'Sadece senin yayınlanmış şarkıların.'
  ),
  'Only unreleased songs': (
    'Only unreleased songs.',
    'Sadece yayınlanmamış şarkılar.'
  ),
  'Only unreleased songs can be scrapped': (
    'Only unreleased songs can be scrapped.',
    'Sadece yayınlanmamış şarkılar silinebilir.'
  ),
  'Only unreleased songs or loose singles': (
    'Only unreleased songs or singles not on a record.',
    'Sadece yayınlanmamış şarkılar ya da bir kayıtta olmayan single\'lar.'
  ),
  'Only singles get physical editions': (
    'Only singles get physical editions.',
    'Fiziksel baskı sadece single\'lara yapılır.'
  ),
  'Only announced albums': (
    'Only announced albums.',
    'Sadece duyurulmuş albümler.'
  ),
  'Not on a scrapped song': (
    'Not on a scrapped song.',
    'Silinmiş şarkıda olmaz.'
  ),
  'Scrapped': ('This song was scrapped.', 'Bu şarkı silindi.'),
  'Song is set for a version': (
    'This song is already set for a version.',
    'Bu şarkı zaten bir versiyona ayrıldı.'
  ),
  'EP or album': ('An EP or an album.', 'EP ya da albüm.'),
  'An EP or an album': ('An EP or an album.', 'EP ya da albüm.'),
  'A free mixtape has no editions': (
    'A free mixtape has no editions.',
    'Ücretsiz mixtape\'in baskısı olmaz.'
  ),
  'No such scheduled release': (
    'That planned release is no longer there.',
    'Bu planlı çıkış artık yok.'
  ),
  'Name it': ('Give it a name.', 'Bir isim ver.'),
  'Nothing set': ('Nothing is set.', 'Hiçbir şey ayarlı değil.'),
  'Nothing to buy': ('Nothing to buy.', 'Satın alacak bir şey yok.'),
  'Nothing to push': ('Nothing to push.', 'Öne çıkaracak bir şey yok.'),
  'Nothing to tease': ('Nothing to tease.', 'Tanıtacak bir şey yok.'),
  'Nothing to answer': ('Nothing to answer.', 'Cevaplanacak bir şey yok.'),
  'Gone': ('It is gone.', 'Artık yok.'),
  // Streaming, radio, social.
  'No streaming yet': (
    'Streaming has not started yet.',
    'Streaming henüz başlamadı.'
  ),
  'No social media yet': (
    'Social media has not started yet.',
    'Sosyal medya henüz başlamadı.'
  ),
  'No autoplay yet': (
    'Autoplay has not started yet.',
    'Otomatik oynatma henüz başlamadı.'
  ),
  'No playlists yet': (
    'Playlists have not started yet.',
    'Çalma listeleri henüz başlamadı.'
  ),
  'No playlist': ('No playlist.', 'Çalma listesi yok.'),
  'No Marquee': ('No Marquee right now.', 'Şu an Marquee yok.'),
  'No Showcase': ('No Showcase right now.', 'Şu an Showcase yok.'),
  'No canvas for this song': (
    'This song cannot get a Canvas.',
    'Bu şarkıya Canvas eklenemez.'
  ),
  'No artist pick yet': ('No Artist Pick yet.', 'Henüz Artist Pick yok.'),
  'No countdown yet': ('No countdown yet.', 'Henüz geri sayım yok.'),
  'No snippet now': ('No snippet right now.', 'Şu an snippet yok.'),
  'Cannot pitch': (
    'This cannot be pitched right now.',
    'Bu şu an listelere önerilemez.'
  ),
  'No creator campaign': (
    'No creator campaign.',
    'İçerik üretici kampanyası yok.'
  ),
  'No creator campaign now': (
    'No creator campaign right now.',
    'Şu an içerik üretici kampanyası yok.'
  ),
  'Not on the radio': ('Not on the radio.', 'Radyoda değil.'),
  // The radio budget and records off the market (docs K290, K293).
  'The label cannot run this': (
    'Your label cannot run this.',
    'Şirketin bunu yapamaz.'
  ),
  'Not on sale': ('It is not on sale.', 'Satışta değil.'),
  'Not off the market': (
    'It is not off the market.',
    'Yayından kaldırılmış değil.'
  ),
  'Radio format not possible': (
    'That radio format is not possible.',
    'Bu radyo formatı olmaz.'
  ),
  'Radio push not possible': (
    'No radio push right now.',
    'Şu an radyo tanıtımı yapılamaz.'
  ),
  'UK push not possible': (
    'No UK push right now.',
    'Şu an İngiltere tanıtımı yapılamaz.'
  ),
  'No radio edit now': (
    'No radio edit right now.',
    'Şu an radyo versiyonu yapılamaz.'
  ),
  'No visit now': (
    'No station visit right now.',
    'Şu an radyo ziyareti yapılamaz.'
  ),
  'No visual album now': (
    'No visual album right now.',
    'Şu an görsel albüm yapılamaz.'
  ),
  'No anniversary now': ('No anniversary right now.', 'Şu an yıl dönümü yok.'),
  'No such comment': ('That comment is gone.', 'Bu yorum artık yok.'),
  'Not that kind of comment': (
    'Not that kind of comment.',
    'Bu tür yoruma olmaz.'
  ),
  // Deals, labels, people.
  'Deal over': ('This deal is over.', 'Bu anlaşma bitti.'),
  'No offer': ('No offer.', 'Teklif yok.'),
  'No label': ('No label.', 'Plak şirketi yok.'),
  'Not signable': ('Cannot be signed.', 'Bununla anlaşma yapılamaz.'),
  'Not signed': ('Not signed.', 'Anlaşma yok.'),
  'Not this distributor': ('Not this distributor.', 'Bu dağıtımcı olmaz.'),
  'Not for them': ('Not their kind of song.', 'Onlara göre bir şarkı değil.'),
  'No such buyer': ('That buyer is gone.', 'Bu alıcı artık yok.'),
  'No such demo': ('That demo is gone.', 'Bu demo artık yok.'),
  'No such member': ('That member is gone.', 'Bu üye artık yok.'),
  'Not a group': ('Only a group can do that.', 'Bunu sadece grup yapabilir.'),
  'Not a role of this group': (
    'Not a role in this group.',
    'Bu grupta böyle bir rol yok.'
  ),
  'That act cannot open for you': (
    'That act cannot open for you.',
    'Bu sanatçı senin açılışını yapamaz.'
  ),
  // Tours, festivals, events.
  'No such tour': ('That tour is gone.', 'Bu turne artık yok.'),
  'No such leg': ('That tour leg is gone.', 'Bu turne ayağı artık yok.'),
  "Not this festival's genre": (
    "Not this festival's genre.",
    'Bu festivalin türü değil.'
  ),
  'No reunion on': ('No reunion is on.', 'Süren bir birleşme yok.'),
  'No beef': ('No beef.', 'Atışma yok.'),
  'No crisis': ('No crisis.', 'Kriz yok.'),
  'No moment': ('Nothing to answer.', 'Cevaplanacak bir şey yok.'),
  'No such answer': ('Not an answer to this.', 'Buna böyle cevap verilmez.'),
  'Not an answer to this offer': (
    'Not an answer to this offer.',
    'Bu teklife böyle cevap verilmez.'
  ),
  'Not on it': ('Not on it.', 'Üzerinde değil.'),
  // Rarely seen: the screen does not offer these.
  'Cannot submit': ('This cannot be submitted.', 'Bu aday gösterilemez.'),
  'Not for this record': ('Not for this record.', 'Bu kayıt için olmaz.'),
  'Use scheduleDraft': ('Pick a date for this draft first.', 'Önce bu taslağa bir tarih seç.'),
  'Use releaseSingle for singles': ('Release a single as a single.', 'Single\'ı single olarak yayınla.'),
  'Variants must include week 0': ('The first edition must come out on release week.', 'İlk baskı çıkış haftasında çıkmalı.'),
  'One format per extra edition (not the first)': ('One format per extra edition.', 'Her ek baskıda bir format olur.'),
  'Only a group can split': ('Only a group can split.', 'Sadece grup ayrılabilir.'),
  'Only a group': ('Only a group can do that.', 'Bunu sadece grup yapabilir.'),
  'Only released studio songs': ('Only released studio songs.', 'Sadece yayınlanmış stüdyo şarkıları.'),
};
