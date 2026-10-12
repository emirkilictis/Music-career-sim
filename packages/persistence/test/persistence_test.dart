import 'dart:io';

import 'package:persistence/persistence.dart';
import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

late Directory tmp;

World _newWorld(int seed, {Difficulty difficulty = Difficulty.normal}) {
  final w =
      WorldGen.create(seed: seed, startYear: 2012, difficulty: difficulty);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(2012)) {
    sim.step();
  }
  WorldGen.addPlayer(w,
      name: 'Player', genre: 0, money: StartMoney.millionaire);
  return w;
}

/// Deterministic scripted player moves, applied identically in both runs.
void _playerMoves(World w, int i) {
  final p = w.player!;
  if (i == 2) Actions.setJob(w, p, true);
  if (i == 90) Actions.setJob(w, p, false);
  if (i % 3 == 0) Actions.claimAdReward(w, p);
  if (i % 5 == 0 && Actions.canWrite(w, p)) {
    Actions.writeSong(w, p, budget: BudgetTier.medium);
  }
  if (i == 30) {
    final vault = [
      for (final s in w.songs)
        if (s.primaryArtistId == p.id && s.status == SongStatus.vault) s.id,
    ];
    Actions.releaseSingle(w, p, w.songs[vault.first]);
  }
  if (i == 60) {
    final vault = [
      for (final s in w.songs)
        if (s.primaryArtistId == p.id && s.status == SongStatus.vault) s.id,
    ];
    final single =
        w.songs.firstWhere((s) => s.primaryArtistId == p.id && s.isSingle);
    Actions.releaseAlbum(w, p, 'Debut', [single.id, ...vault],
        variantWeeks: const [0, 0, 1]);
  }
}

void main() {
  setUp(() => tmp = Directory.systemTemp.createTempSync('mcs_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('create + load reproduces the world exactly', () {
    final w = _newWorld(1);
    final store = SaveStore.create('${tmp.path}/a.sqlite', w);
    final loaded = store.load();
    store.close();
    expect(worldHash(loaded), worldHash(w));
    expect(loaded.songs.length, w.songs.length);
    expect(loaded.activeSongIds, w.activeSongIds);
    expect(loaded.activeArtistIds, w.activeArtistIds);
  });

  test('difficulty and side income survive save/load', () {
    final w = _newWorld(5, difficulty: Difficulty.hard);
    final p = w.player!;
    Actions.setJob(w, p, true);
    Actions.claimAdReward(w, p);
    Actions.claimAdReward(w, p);
    final store = SaveStore.create('${tmp.path}/e.sqlite', w);
    final loaded = store.load();
    store.close();
    expect(loaded.difficulty, Difficulty.hard);
    expect(loaded.player!.hasJob, isTrue);
    expect(Actions.adsLeftThisWeek(loaded, loaded.player!), 1);
    expect(worldHash(loaded), worldHash(w));
  });

  test('continuous play == save/load every few weeks (determinism)', () {
    // Run A: never saved.
    final a = _newWorld(42);
    final simA = Simulator(a);
    for (var i = 0; i < 120; i++) {
      _playerMoves(a, i);
      simA.step();
    }

    // Run B: weekly autosave, and the game is "restarted" every 13 weeks.
    var b = _newWorld(42);
    final path = '${tmp.path}/b.sqlite';
    var store = SaveStore.create(path, b);
    var simB = Simulator(b);
    for (var i = 0; i < 120; i++) {
      _playerMoves(b, i);
      final r = simB.step();
      store.commitWeek(b, r);
      if (i % 13 == 12) {
        store.close();
        store = SaveStore.open(path);
        b = store.load();
        simB = Simulator(b);
      }
    }
    store.close();
    expect(worldHash(b), worldHash(a));
    expect(b.player!.lifetimeStreams, a.player!.lifetimeStreams);
  });

  test('a crash during save keeps the previous week', () {
    final w = _newWorld(7);
    final path = '${tmp.path}/c.sqlite';
    final store = SaveStore.create(path, w);
    final sim = Simulator(w);
    store.commitWeek(w, sim.step());
    final savedWeek = w.week;
    final hashBefore = worldHash(store.load());

    expect(
        () => store.commitWeek(w, sim.step(),
            debugBeforeCommit: () => throw StateError('power loss')),
        throwsStateError);
    store.close();

    final reopened = SaveStore.open(path);
    final back = reopened.load();
    reopened.close();
    expect(back.week, savedWeek);
    expect(worldHash(back), hashBefore);
  });

  test('history: charts and player weekly stats are queryable', () {
    final w = _newWorld(3);
    final store = SaveStore.create('${tmp.path}/d.sqlite', w);
    final sim = Simulator(w);
    for (var i = 0; i < 70; i++) {
      _playerMoves(w, i);
      store.commitWeek(w, sim.step());
    }
    final weeks = store.db.select(
        'SELECT COUNT(DISTINCT week) AS n FROM chartEntry WHERE chartId = ?',
        [Charts.usSongs]);
    expect(weeks.first['n'], 71); // 70 simulated + the chart at creation
    final top = store.db.select(
        'SELECT COUNT(*) AS n FROM chartEntry WHERE chartId = ? AND week = ?',
        [Charts.usAlbums, w.week - 1]);
    expect(top.first['n'], 100);
    final playerWeeks = store.db.select('SELECT COUNT(*) AS n FROM playerWeek');
    expect(playerWeeks.first['n'], 70);
    final albumWeeks = store.db.select(
        'SELECT COUNT(*) AS n FROM albumWeek aw JOIN album a ON a.id = aw.albumId '
        'WHERE a.artistId = ?',
        [w.playerArtistId]);
    expect(albumWeeks.first['n'], greaterThan(0));
    store.close();
  });

  test('save slots: create, list, reopen, delete', () {
    final slots = SaveSlots(Directory('${tmp.path}/Saves'));
    final w = _newWorld(5);
    slots.create('career-1', w).close();
    slots.create('career-2', _newWorld(6)).close();
    final list = slots.list();
    expect(list.map((e) => e['slotId']), ['career-1', 'career-2']);
    expect(list.first['artistName'], 'Player');
    final reopened = slots.open('career-1');
    expect(worldHash(reopened.load()), worldHash(w));
    reopened.close();
    slots.delete('career-2');
    expect(slots.list().length, 1);
  });
}
