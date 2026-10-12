// Scenario: replay a real pop career's release calendar (2002–2024) in
// Realistic mode and compare. Scratch tool for a playtest report.
import 'dart:io';

import 'package:game/game.dart';

late GameSession g;
final log = <String>[];
final relSongs = <String, int>{}; // title -> song id
final relAlbums = <String, int>{};
final eraSongs = <int>[]; // songs written for the current album

int wk(int year, int week) => GameTime.firstWeekOf(year) + week - 1;

String c(num v) => v >= 1e6
    ? '${(v / 1e6).toStringAsFixed(2)}M'
    : v >= 1e3
        ? '${(v / 1e3).toStringAsFixed(0)}K'
        : v.round().toString();

/// Best available collaborator: skill, with a small bonus for genre fit.
int? best(CollaboratorRole role, List<int> genres, int budgetCents) {
  CollaboratorView? pick;
  double score(CollaboratorView x) =>
      x.skill + (genres.contains(x.genre) ? 3 : 0);
  for (final x in g.collaborators(role)) {
    if (!x.available || x.feeCents > budgetCents) continue;
    if (pick == null || score(x) > score(pick)) pick = x;
  }
  return pick?.id;
}

/// Writes one song if energy allows (keeps energy above burnout).
void writeOne(String title, List<int> genres) {
  final p = g.player;
  if (p.songsLeftThisWeek == 0 || p.creativeEnergy < 45) return;
  final money = p.moneyCents;
  final budget = money > 20000000
      ? BudgetTier.high
      : money > 2000000
          ? BudgetTier.medium
          : BudgetTier.low;
  if (Actions.budgetCostCents(budget) > money) return;
  final spare = (money - Actions.budgetCostCents(budget)) ~/ 3;
  final s = g.writeSong(
    budget: budget,
    producerId: best(CollaboratorRole.producer, genres, spare),
    cowriterId: best(CollaboratorRole.songwriter, genres, spare),
    genres: genres,
    title: title,
  );
  eraSongs.add(s.id);
}

void single(String title, {Campaign campaign = Campaign.intensive}) {
  final id = relSongs[title]!;
  g.releaseSingle(id, campaign: campaign);
  log.add('${_date()}  single   "$title" (${_grade(id)})');
}

void album(String title, List<String> leadTitles, int tracks,
    {Campaign campaign = Campaign.global}) {
  final ids = <int>[for (final t in leadTitles) relSongs[t]!];
  final rest = eraSongs.where((id) => !ids.contains(id)).toList()
    ..sort(
        (a, b) => g.song(b).estimatedGrade.compareTo(g.song(a).estimatedGrade));
  ids.addAll(rest.take(tracks - ids.length));
  final al = g.releaseAlbum(title, ids, campaign: campaign);
  relAlbums[title] = al.id;
  eraSongs.clear();
  log.add('${_date()}  ALBUM    "$title" (${ids.length} tracks)');
}

String _grade(int songId) => g.song(songId).estimatedGrade.toString();
String _date() => 'W${GameTime.weekOfYear(g.week)} ${GameTime.yearOf(g.week)}';

/// Plays up to [w], writing songs on the way for the next release.
void playUntil(int w, {List<String> write = const [], List<int>? genres}) {
  final queue = [...write];
  while (g.week < w) {
    if (queue.isNotEmpty) {
      final before = eraSongs.length;
      writeOne(queue.first, genres ?? const [0, 2]);
      if (eraSongs.length > before) {
        relSongs[queue.first] = eraSongs.last;
        queue.removeAt(0);
      }
    }
    if (g.player.hasJob) g.setJob(Job.none);
    final r = g.advanceWeek();
    for (final e in r.events) {
      final line = switch (e) {
        NumberOne(isFirstTime: true) =>
          '#1 ${Charts.all[e.chartId].key} ${_title(e.kind, e.entityId)}',
        AlbumFirstWeek() =>
          'album first week: US ${c(e.usUnits)} (#${e.usPosition}), global ${c(e.globalUnits)}',
        ViralTrend() => 'viral ${g.song(e.songId).title}',
        EraClosed() => 'era closed: ${e.result.name}',
        _ => null,
      };
      if (line != null) log.add('${_date()}    · $line');
    }
  }
  if (queue.isNotEmpty) stderr.writeln('Not written in time: $queue');
}

String _title(EntityKind k, int id) =>
    k == EntityKind.song ? g.song(id).title : g.album(id).title;

