import 'package:simulation_core/simulation_core.dart';

/// What a to-do on the home page is about (docs K298).
enum TodoKind {
  /// The stations are still deciding on a single: its radio format and
  /// push can still change.
  radioDecide,

  /// A song can still be pitched to the playlist editors.
  pitch,

  /// A leaked song waits for an answer.
  leak,

  /// An album's anniversary: a reissue is possible.
  anniversary,

  /// The award submissions are open.
  awards,

  /// This week's lesson is not taken yet.
  practice,

  /// A scheduled release comes out soon.
  releaseSoon,
}

/// One thing worth doing this week, with how long it can wait.
class TodoItem {
  const TodoItem(this.kind,
      {this.songId = -1,
      this.albumId = -1,
      this.title = '',
      this.weeksLeft,
      this.more = 0});
  final TodoKind kind;
  final int songId;
  final int albumId;
  final String title;

  /// More of the same (songs to pitch) folded into this line.
  final int more;

  /// Weeks before it is too late (null: no deadline).
  final int? weeksLeft;
}

/// The home page's list of things to do this week (docs K298): windows
/// about to close first, then the rest.
abstract final class WeekTodo {
  static const maxItems = 6;

  static List<TodoItem> of(World w) {
    final p = w.player;
    if (p == null || w.playerRetiredWeek >= 0) return const [];
    final out = <TodoItem>[];
    // Singles that can still be pitched, folded into one line.
    final pitches = <TodoItem>[];
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != p.id || s.status == SongStatus.scrapped) {
        continue;
      }
      if (s.isSingle &&
          s.status == SongStatus.active &&
          s.singleWeek >= 0 &&
          w.week - s.singleWeek < Actions.radioUpgradeWeeks &&
          s.radioLevel < 0) {
        out.add(TodoItem(TodoKind.radioDecide,
            songId: s.id,
            title: s.title,
            weeksLeft: Actions.radioUpgradeWeeks - (w.week - s.singleWeek)));
      }
      if (s.isSingle &&
          s.releasedWeek >= 0 &&
          StreamingTools.canPitch(w, s)) {
        pitches.add(TodoItem(TodoKind.pitch,
            songId: s.id,
            title: s.title,
            weeksLeft: StreamingTools.pitchWindowWeeks -
                (w.week -
                    (s.singleWeek > s.releasedWeek
                        ? s.singleWeek
                        : s.releasedWeek))));
      }
      if (Leaks.canAnswer(s, w.week)) {
        out.add(TodoItem(TodoKind.leak, songId: s.id, title: s.title));
      }
    }
    if (pitches.isNotEmpty) {
      pitches.sort((a, b) => a.weeksLeft!.compareTo(b.weeksLeft!));
      final first = pitches.first;
      out.add(TodoItem(TodoKind.pitch,
          songId: first.songId,
          title: first.title,
          weeksLeft: first.weeksLeft,
          more: pitches.length - 1));
    }
    for (final al in w.albums) {
      if (al.artistId == p.id && Anniversaries.can(w, p, al)) {
        out.add(
            TodoItem(TodoKind.anniversary, albumId: al.id, title: al.title));
      }
    }
    if (Awards.submissionsOpen(w) &&
        w.awardSubmissions?.year != Awards.showYearOf(w.week)) {
      out.add(TodoItem(TodoKind.awards,
          weeksLeft:
              Awards.nominationsWeekOfYear - GameTime.weekOfYear(w.week)));
    }
    for (final sr in p.scheduled) {
      final left = sr.releaseWeek - w.week;
      if (left >= 0 && left <= 2) {
        out.add(TodoItem(TodoKind.releaseSoon,
            title: sr.isAlbum ? sr.title : w.songs[sr.songIds.single].title,
            weeksLeft: left));
      }
    }
    if (w.practiceWeek != w.week && p.restWeek != w.week) {
      out.add(const TodoItem(TodoKind.practice));
    }
    // Windows about to close first; the rest after, in their order.
    final order = [for (var i = 0; i < out.length; i++) i]..sort((a, b) {
        final x = out[a].weeksLeft ?? 1 << 20, y = out[b].weeksLeft ?? 1 << 20;
        return x != y ? x.compareTo(y) : a.compareTo(b);
      });
    return [for (final i in order.take(maxItems)) out[i]];
  }
}

/// The first career's guide (docs K297): the steps of a career in the
/// order a new player meets them, each done when the player has done it.
enum GuideStep {
  writeSong,
  releaseSingle,
  radio,
  charts,
  album,
  practice,
  tour,
}

class GuideView {
  const GuideView(this.done, {required this.latestSingle});

  /// Whether each [GuideStep] is done, by index.
  final List<bool> done;

  /// The player's latest single (for the radio step; -1: none).
  final int latestSingle;

  int get doneCount => done.where((d) => d).length;
  bool get finished => doneCount == done.length;

  /// The first step not done yet.
  GuideStep? get next {
    for (var i = 0; i < done.length; i++) {
      if (!done[i]) return GuideStep.values[i];
    }
    return null;
  }

  static GuideView of(World w) {
    final p = w.player!;
    var wrote = false, released = false, radio = false, charted = false;
    var latest = -1;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != p.id) continue;
      wrote = true;
      if (s.isSingle && s.releasedWeek >= 0) {
        released = true;
        if (latest < 0 || s.singleWeek >= w.songs[latest].singleWeek) {
          latest = s.id;
        }
        if (s.radioLevel >= 0 || s.radioPush != RadioPush.none) radio = true;
      }
      for (final ch in Charts.mainSongCharts) {
        if ((s.statsOrNull(ch)?.weeksOn ?? 0) > 0) charted = true;
      }
    }
    final album = w.albums.any((al) => al.artistId == p.id);
    // Eight weeks in, the charts have been seen, on them or not.
    if (released && w.week - w.playerSinceWeek >= 8) charted = true;
    return GuideView([
      wrote,
      released,
      radio,
      charted,
      album,
      w.practiceWeek >= 0,
      w.pastTours.isNotEmpty || p.tour != null,
    ], latestSingle: latest);
  }
}
