import 'actions.dart';
import 'model.dart';
import 'names.dart';
import 'rng.dart';
import 'world.dart';

/// A simple automated player used for calibration and stress tests. It uses
/// the same [Actions] API as the real player will.
class BotPlayer {
  BotPlayer(this.world);

  final World world;
  int _lastSingleWeek = -1000;
  int _lastAlbumWeek = -1000;

  /// Ids of songs this bot wrote (avoids scanning the whole world).
  final List<int> _mySongs = [];

  Iterable<Song> get _songs => _mySongs.map((id) => world.songs[id]);

  void act() {
    final w = world;
    final a = w.player;
    if (a == null) return;
    _sideIncome(a);
    _maybeWrite(a);
    _maybeRelease(a);
  }

  /// Free start: keep a day job until the music pays, watch the weekly ads.
  void _sideIncome(Artist a) {
    final w = world;
    Actions.setJob(w, a, a.moneyCents < 5000000);
    while (Actions.adsLeftThisWeek(w, a) > 0) {
      Actions.claimAdReward(w, a);
    }
  }

  List<Song> _vault(Artist a) =>
      _songs.where((s) => s.status == SongStatus.vault).toList()
        ..sort((x, y) {
          final g = y.estimatedGrade.compareTo(x.estimatedGrade);
          return g != 0 ? g : x.id.compareTo(y.id);
        });

  void _maybeWrite(Artist a) {
    final w = world;
    if (!Actions.canWrite(w, a) || a.creativeEnergy < 40) return;
    if (_vault(a).length >= 16) return;
    final budget = a.moneyCents > 20000000
        ? BudgetTier.high
        : (a.moneyCents > 2000000 ? BudgetTier.medium : BudgetTier.low);
    final spend = a.moneyCents * 0.10;
    Collaborator? producer;
    for (final c in w.collaborators) {
      if (c.role != CollaboratorRole.producer) continue;
      if (c.minFame > a.fame || c.feeCents > spend) continue;
      if (producer == null || c.skill > producer.skill) producer = c;
    }
    final cost = Actions.budgetCostCents(budget) + (producer?.feeCents ?? 0);
    if (cost > a.moneyCents) {
      if (Actions.budgetCostCents(BudgetTier.low) > a.moneyCents) return;
      _mySongs.add(Actions.writeSong(w, a, budget: BudgetTier.low).id);
      return;
    }
    _mySongs
        .add(Actions.writeSong(w, a, producer: producer, budget: budget).id);
  }

  void _maybeRelease(Artist a) {
    final w = world;
    final vault = _vault(a);
    final looseSingles =
        _songs.where((s) => s.isSingle && s.albumId < 0).toList();

    if (looseSingles.length >= 2 &&
        vault.length + looseSingles.length >= 10 &&
        w.week - _lastAlbumWeek >= 60 &&
        w.week - _lastSingleWeek >= 6) {
      final tracks = [
        ...looseSingles.map((s) => s.id),
        ...vault.take(12 - looseSingles.length).map((s) => s.id),
      ];
      final title = Names.album(
          RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.botPlayer));
      // Use variants once famous enough to have collectors.
      final variants =
          a.fame > 0.3 && a.moneyCents > Actions.variantCostCents * 8
              ? const [0, 0, 0, 1, 2]
              : const [0];
      Actions.releaseAlbum(w, a, title, tracks,
          variantWeeks: variants, payForVariants: true);
      _lastAlbumWeek = w.week;
      return;
    }

    if (w.week - _lastSingleWeek >= 10) {
      // After an album, promote its best remaining track; otherwise use the vault.
      Song? pick;
      if (w.week - _lastAlbumWeek < 40) {
        for (final s in _songs) {
          if (s.albumId >= 0 &&
              !s.isSingle &&
              w.albums[s.albumId].releaseWeek == _lastAlbumWeek &&
              (pick == null || s.estimatedGrade > pick.estimatedGrade)) {
            pick = s;
          }
        }
      }
      pick ??= vault.isNotEmpty ? vault.first : null;
      if (pick == null) return;
      Actions.releaseSingle(w, a, pick);
      _lastSingleWeek = w.week;
    }
  }
}
