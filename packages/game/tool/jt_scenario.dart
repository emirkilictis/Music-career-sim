// Scenario: replay a real pop career's release calendar (2002–2024) in
// Realistic mode and compare. Scratch tool for a playtest report.
import 'dart:io';

import 'package:game/game.dart';

late GameSession g;
final log = <String>[];
final relSongs = <String, int>{}; // title -> song id
final relAlbums = <String, int>{};
final eraSongs = <int>[]; // songs written for the current album
final team = <int, String>{}; // song id -> "producer / co-writer · budget"
final skillsAt = <String, String>{}; // moment -> skills
final eras = <String>[];

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
  if (!p.canWrite || p.creativeEnergy < 45) return;
  final money = p.moneyCents;
  final budget = money > 20000000
      ? BudgetTier.high
      : money > 2000000
          ? BudgetTier.medium
          : BudgetTier.low;
  if (Actions.budgetCostCents(budget) > money) return;
  final spare = (money - Actions.budgetCostCents(budget)) ~/ 3;
  final prodId = best(CollaboratorRole.producer, genres, spare);
  final writerId = best(CollaboratorRole.songwriter, genres, spare);
  String name(CollaboratorRole r, int? id) => id == null
      ? '—'
      : g
          .collaborators(r)
          .firstWhere((x) => x.id == id)
          .let((x) => '${x.name} (${x.skill.round()})');
  final s = g.writeSong(
    budget: budget,
    producerId: prodId,
    cowriterId: writerId,
    genres: genres,
    title: title,
  );
  eraSongs.add(s.id);
  team[s.id] = '${name(CollaboratorRole.producer, prodId)} / '
      '${name(CollaboratorRole.songwriter, writerId)} · ${budget.name}';
}

/// Signs with the biggest label that takes the player, when free (K54),
/// and keeps campaigns within what the label can run.
Campaign _withLabel(Campaign wanted) {
  final p = g.player;
  if (p.contractAlbumsLeft == 0) {
    final best = g.labels.reversed.where((l) => l.wouldSign).first.label;
    if (best.index > p.label.index) {
      g.signLabel(best);
      log.add('${_date()}  LABEL    signed with ${best.name}');
    }
  }
  final max = g.player.label.maxCampaign;
  return wanted.index <= max.index ? wanted : max;
}

void single(String title, {Campaign campaign = Campaign.intensive}) {
  final id = relSongs[title]!;
  g.releaseSingle(id, campaign: _withLabel(campaign));
  log.add('${_date()}  single   "$title" (${_grade(id)})');
}

void album(String title, List<String> leadTitles, int tracks,
    {Campaign campaign = Campaign.global}) {
  final ids = <int>[for (final t in leadTitles) relSongs[t]!];
  final rest = eraSongs.where((id) => !ids.contains(id)).toList()
    ..sort(
        (a, b) => g.song(b).estimatedGrade.compareTo(g.song(a).estimatedGrade));
  ids.addAll(rest.take(tracks - ids.length));
  final al = g.releaseAlbum(title, ids, campaign: _withLabel(campaign));
  relAlbums[title] = al.id;
  skillsAt[title] = _skills();
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
    _spendPoints();
    final r = g.advanceWeek();
    for (final e in r.events) {
      final line = switch (e) {
        NumberOne(isFirstTime: true) =>
          '#1 ${Charts.all[e.chartId].key} ${_title(e.kind, e.entityId)}',
        AlbumFirstWeek() =>
          'album first week: US ${c(e.usUnits)} (#${e.usPosition}), global ${c(e.globalUnits)}',
        ViralTrend() => 'viral ${g.song(e.songId).title}',
        EraClosed() => () {
            eras.add('${_date()}: ${e.result.name} '
                '(${c(e.units)} units vs expected ${c(e.expected)})');
            return 'era closed: ${e.result.name}';
          }(),
        _ => null,
      };
      if (line != null) log.add('${_date()}    · $line');
    }
  }
  if (queue.isNotEmpty) stderr.writeln('Not written in time: $queue');
}

