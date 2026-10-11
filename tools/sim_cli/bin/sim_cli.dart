import 'dart:io';

import 'package:simulation_core/simulation_core.dart';

/// Headless runner: simulates N years and prints a yearly report.
///
///   dart run sim_cli --start 2005 --years 10 --seed 42
void main(List<String> args) {
  final opts = _parse(args);
  final start = int.parse(opts['start'] ?? '2005');
  final years = int.parse(opts['years'] ?? '10');
  final seed = int.parse(opts['seed'] ?? '42');
  final quiet = opts.containsKey('quiet');

  final world = WorldGen.create(seed: seed, startYear: start);
  final sim = Simulator(world);
  final startWeek = GameTime.firstWeekOf(start);
  while (world.week < startWeek) {
    sim.step();
  }

  final player = WorldGen.addPlayer(world, name: 'Player (bot)', genre: 0);
  final bot = BotPlayer(world);
  final endWeek = GameTime.firstWeekOf(start + years);

  final allTimes = <int>[];
  final activeByWeek = <int>[];
  var report = _YearReport(world, start);
  while (world.week < endWeek) {
    bot.act();
    final res = sim.step();
    allTimes.add(res.microseconds);
    activeByWeek.add(res.activeSongs);
    report.add(res);
    if (GameTime.weekOfYear(world.week) == 1) {
      if (!quiet) report.print();
      report = _YearReport(world, GameTime.yearOf(world.week));
    }
  }

  _printTopArtists(world);
  _printPlayer(world, player);
  _printPerf(allTimes, world);
  _printDecades(allTimes, activeByWeek, start);
}

Map<String, String> _parse(List<String> args) {
  final m = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      m[key] = args[++i];
    } else {
      m[key] = 'true';
    }
  }
  return m;
}

