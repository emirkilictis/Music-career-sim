import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:game/game.dart';

import 'commands.dart';
import 'event_lines.dart';
import 'game_controller.dart';

/// The open career as the UI sees it: a cached player snapshot that is
/// refreshed after every command, plus the latest week's news.
class CareerState extends ChangeNotifier {
  CareerState(this.controller);

  final GameController controller;

  ArtistView? _player;
  int week = 0;
  Difficulty difficulty = Difficulty.normal;

  /// News of the last played week (most important first).
  List<EventLine> lastEvents = const [];
  int lastWeekPlayed = -1;
  int lastMoneyDelta = 0;

  /// Bumped on every change so screens know to reload their own data.
  int revision = 0;
  bool busy = false;

  ArtistView get player => _player!;
  bool get loaded => _player != null;
  int get year => GameTime.yearOf(week);
  int get weekOfYear => GameTime.weekOfYear(week);

  Future<void> refresh() async {
    final (p, w, d) = await controller.run(Cmd.snapshot());
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
    try {
      final (week, lines, delta) = await controller.run(Cmd.nextWeek());
      lastEvents = sortLines(lines);
      lastWeekPlayed = week;
      lastMoneyDelta = delta;
      await refresh();
      return lastEvents;
    } finally {
      _setBusy(false);
    }
  }

  /// Year skip (stops at a major event); [onProgress] gets weeks played.
  Future<(YearReport, List<EventLine>)> skipYear(
      void Function(int weeks) onProgress) async {
    _setBusy(true);
    final port = ReceivePort()..listen((m) => onProgress(m as int));
    try {
      final result = await controller.run(Cmd.skipYear(port.sendPort));
      final y = result.$1;
      lastEvents = sortLines(result.$2.where((l) => l.event.isMajor).toList());
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