/// A singer-songwriter's priorities for the weekly skill point.
void _spendPoints() {
  const order = [
    SkillKind.songwriting,
    SkillKind.vocals,
    SkillKind.performance,
    SkillKind.charisma,
    SkillKind.production,
  ];
  while (g.player.skillPoints > 0) {
    final k = order.firstWhere((k) => g.player.skills[k]! < 100,
        orElse: () => order.last);
    if (g.player.skills[k]! >= 100) break;
    g.spendSkillPoint(k);
  }
}

String _skills() {
  final k = g.world.artists[g.player.id].skills;
  String f(double v) => v.toStringAsFixed(0);
  return 'songwriting ${f(k.songwriting)} · vocals ${f(k.vocals)} · '
      'production ${f(k.production)} · performance ${f(k.performance)} · '
      'charisma ${f(k.charisma)}';
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
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
      path: CareerPath.independent,
      premium: true,
      seed: args.isEmpty ? 2002 : int.parse(args.first),
    ),
  );
  skillsAt['Start 2002'] = _skills();
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
        ' / ${c(a.lifetimePure.total)} pure, pre-singles ${c(a.preSingleUnits)}'
        ' (track eq ${c(g.albumSales(a.id).fold(0.0, (x, w) => x + (w.tea ?? 0)))},'
        ' stream eq ${c(g.albumSales(a.id).fold(0.0, (x, w) => x + (w.sea ?? 0)))},'
        ' all track streams/1500 ${c(a.trackStreams / 1500)})');
  }
  final p = g.player;
  print(
      '\nEnd ${_date()}: fans ${c(p.coreFans)}, fame ${(p.fame * 100).round()}%,'
      ' devotion ${(p.devotion * 100).round()}%, money \$${c(p.moneyCents / 100)},'
      ' streams ${c(p.lifetimeStreams.total)}, album units ${c(p.lifetimeUnits.total)},'
      ' single sales ${c(p.lifetimeSingleSales)}');
  print('#1 singles: ${p.numberOneSingles}  #1 albums: ${p.numberOneAlbums}');
  if (args.length > 1) File(args[1]).writeAsStringSync(_markdown());
  g.close();
  dir.deleteSync(recursive: true);
}