void main(List<String> args) {
  final dir = Directory.systemTemp.createTempSync('jt');
  g = GameSession.start(
    SaveSlots(dir),
    CareerSetup(
      name: 'Justin Timberlake',
      genre: 0,
      home: HomeCountry.us,
      startYear: 2002,
      difficulty: Difficulty.normal,
      tier: StartTier.risingStar,
      money: StartMoney.millionaire,
      path: CareerPath.smallLabel,
      premium: true,
      seed: args.isEmpty ? 2002 : int.parse(args.first),
    ),
  );
  final p0 = g.player;
  log.add(
      'Start 2002: fans ${c(p0.coreFans)}, fame ${(p0.fame * 100).round()}%,'
      ' money \$${c(p0.moneyCents / 100)}');

  // ---- Justified (2002) -------------------------------------------------
  const justified = [
    'Like I Love You',
    'Cry Me a River',
    'Rock Your Body',
    'Señorita',
    'Senorita (Reprise)',
    'Take It from Here',
    'Still on My Brain',
    '(And She Said) Take Me Now',
    'Right for Me',
    'Let\'s Take a Ride',
    'Nothin\' Else',
    'Last Night',
    'Never Again',
    'Worthy Of',
  ];
  playUntil(wk(2002, 33), write: justified);
  single('Like I Love You');
  playUntil(wk(2002, 45));
  album('Justified',
      ['Like I Love You', 'Cry Me a River', 'Rock Your Body', 'Señorita'], 13);
  playUntil(wk(2002, 49));
  single('Cry Me a River');
  playUntil(wk(2003, 15));
  single('Rock Your Body');
  playUntil(wk(2003, 30));
  single('Señorita', campaign: Campaign.standard);

  // ---- FutureSex/LoveSounds (2006) --------------------------------------
  const fsls = [
    'SexyBack',
    'My Love',
    'What Goes Around... Comes Around',
    'LoveStoned',
    'Until the End of Time',
    'FutureSex/LoveSound',
    'Sexy Ladies',
    'Damn Girl',
    'Summer Love',
    'Chop Me Up',
    'Losing My Way',
    '(Another Song) All Over Again',
    'Pose',
  ];
  playUntil(wk(2006, 1));
  playUntil(wk(2006, 28), write: fsls, genres: const [0, 2, 5]);
  single('SexyBack', campaign: Campaign.global);
  playUntil(wk(2006, 37));
  album(
      'FutureSex/LoveSounds',
      [
        'SexyBack',
        'My Love',
        'What Goes Around... Comes Around',
        'LoveStoned',
        'Until the End of Time'
      ],
      12);
  playUntil(wk(2006, 42));
  single('My Love');
  playUntil(wk(2007, 1));
  single('What Goes Around... Comes Around');
  playUntil(wk(2007, 24));
  single('LoveStoned', campaign: Campaign.standard);

  // ---- The 20/20 Experience (2013), 2 of 2 -------------------------------
  const twenty = [
    'Suit & Tie',
    'Mirrors',
    'Pusher Love Girl',
    'Tunnel Vision',
    'Don\'t Hold the Wall',
    'Strawberry Bubblegum',
    'Spaceship Coupe',
    'That Girl',
    'Let the Groove Get In',
    'Blue Ocean Floor',
  ];
  const twoOfTwo = [
    'Take Back the Night',
    'TKO',
    'Gimme What I Don\'t Know',
    'True Blood',
    'Cabaret',
    'Murder',
    'Drink You Away',
    'You Got It On',
    'Amnesia',
    'Only When I Walk Away',
    'Not a Bad Thing',
  ];
  playUntil(wk(2012, 30));
  playUntil(wk(2013, 2), write: twenty, genres: const [0, 2, 11]);
  single('Suit & Tie', campaign: Campaign.global);
  playUntil(wk(2013, 8));
  single('Mirrors', campaign: Campaign.global);
  playUntil(wk(2013, 12));
  album('The 20/20 Experience', ['Suit & Tie', 'Mirrors'], 10);
  playUntil(wk(2013, 28), write: twoOfTwo, genres: const [0, 2, 11]);
  single('Take Back the Night');
  playUntil(wk(2013, 40));
  album('The 20/20 Experience – 2 of 2', ['Take Back the Night', 'TKO'], 11,
      campaign: Campaign.intensive);
  playUntil(wk(2013, 46));
  single('TKO');
  playUntil(wk(2014, 20));
  single('Not a Bad Thing', campaign: Campaign.standard);

  // ---- Can't Stop the Feeling! (2016) -----------------------------------
  playUntil(wk(2016, 19),
      write: ['Can\'t Stop the Feeling!'], genres: const [0, 12]);
  single('Can\'t Stop the Feeling!', campaign: Campaign.global);

  // ---- Man of the Woods (2018) ------------------------------------------
  const motw = [
    'Filthy',
    'Supplies',
    'Say Something',
    'Man of the Woods',
    'Midnight Summer Jam',
    'Sauce',
    'Wave',
    'Higher Higher',
    'Morning Light',
    'Montana',
    'Breeze off the Pond',
    'Livin\' Off the Land',
    'The Hard Stuff',
    'Flannel',
    'Young Man',
    'Hers (interlude)',
  ];
  playUntil(wk(2017, 26));
  playUntil(wk(2018, 1), write: motw, genres: const [0, 2, 4]);
  single('Filthy', campaign: Campaign.global);
  playUntil(wk(2018, 5));
  album('Man of the Woods', ['Filthy', 'Supplies', 'Say Something'], 16);
  playUntil(wk(2018, 6));
  single('Say Something');

  // ---- Everything I Thought It Was (2024) -------------------------------
  const eitiw = [
    'Selfish',
    'No Angels',
    'Drown',
    'Play',
    'Fuckin\' Up the Disco',
    'Memphis',
    'Infinity Sex',
    'Love & War',
    'Liar',
    'Technicolor',
    'Sanctified',
    'Imagination',
    'My Favorite Drug',
    'What Lovers Do',
    'Alone',
    'Flame',
    'Paradise',
    'Conditions',
  ];
  playUntil(wk(2023, 22));
  playUntil(wk(2024, 4), write: eitiw, genres: const [0, 2]);
  single('Selfish', campaign: Campaign.global);
  playUntil(wk(2024, 11));
  album('Everything I Thought It Was', ['Selfish', 'No Angels', 'Drown'], 18);
  playUntil(wk(2024, 40));

  // ---- Report ------------------------------------------------------------
  log.forEach(print);
  print('\n== SINGLES (US Songs peak / weeks at #1 / weeks on) ==');
  for (final t in [
    'Like I Love You',
    'Cry Me a River',
    'Rock Your Body',
    'Señorita',
    'SexyBack',
    'My Love',
    'What Goes Around... Comes Around',
    'LoveStoned',
    'Suit & Tie',
    'Mirrors',
    'Take Back the Night',
    'TKO',
    'Not a Bad Thing',
    'Can\'t Stop the Feeling!',
    'Filthy',
    'Say Something',
    'Selfish',
  ]) {
    final s = g.song(relSongs[t]!);
    String rec(int chart) {
      final r = s.charts.where((x) => x.chartId == chart).firstOrNull;
      return r == null
          ? '—'
          : '#${r.peak}${r.weeksAtNo1 > 0 ? ' (${r.weeksAtNo1}w #1)' : ''} ${r.weeksOn}w';
    }

    print('${t.padRight(34)} grade ${s.estimatedGrade.toString().padLeft(3)}'
        '  US ${rec(Charts.usSongs).padRight(16)} UK ${rec(Charts.ukSongs).padRight(14)}'
        ' Global ${rec(Charts.globalSongs).padRight(14)}'
        ' streams ${c(s.lifetimeStreams.total)} sales ${c(s.singleSales)}');
  }
  print('\n== ALBUMS ==');
  for (final e in relAlbums.entries) {
    final a = g.album(e.value);
    String rec(int chart) {
      final r = a.charts.where((x) => x.chartId == chart).firstOrNull;
      return r == null
          ? '—'
          : '#${r.peak}${r.weeksAtNo1 > 0 ? ' (${r.weeksAtNo1}w #1)' : ''}';
    }

    print(
        '${e.key.padRight(32)} first week US ${c(a.firstWeekUsUnits).padLeft(6)}'
        ' (pure ${c(a.firstWeekUsPure)})  US ${rec(Charts.usAlbums).padRight(10)}'
        ' UK ${rec(Charts.ukAlbums).padRight(8)} total ${c(a.lifetimeUnits.total)} units'
        ' / ${c(a.lifetimePure.total)} pure');
  }
  final p = g.player;
  print(
      '\nEnd ${_date()}: fans ${c(p.coreFans)}, fame ${(p.fame * 100).round()}%,'
      ' devotion ${(p.devotion * 100).round()}%, money \$${c(p.moneyCents / 100)},'
      ' streams ${c(p.lifetimeStreams.total)}, album units ${c(p.lifetimeUnits.total)},'
      ' single sales ${c(p.lifetimeSingleSales)}');
  print('#1 singles: ${p.numberOneSingles}  #1 albums: ${p.numberOneAlbums}');
  g.close();
  dir.deleteSync(recursive: true);
}
