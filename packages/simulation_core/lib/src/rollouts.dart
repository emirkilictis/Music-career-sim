import 'model.dart';
import 'streaming_tools.dart';
import 'time.dart';
import 'world.dart';

/// A step of an album's rollout (docs K165). Index order is stored as
/// bits: only append.
enum RolloutStep {
  /// A track out as a single a month or more ahead.
  leadSingle,

  /// A second single from the record before it comes out.
  secondSingle,

  /// Announced a month or more ahead.
  announced,

  /// A music video for one of its songs.
  video,

  /// A snippet teased on the short-video app (2019+).
  teaser,

  /// A track pitched to the playlist editors (streaming era).
  pitch,
}

/// How the steps stand for a record.
class RolloutStatus {
  const RolloutStatus(this.applicable, this.done);

  /// Bits of [RolloutStep] that count for it, and of those done.
  final int applicable;
  final int done;

  bool counts(RolloutStep s) => applicable & (1 << s.index) != 0;
  bool has(RolloutStep s) => done & (1 << s.index) != 0;

  int get count => _bits(applicable);
  int get doneCount => _bits(done & applicable);
  double get share => count == 0 ? 0 : doneCount / count;

  static int _bits(int x) {
    var n = 0;
    for (var v = x; v != 0; v >>= 1) {
      n += v & 1;
    }
    return n;
  }
}

/// The album rollout (docs K165): singles ahead of the record, an early
/// announcement, a video, a teaser and a pitch. Each one tells more
/// people the album is coming; a full rollout opens it bigger.
abstract final class Rollouts {
  /// Hype a complete rollout adds at release.
  static const fullHype = 0.15;

  /// The lead single comes out at least this many weeks ahead, and the
  /// singles count up to [windowWeeks] before the record.
  static const leadWeeks = 4, windowWeeks = 26;

  /// The announcement comes at least this many weeks ahead.
  static const announceWeeks = 4;

  /// How [songIds] (out in [releaseWeek], announced in [announceWeek],
  /// -1: not) stand. With [planned], singles set for later count as done
  /// if they come out in time.
  static RolloutStatus status(World w, Artist a, List<int> songIds,
      int releaseWeek, int announceWeek,
      {bool planned = false}) {
    final year = GameTime.yearOf(w.week);
    var applicable = 0, done = 0;
    void mark(RolloutStep s, bool counts, bool ok) {
      if (!counts) return;
      applicable |= 1 << s.index;
      if (ok) done |= 1 << s.index;
    }

    final singleWeeks = <int>[];
    for (final id in songIds) {
      final s = w.songs[id];
      if (s.isSingle && s.singleWeek >= 0) singleWeeks.add(s.singleWeek);
    }
    if (planned) {
      for (final sr in a.scheduled) {
        if (sr.isAlbum || sr.isDraft) continue;
        if (songIds.contains(sr.songIds.single)) {
          singleWeeks.add(sr.releaseWeek);
        }
      }
    }
    final inWindow = [
      for (final wk in singleWeeks)
        if (wk <= releaseWeek && wk >= releaseWeek - windowWeeks) wk
    ];
    mark(RolloutStep.leadSingle, true,
        inWindow.any((wk) => wk <= releaseWeek - leadWeeks));
    mark(RolloutStep.secondSingle, true, inWindow.length >= 2);
    mark(RolloutStep.announced, true,
        announceWeek >= 0 && announceWeek <= releaseWeek - announceWeeks);
    mark(RolloutStep.video, true,
        songIds.any((id) => w.songs[id].videoBudget >= 0));
    mark(RolloutStep.teaser, year >= 2019,
        songIds.any((id) => w.songs[id].snippetWeek >= 0));
    mark(RolloutStep.pitch, StreamingTools.streamingOpen(w),
        songIds.any((id) => w.songs[id].pitchWeek >= 0));
    return RolloutStatus(applicable, done);
  }

  /// Whether a record of [type] has a rollout.
  static bool counts(AlbumType type, {bool live = false, bool hits = false}) =>
      (type == AlbumType.album || type == AlbumType.ep) && !live && !hits;

  /// [al] came out: scores its rollout and opens it bigger for it.
  static void apply(World w, Artist a, Album al, int announceWeek) {
    final st = status(w, a, al.songIds, al.releaseWeek, announceWeek);
    al.rolloutApplicable = st.applicable;
    al.rolloutDone = st.done;
    al.hypeAtRelease += fullHype * st.share;
    w.dirtyAlbums.add(al.id);
  }
}
