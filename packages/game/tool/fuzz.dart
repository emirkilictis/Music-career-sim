// Plays careers with random actions and reports anything that breaks
// other than the game's own refusals (GameException): crashes in actions,
// views or saves (docs K184).
//
//   dart run tool/fuzz.dart [weeks] [seed]
import 'dart:io';
import 'dart:math' as math;

import 'package:game/game.dart';

final _found = <String, int>{};
final _examples = <String, String>{};

void _report(String what, Object e, StackTrace st) {
  final frames = st
      .toString()
      .split('\n')
      .where((l) => l.contains('package:'))
      .take(4)
      .join(' | ');
  final key = '$what: ${e.runtimeType}: ${e.toString().split('\n').first}';
  _found[key] = (_found[key] ?? 0) + 1;
  _examples.putIfAbsent(key, () => frames);
}

void _try(String what, void Function() f) {
  try {
    f();
  } on GameException {
    // The game said no: fine.
  } catch (e, st) {
    _report(what, e, st);
  }
}

T _pick<T>(math.Random r, List<T> xs) => xs[r.nextInt(xs.length)];

void main(List<String> args) {
  final weeks = args.isNotEmpty ? int.parse(args[0]) : 104;
  final seed = args.length > 1 ? int.parse(args[1]) : 1;
  final configs = [
    (2003, StartTier.unknown, ArtistKind.solo, 1),
    (2007, StartTier.risingStar, ArtistKind.band, 3),
    (2013, StartTier.superstar, ArtistKind.solo, 0),
    (2018, StartTier.superstar, ArtistKind.vocalGroup, 18),
    (2021, StartTier.localBuzz, ArtistKind.solo, 5),
  ];
  final dir = Directory.systemTemp.createTempSync('fuzz');
  for (final (year, tier, kind, genre) in configs) {
    final r = math.Random(seed * 1000 + year);
    final slots = SaveSlots(Directory('${dir.path}/$year'));
    var g = GameSession.start(
        slots,
        CareerSetup(
            name: 'Fuzz',
            genre: genre,
            startYear: year,
            tier: tier,
            kind: kind,
            members: kind.isGroup ? const ['A', 'B', 'C', 'D'] : const [],
            premium: true,
            money: StartMoney.millionaire,
            seed: seed + year),
        slotId: 'f');
    stdout.writeln('== $year ${tier.name} ${kind.name}');
    for (var wk = 0; wk < weeks; wk++) {
      final w = g.world;
      final p = w.player!;
      // Keep money around half of the time so expensive paths run too.
      if (wk % 8 == 0 && r.nextBool()) p.moneyCents += 2000000000;
      p.creativeEnergy = math.max(p.creativeEnergy, 60);
      final own = w.playerSongIds.toList();
      final released = [
        for (final id in own)
          if (w.songs[id].releasedWeek >= 0) id
      ];
      final vault = [
        for (final id in own)
          if (w.songs[id].status == SongStatus.vault) id
      ];
      final albums = [
        for (final al in w.albums)
          if (al.artistId == p.id) al.id
      ];
      final rivals = w.activeArtistIds.toList();
      final anySong = w.activeSongIds.toList();
      int song() => own.isEmpty ? 0 : _pick(r, own);
      int rel() => released.isEmpty ? song() : _pick(r, released);
      int album() => albums.isEmpty ? 0 : _pick(r, albums);
      final actions = <String, void Function()>{
        'write': () => g.writeSong(
            budget: _pick(r, BudgetTier.values),
            genres: [genre, if (r.nextBool()) r.nextInt(20)]),
        'single': () => g.releaseSingle(_pick(r, vault.isEmpty ? own : vault),
            campaign: _pick(r, Campaign.values),
            radio: _pick(r, RadioPush.values)),
        'album': () => g.releaseAlbum(
            'A$wk', (vault..shuffle(r)).take(3 + r.nextInt(10)).toList(),
            type: _pick(r, AlbumType.values),
            campaign: _pick(r, Campaign.values),
            exclusive: r.nextInt(5) == 0,
            windowWeeks: _pick(r, [0, 0, 4, 13]),
            bundle: _pick(r, AlbumBundle.values)),
        'scheduleSingle': () => g.scheduleSingle(song(),
            releaseWeek: w.week + 1 + r.nextInt(10),
            announceWeek: w.week + r.nextInt(3)),
        'scheduleAlbum': () => g.scheduleAlbum(
            'S$wk', (vault..shuffle(r)).take(3 + r.nextInt(10)).toList(),
            type: _pick(r, AlbumType.values),
            releaseWeek: w.week + 2 + r.nextInt(20),
            announceWeek: w.week + r.nextInt(2),
            windowWeeks: _pick(r, [0, 4])),
        'video': () => g.shootVideo(rel(), _pick(r, VideoBudget.values)),
        'version': () => g.releaseVersion(rel(), _pick(r, SongVersion.values)),
        'variant': () => g.releaseVariant(rel(), _pick(r, SingleFormat.values)),
        'pitch': () => g.pitchSong(song()),
        'bots': () => g.buyBots(rel(), _pick(r, BotPackage.values)),
        'autoplay': () =>
            g.setAutoplayLevel(rel(), _pick(r, AutoplayLevel.values)),
        'marquee': () => g.runMarquee(rel()),
        'showcase': () => g.runShowcase(rel()),
        'creators': () => g.runCreators(rel(), _pick(r, CreatorCampaign.values)),
        'snippet': () => g.teaseSnippet(song()),
        'curators': () => g.submitToCurators(song(), _pick(r, CuratorPack.values)),
        'cloud': () => g.uploadToCloud(song()),
        'upload': () => g.uploadVideo(_pick(r, VideoKind.values), songId: rel()),
        'language': () =>
            g.releaseLanguageVersion(rel(), _pick(r, LanguageVersion.values)),
        'deluxe': () => g.releaseDeluxe(
            album(), (vault..shuffle(r)).take(1 + r.nextInt(3)).toList()),
        'anniversary': () => g.reissueAnniversary(album()),
        'visual': () => g.makeVisualAlbum(album()),
        'priceCut': () => g.cutAlbumPrice(album(), _pick(r, PriceCut.values)),
        'hits': () => g.releaseGreatestHits(
            'GH', (released..shuffle(r)).take(10).toList(),
            (vault..shuffle(r)).take(1).toList()),
        'rerecord': () => g.rerecordAlbum(album(), 'R$wk'),
        'sell': () => g.sellSong(song(), _pick(r, rivals)),
        'feature': () => g.requestFeature(song(), _pick(r, rivals)),
        'tour': () => g.startTour(TourRequest(name: 'T', legs: [
              TourLeg(_pick(r, TourMarket.values), _pick(r, TourKind.values),
                  1 + r.nextInt(20))
            ])),
        'festival': () => g.bookFestival(r.nextInt(Festivals.all.length)),
        'manager': () => g.hireManager(_pick(r, Manager.values)),
        'label': () => g.signLabel(_pick(r, Label.values),
            deal: _pick(r, ContractDeal.values)),
        'post': () => g.post(_pick(r, PostKind.values), songId: rel()),
        'skill': () => g.spendSkillPoint(_pick(r, SkillKind.values)),
        'job': () => g.setJob(_pick(r, Job.values)),
        'rest': () => g.rest(),
        'ad': () => g.rewardAd(),
        'opportunity': () {
          final o = p.opportunity;
          if (o != null) g.answerOpportunity(_pick(r, o.choices));
        },
        'fanClub': () => g.openFanClub(_pick(r, ClubPrice.values)),
        'imprint': () => g.foundImprint('Label'),
        'signImprint': () => g.signToImprint(_pick(r, rivals)),
        'doc': () => g.startDocumentary(_pick(r, DocDeal.values), 'Doc'),
        'fyc': () => g.runFyc(_pick(r, FycTier.values)),
        'session': () => g.recordSession(rel(),
            anySong.isEmpty ? 0 : _pick(r, anySong)),
        'playlist': () => g.createPlaylist('PL'),
        'addPl': () => g.addToPlaylist(anySong.isEmpty ? 0 : _pick(r, anySong)),
        'distributor': () => g.chooseDistributor(_pick(r, Distributor.values)),
        'upgradeRadio': () => g.upgradeRadio(rel(), _pick(r, RadioPush.values)),
        'radioFormat': () => g.setRadioFormat(rel(), _pick(r, RadioFormat.values)),
        'draft': () => g.saveDraft(
            'D$wk', (vault..shuffle(r)).take(3 + r.nextInt(8)).toList()),
        'releaseDraft': () {
          final d = g.scheduled.where((s) => s.isDraft).toList();
          if (d.isNotEmpty) g.releaseDraft(_pick(r, d).id);
        },
        'scrap': () => g.scrapSong(song()),
        'canvas': () => g.addCanvas(song()),
        'focus': () => g.setMemberFocus(r.nextInt(5) - 1),
        'roles': () => g.setMemberRoles(r.nextInt(4), {
              for (final x in MemberRole.values)
                if (r.nextInt(4) == 0) x
            }),
        'members': () => g.members,
        'lineSplit': () => g.setLineSplit(_pick(r, LineSplit.values)),
        'cheer': () => g.cheerMember(r.nextInt(4)),
        'reunion': () {
          // Years apart, sometimes (docs K194).
          if (w.formerGroupId >= 0 && r.nextInt(4) == 0) {
            w.playerSinceWeek -= Reunions.gapWeeks;
          }
          g.startReunion();
        },
        'reunionSingle': () => g.releaseReunionSingle(song()),
        'reunionAlbum': () => g.releaseReunionAlbum('R$wk',
            (vault..shuffle(r)).take(3 + r.nextInt(6)).toList(),
            type: _pick(r, Credits.memberAlbumTypes)),
        'goSolo': () {
          // Rarely: a split changes the whole career (docs K191).
          if (r.nextInt(6) == 0) g.goSolo(r.nextInt(4));
        },
        'albumMarquee': () => g.runAlbumMarquee(album()),
        'memberSolo': () => g.releaseMemberSolo(r.nextInt(4), song()),
        'memberAlbum': () => g.releaseMemberAlbum(r.nextInt(4), 'M$wk',
            (vault..shuffle(r)).take(3 + r.nextInt(6)).toList(),
            type: _pick(r, AlbumType.values)),
        'cancel': () {
          final s = g.scheduled;
          if (s.isNotEmpty) g.cancelScheduled(_pick(r, s).id);
        },
      };
      final names = actions.keys.toList();
      for (var k = 0; k < 4; k++) {
        final n = _pick(r, names);
        _try(n, actions[n]!);
      }
      // Writing keeps the vault going.
      _try('write', actions['write']!);
      // Every screen's data.
      _try('views', () {
        g.artistPage(p.id);
        g.calendar;
        g.sessions;
        g.festivals;
        g.scheduled;
        g.members;
        g.documentary;
        g.careerByYear;
        g.careerIncome;
        g.topTours(GameTime.yearOf(w.week));
        for (final c in Charts.all) {
          if (c.activeIn(w.week - 1)) g.chart(c.id);
        }
        for (final m in MusicPlatform.values) {
          g.platform(m);
        }
        if (own.isNotEmpty) {
          final id = song();
          g.song(id);
          g.songIncome(id);
          g.featureCandidates(id);
        }
        if (albums.isNotEmpty) {
          g.album(album());
          g.singlePicks(album());
        }
        g.artistPage(_pick(r, rivals));
        g.thisIs(p.id);
        g.goSoloPreview(r.nextInt(4));
        g.lineup;
        g.reunion;
        g.thisIs(_pick(r, rivals));
        for (final role in CollaboratorRole.values) {
          g.collaborators(role);
        }
      });
      _try('week', () => g.advanceWeek());
      if (wk % 26 == 25) {
        _try('reopen', () {
          final slot = g.slotId;
          g.close();
          g = GameSession.resume(slots, slot);
        });
      }
    }
    g.close();
  }
  stdout.writeln('\n${_found.length} kinds of trouble');
  final sorted = _found.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    stdout.writeln('${e.value}x ${e.key}\n    ${_examples[e.key]}');
  }
}