String _markdown() {
  final b = StringBuffer();
  final p = g.player;
  String rec(List<ChartRecord> rs, int chart) {
    final r = rs.where((x) => x.chartId == chart).firstOrNull;
    if (r == null) return '—';
    return '#${r.peak}${r.weeksAtNo1 > 0 ? ' (${r.weeksAtNo1}× #1)' : ''}, '
        '${r.weeksOn} hf';
  }

  String reg(RegionalNumbers n) =>
      Region.values.map((r) => c(n[r])).join(' / ');

  b.writeln(
      '# JT kariyeri — ayrıntılı döküm (Gerçekçi mod, tohum ${g.world.seed})\n');
  b.writeln('## Özet\n');
  b.writeln('| | |\n|---|---|');
  b.writeln('| Bitiş | ${_date()} |');
  b.writeln('| Sadık hayran | ${c(p.coreFans)} |');
  b.writeln('| Dinleyici (casual) | ${c(p.casualListeners)} |');
  b.writeln(
      '| Ünlülük / popülerlik / sadakat | %${(p.fame * 100).round()} / %${(p.popularity * 100).round()} / %${(p.devotion * 100).round()} |');
  b.writeln('| Para | \$${c(p.moneyCents / 100)} |');
  b.writeln(
      '| Toplam stream (K.Amerika / Avrupa / Diğer) | ${c(p.lifetimeStreams.total)} (${reg(p.lifetimeStreams)}) |');
  b.writeln(
      '| Albüm birimi (K.Amerika / Avrupa / Diğer) | ${c(p.lifetimeUnits.total)} (${reg(p.lifetimeUnits)}) |');
  b.writeln('| Saf albüm satışı | ${c(p.lifetimePure.total)} |');
  b.writeln('| Single satışı (indirme + CD) | ${c(p.lifetimeSingleSales)} |');
  b.writeln('| Radyo dinleyicisi (toplam) | ${c(p.lifetimeRadio)} |');
  final charts = Charts.all;
  b.writeln('| #1 single sayısı | ${[
    for (final ch in Charts.mainSongCharts)
      '${charts[ch].key.replaceAll('chart.', '')}: ${p.numberOneSingles[ch]}'
  ].join(', ')} |');
  b.writeln('| #1 albüm sayısı | ${[
    for (final ch in Charts.mainAlbumCharts)
      '${charts[ch].key.replaceAll('chart.', '')}: ${p.numberOneAlbums[ch]}'
  ].join(', ')} |');
  b.writeln();
  b.writeln('## Statlar (beceriler)\n');
  b.writeln('| An | Beceriler |\n|---|---|');
  skillsAt['Bitiş 2024'] = _skills();
  for (final e in skillsAt.entries) {
    b.writeln('| ${e.key} | ${e.value} |');
  }
  b.writeln();
  b.writeln('## Dönemler (era)\n');
  for (final e in eras) {
    b.writeln('- $e');
  }
  b.writeln();
  b.writeln('## Yıl yıl\n');
  b.writeln(
      '| Yıl | Stream | Single satışı | Albüm birimi | Saf satış | Ünlülük | Sadık hayran | Para |');
  b.writeln('|---|---|---|---|---|---|---|---|');
  for (final y in g.careerByYear()) {
    b.writeln(
        '| ${y.year} | ${c(y.streams)} | ${c(y.singleSales)} | ${c(y.units)} | ${c(y.pure)} | %${(y.fame * 100).round()} | ${c(y.coreFans)} | \$${c(y.moneyCents / 100)} |');
  }
  b.writeln();
  b.writeln('## Albümler\n');
  for (final e in relAlbums.entries) {
    final a = g.album(e.value);
    b.writeln(
        '### ${e.key} (${GameTime.yearOf(a.releaseWeek)}, ${a.campaign.name} kampanya)\n');
    b.writeln(
        '- İlk hafta: ABD ${c(a.firstWeekUsUnits)} birim (${c(a.firstWeekUsPure)} saf), İngiltere ${c(a.firstWeekUkUnits)}, dünya ${c(a.firstWeekUnits)}');
    b.writeln(
        '- Listeler: ABD ${rec(a.charts, Charts.usAlbums)} · İngiltere ${rec(a.charts, Charts.ukAlbums)} · Global ${rec(a.charts, Charts.globalAlbums)}');
    b.writeln(
        '- Toplam: ${c(a.lifetimeUnits.total)} birim (${reg(a.lifetimeUnits)}), ${c(a.lifetimePure.total)} saf, önceden çıkan single’lardan ${c(a.preSingleUnits)}');
    b.writeln(
        '\n| # | Şarkı | Not | Stream | Satış | Ekip (prodüktör / söz yazarı · bütçe) |');
    b.writeln('|---|---|---|---|---|---|');
    var i = 1;
    for (final id in a.trackIds) {
      final s = g.song(id);
      b.writeln(
          '| ${i++} | ${s.title}${s.isSingle ? ' ★' : ''} | ${s.estimatedGrade} | ${c(s.lifetimeStreams.total)} | ${c(s.singleSales)} | ${team[id] ?? ''} |');
    }
    b.writeln();
  }
  b.writeln('## Single\'lar\n');
  b.writeln(
      '| Single | Not | ABD | İngiltere | Global | Streamify Global | Stream (KA / AV / D) | İndirme | CD | Radyo |');
  b.writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final t in relSongs.keys) {
    final s = g.song(relSongs[t]!);
    if (!s.isSingle) continue;
    b.writeln(
        '| $t | ${s.estimatedGrade} | ${rec(s.charts, Charts.usSongs)} | ${rec(s.charts, Charts.ukSongs)} | ${rec(s.charts, Charts.globalSongs)} | ${rec(s.charts, Charts.platformGlobal)} | ${c(s.lifetimeStreams.total)} (${reg(s.lifetimeStreams)}) | ${c(s.lifetimeDownloads)} | ${c(s.lifetimePhysical)} | ${c(s.lifetimeRadio)} |');
  }
  b.writeln();
  b.writeln('## Önemli anlar\n');
  for (final l in log) {
    b.writeln('- ${l.trim()}');
  }
  return b.toString();
}
