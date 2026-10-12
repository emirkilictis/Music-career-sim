import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:game/game.dart';

/// What a command can use on the game side: the save slots and the open
/// career (docs/architecture.md §2).
class GameHost {
  GameHost(String slotsRoot) : slots = SaveSlots(Directory(slotsRoot));

  final SaveSlots slots;
  GameSession? session;

  GameSession get open {
    final s = session;
    if (s == null) throw StateError('No career is open');
    return s;
  }
}

/// Runs game commands away from the UI.
///
/// A command is a closure over [GameHost]. It must only capture sendable
/// values (numbers, strings, lists, SendPorts) — copy widget fields into
/// locals before building the closure.
abstract class GameController {
  Future<R> exec<R>(R Function(GameHost host) command);

  /// Shortcut for commands on the open career.
  Future<R> run<R>(R Function(GameSession s) command) =>
      exec((h) => command(h.open));

  Future<void> dispose();
}

/// Production controller: the game lives in a long-lived background isolate,
/// so a week (simulation + save) or a year skip never blocks the UI.
class IsolateGameController extends GameController {
  IsolateGameController._(this._isolate, this._send, this._replies);

  final Isolate _isolate;
  final SendPort _send;
  final ReceivePort _replies;
  final Map<int, Completer<Object?>> _pending = {};
  int _next = 0;

  static Future<IsolateGameController> spawn(String slotsRoot) async {
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    final isolate = await Isolate.spawn(_main, (slotsRoot, replies.sendPort),
        debugName: 'game');
    late final IsolateGameController c;
    replies.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
        return;
      }
      final (id, ok, value, stack) = msg as (int, bool, Object?, String?);
      final done = c._pending.remove(id);
      if (done == null) return;
      if (ok) {
        done.complete(value);
      } else {
        done.completeError(
            value!, stack == null ? null : StackTrace.fromString(stack));
      }
    });
    c = IsolateGameController._(isolate, await ready.future, replies);
    return c;
  }

  static void _main((String, SendPort) args) {
    final (root, reply) = args;
    final host = GameHost(root);
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    inbox.listen((msg) {
      final (id, command) = msg as (int, Object? Function(GameHost));
      try {
        reply.send((id, true, command(host), null));
      } on GameException catch (e, st) {
        reply.send((id, false, e, st.toString()));
      } catch (e, st) {
        reply.send((id, false, StateError('$e'), st.toString()));
      }
    });
  }

  @override
  Future<R> exec<R>(R Function(GameHost host) command) async {
    final id = _next++;
    final done = Completer<Object?>();
    _pending[id] = done;
    _send.send((id, (GameHost h) => command(h)));
    return (await done.future) as R;
  }

  @override
  Future<void> dispose() async {
    try {
      await exec((h) {
        h.session?.close();
        h.session = null;
      });
    } finally {
      _isolate.kill();
      _replies.close();
    }
  }
}

/// Same-isolate controller for tests and tools.
class LocalGameController extends GameController {
  LocalGameController(String slotsRoot) : host = GameHost(slotsRoot);

  final GameHost host;

  @override
  Future<R> exec<R>(R Function(GameHost host) command) async => command(host);

  @override
  Future<void> dispose() async {
    host.session?.close();
    host.session = null;
  }
}
