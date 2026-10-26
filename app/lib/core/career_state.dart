import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:game/game.dart';

import 'commands.dart';
import 'event_lines.dart';
import 'game_controller.dart';
import '../widgets/art.dart';

/// The open career as the UI sees it: a cached player snapshot that is
/// refreshed after every command, plus the latest week's news.
class CareerState extends ChangeNotifier {
  CareerState(this.controller);

  final GameController controller;

  ArtistView? _player;
  int week = 0;

  /// Save slot of this career (for its images folder).
  String? slotId;
  Difficulty difficulty = Difficulty.normal;

  /// The player before the last played week or skip, for "what changed".
  ArtistView? before;

  /// News of the last played week (most important first).
  List<EventLine> lastEvents = const [];
  int lastWeekPlayed = -1;
  int lastMoneyDelta = 0;

  /// Royalties that paid back the label's advance last week (K107).
  int lastRecouped = 0;

  /// Called when a scheduled album comes out (moves its advance cover).
  void Function(int scheduleId, int albumId)? onScheduledAlbumOut;

  void _adoptCovers(List<EventLine> lines) {
    for (final (scheduleId, albumId) in scheduledAlbumsOut(lines)) {
      onScheduledAlbumOut?.call(scheduleId, albumId);
    }
  }

  /// Bumped on every change so screens know to reload their own data.
  int revision = 0;
  bool busy = false;

  ArtistView get player => _player!;
  bool get loaded => _player != null;
  int get year => GameTime.yearOf(week);
  int get weekOfYear => GameTime.weekOfYear(week);

  int _groupsWeek = -1;

  Future<void> refresh() async {
    slotId ??= await controller.run(Cmd.slotId());
    final (p, w, d) = await controller.run(Cmd.snapshot());
    // Bands' drawn avatars (docs K212): new groups debut now and then.
    if (_groupsWeek < 0 || w - _groupsWeek >= 4 || w < _groupsWeek) {
      ArtistAvatar.groupSizes = await controller.run(Cmd.groupSizes());
      _groupsWeek = w;
    }
    // After going solo the player is someone else: no "what changed" from
    // the group (docs K191).
    if (_player != null && _player!.id != p.id) before = null;
    _player = p;
    week = w;
    difficulty = d;
    revision++;
    notifyListeners();
  }

  /// Reads data without changing anything (no busy state).
  Future<R> read<R>(SessionCmd<R> command) => controller.run(command);

  /// Runs a player action (built with [Cmd]) and refreshes. Rule errors
  /// ([GameException]) are passed on for the caller to show.
  Future<R> act<R>(SessionCmd<R> command) async {
    _setBusy(true);
    try {
      final r = await controller.run(command);
      await refresh();
      return r;
    } finally {
      _setBusy(false);
    }
  }

  /// Plays one week; returns its news.
  Future<List<EventLine>> nextWeek() async {
    if (busy) return const [];
    _setBusy(true);
    before = _player;
    try {
      final (week, lines, delta, recouped) =
          await controller.run(Cmd.nextWeek());
      lastRecouped = recouped;
      _adoptCovers(lines);
      lastEvents = sortLines(playerNews(lines));
      lastWeekPlayed = week;
      lastMoneyDelta = delta;
      await refresh();
      return lastEvents;
    } finally {
      _setBusy(false);
    }
  }

  /// Skips up to [weeks] weeks (see [SkipStop]); [onProgress] gets weeks
  /// played. A year skip keeps only the big news; a short skip keeps all of
  /// the player's news.
  Future<(YearReport, List<EventLine>)> skip(
      int weeks, SkipStop stop, void Function(int weeks) onProgress) async {
    _setBusy(true);
    before = _player;
    final port = ReceivePort()..listen((m) => onProgress(m as int));
    try {
      final result =
          await controller.run(Cmd.skipWeeks(weeks, stop, port.sendPort));
      final y = result.$1;
      _adoptCovers(result.$2);
      final news = playerNews(result.$2);
      lastEvents = sortLines(
          y.isYear ? news.where((l) => l.event.isMajor).toList() : news);
      lastWeekPlayed = y.fromWeek + y.weeks - 1;
      lastMoneyDelta = y.moneyDeltaCents;
      await refresh();
      return result;
    } finally {
      port.close();
      _setBusy(false);
    }
  }

  void _setBusy(bool b) {
    busy = b;
    notifyListeners();
  }
}