String fmt(num v) {
  final a = v.abs();
  if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
  if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String grade(int g) {
  if (g >= 90) return 'A+';
  if (g >= 80) return 'A';
  if (g >= 72) return 'B+';
  if (g >= 64) return 'B';
  if (g >= 56) return 'C+';
  if (g >= 48) return 'C';
  return 'D';
}

class _YearReport {
  _YearReport(this.w, this.year);

  final World w;
  final int year;
  final Map<int, int> no1SongWeeks = {};
  final Map<int, int> no1AlbumWeeks = {};
  final Map<int, double> songPoints = {};
  final Map<int, double> albumUnits = {};
  final List<int> debuts = [];
  final List<double> no1Streams = [];
  final List<double> no100Streams = [];
  final List<double> no1Downloads = [];
  final List<double> no200Units = [];
  final List<double> no1AlbumUnits = [];

  void add(WeekResult r) {
    if (r.songChart.isNotEmpty) {
      final top = r.songChart.first.entityId;
      no1SongWeeks[top] = (no1SongWeeks[top] ?? 0) + 1;
      no1Streams.add(w.songs[top].weekStreams);
      no1Downloads.add(w.songs[top].weekDownloads);
      no100Streams.add(w.songs[r.songChart.last.entityId].weekStreams);
    }
    if (r.albumChart.isNotEmpty) {
      final top = r.albumChart.first.entityId;
      no1AlbumWeeks[top] = (no1AlbumWeeks[top] ?? 0) + 1;
      no200Units.add(r.albumChart.last.points);
      no1AlbumUnits.add(r.albumChart.first.points);
    }
    for (final e in r.songChart) {
      songPoints[e.entityId] = (songPoints[e.entityId] ?? 0) + e.points;
    }
    for (final e in r.albumChart) {
      albumUnits[e.entityId] = (albumUnits[e.entityId] ?? 0) + e.points;
    }
    debuts.addAll(r.albumDebuts);
  }

  String _song(int id) {
    final s = w.songs[id];
    final feat = s.featuredArtistIds.isEmpty
        ? ''
        : ' feat. ${s.featuredArtistIds.map((f) => w.artists[f].name).join(', ')}';
    return '"${s.title}" — ${w.artists[s.primaryArtistId].name}$feat';
  }

  String _album(int id) {
    final al = w.albums[id];
    return '"${al.title}" — ${w.artists[al.artistId].name}';
  }

  double _median(List<double> v) {
    if (v.isEmpty) return 0;
    final s = List.of(v)..sort();
    return s[s.length ~/ 2];
  }

  void print() {
    final out = StringBuffer()
      ..writeln('\n================ $year ================');
    out.writeln('#1 SONGS (weeks at #1 this year):');
    for (final e in no1SongWeeks.entries) {
      out.writeln(
          '  ${_song(e.key)}  ·  ${e.value} wk  ·  quality ${w.songs[e.key].quality.toStringAsFixed(0)}');
    }
    out.writeln('#1 ALBUMS:');
    for (final e in no1AlbumWeeks.entries) {
      out.writeln('  ${_album(e.key)}  ·  ${e.value} wk');
    }
    final topDebuts = List.of(debuts)
      ..sort((a, b) =>
          w.albums[b].firstWeekUnits.compareTo(w.albums[a].firstWeekUnits));
    out.writeln('BIGGEST ALBUM DEBUTS (first-week units / pure sales):');
    for (final id in topDebuts.take(5)) {
      final al = w.albums[id];
      out.writeln(
          '  ${_album(id)}  ·  ${fmt(al.firstWeekUnits)} units / ${fmt(al.firstWeekPure)} pure  ·  debut #${al.debutPos}');
    }
    final topSongs = songPoints.keys.toList()
      ..sort((a, b) => songPoints[b]!.compareTo(songPoints[a]!));
    out.writeln('YEAR-END TOP 5 SONGS:');
    for (final id in topSongs.take(5)) {
      out.writeln('  ${_song(id)}  ·  peak #${w.songs[id].peakPos}');
    }
    final topAlbums = albumUnits.keys.toList()
      ..sort((a, b) => albumUnits[b]!.compareTo(albumUnits[a]!));
    out.writeln('YEAR-END TOP 5 ALBUMS (units this year):');
    for (final id in topAlbums.take(5)) {
      out.writeln('  ${_album(id)}  ·  ${fmt(albumUnits[id]!)}');
    }
    out.writeln(
        'SCALE: #1 song median weekly streams ${fmt(_median(no1Streams))}, '
        'downloads ${fmt(_median(no1Downloads))} · #100 streams ${fmt(_median(no100Streams))} · '
        '#1 album ${fmt(_median(no1AlbumUnits))} · #200 album units ${fmt(_median(no200Units))}');
    stdout.write(out.toString());
  }
}

void _printPlayer(World w, Artist p) {
  final mine = w.songs
      .where((s) => s.primaryArtistId == p.id && s.releasedWeek >= 0)
      .toList();
  final best = List.of(mine)
    ..sort(
        (a, b) => w.songLifetimeStreams(b).compareTo(w.songLifetimeStreams(a)));
  final albums = w.albums.where((a) => a.artistId == p.id).toList();
  print('\n================ PLAYER (bot) ================');
  print(
      '${p.name} · fame ${p.fame.toStringAsFixed(2)} · core fans ${fmt(p.coreFans)} · '
      'casual ${fmt(p.casual)} · money \$${fmt(p.moneyCents / 100)}');
  print(
      'Skills: writing ${p.skills.songwriting.toStringAsFixed(0)}, vocals ${p.skills.vocals.toStringAsFixed(0)}, '
      'production ${p.skills.production.toStringAsFixed(0)} · energy ${p.creativeEnergy.toStringAsFixed(0)}');
  print(
      'Released songs: ${mine.length} · albums: ${albums.length} · #1 singles: ${p.no1Singles} · '
      'lifetime streams ${fmt(p.lifetimeStreams)} · album units ${fmt(p.lifetimeAlbumUnits)}');
  for (final s in best.take(5)) {
    print(
        '  "${s.title}" grade ${grade(s.estimatedGrade)} (true ${s.quality.toStringAsFixed(0)}) · '
        'peak #${s.peakPos == 0 ? '-' : s.peakPos} · ${fmt(w.songLifetimeStreams(s))} streams');
  }
  for (final al in albums) {
    print(
        '  Album "${al.title}" (${GameTime.yearOf(al.releaseWeek)}) · debut #${al.debutPos == 0 ? '-' : al.debutPos} · '
        'first week ${fmt(al.firstWeekUnits)} · total ${fmt(w.albumLifetimeUnits(al))}');
  }
  if (p.lastEraResult != null)
    print('Last era result: ${p.lastEraResult!.name}');
}

/// Flatness check: cost per week must not grow with career length.
void _printDecades(List<int> times, List<int> active, int start) {
  const span = GameTime.weeksPerYear * 10;
  print('\nPer decade (avg ms/week · avg active songs):');
  for (var i = 0; i < times.length; i += span) {
    final t = times.sublist(i, (i + span).clamp(0, times.length));
    final a = active.sublist(i, (i + span).clamp(0, active.length));
    final avgT = t.reduce((x, y) => x + y) / t.length / 1000;
    final avgA = a.reduce((x, y) => x + y) / a.length;
    final y0 = start + i ~/ GameTime.weeksPerYear;
    print(
        '  $y0–${y0 + 9}: ${avgT.toStringAsFixed(2)} ms · ${avgA.toStringAsFixed(0)} active');
  }
}

void _printTopArtists(World w) {
  final list = w.artists.where((a) => !a.isRetired).toList()
    ..sort((a, b) => b.fame.compareTo(a.fame));
  print('\n================ TOP ARTISTS (by fame) ================');
  for (final a in list.take(10)) {
    print(
        '  ${a.name.padRight(22)} fame ${a.fame.toStringAsFixed(2)} · core fans ${fmt(a.coreFans).padLeft(7)} · '
        'casual ${fmt(a.casual).padLeft(7)} · #1 singles ${a.no1Singles} · #1 albums ${a.no1Albums} · '
        'streams ${fmt(a.lifetimeStreams)} · album units ${fmt(a.lifetimeAlbumUnits)}');
  }
}

void _printPerf(List<int> times, World w) {
  final s = List.of(times)..sort();
  final avg = s.isEmpty ? 0 : s.reduce((a, b) => a + b) / s.length;
  final p95 =
      s.isEmpty ? 0 : s[(s.length * 0.95).floor().clamp(0, s.length - 1)];
  var dormant = 0;
  for (final a in w.artists) {
    dormant += a.dormantSongIds.length;
  }
  print('\n================ PERFORMANCE ================');
  print(
      'Weeks: ${s.length} · avg ${(avg / 1000).toStringAsFixed(2)} ms · p95 ${(p95 / 1000).toStringAsFixed(2)} ms');
  print(
      'World: ${w.artists.length} artists · ${w.songs.length} songs · ${w.albums.length} albums');
  print(
      'Active songs: ${w.activeSongIds.length} · active albums: ${w.activeAlbumIds.length} · dormant songs: $dormant');
}
