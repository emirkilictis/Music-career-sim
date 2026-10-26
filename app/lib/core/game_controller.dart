import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:game/game.dart';

/// What a command can use on the game side: the save slots and the open
/// career (docs/architecture.md §2).
class GameHost {
  GameHost(String slotsRoot) : slots = SaveSlots(Directory(slotsRoot));

  /// On given slots (the browser's on the web; docs K218).
  GameHost.on(this.slots);

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
  Future<R> exec<R>(FutureOr<R> Function(GameHost host) command);

  /// Shortcut for commands on the open career.
  Future<R> run<R>(FutureOr<R> Function(GameSession s) command) =>
      exec((h) => command(h.open));

  /// Where a long command (a new world, a skip) reports progress to
  /// [onMessage]; close it when the command is done.
  ProgressChannel progressChannel(void Function(Object? message) onMessage);

  Future<void> dispose();
}

/// Where a long command reports its progress (docs K218): a port back to
/// the UI isolate, or a callback when the game runs on the UI's thread
/// (the web).
abstract interface class ProgressSink {
  void send(Object? message);
}

typedef ProgressChannel = ({ProgressSink sink, void Function() close});

class PortSink implements ProgressSink {
  PortSink(this.port);
  final SendPort port;
  @override
  void send(Object? message) => port.send(message);
}

class _CallbackSink implements ProgressSink {
  _CallbackSink(this.onMessage);
  final void Function(Object? message) onMessage;
  @override
  void send(Object? message) => onMessage(message);
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
    // One command at a time, even one that waits in between (docs K218).
    var queue = Future<void>.value();
    inbox.listen((msg) {
      final (id, command) = msg as (int, FutureOr<Object?> Function(GameHost));
      queue = queue.then((_) async {
        try {
          reply.send((id, true, await command(host), null));
        } on GameException catch (e, st) {
          reply.send((id, false, e, st.toString()));
        } catch (e, st) {
          reply.send((id, false, StateError('$e'), st.toString()));
        }
      });
    });
  }

  @override
  ProgressChannel progressChannel(void Function(Object? message) onMessage) {
    final port = ReceivePort()..listen(onMessage);
    return (sink: PortSink(port.sendPort), close: port.close);
  }

  @override
  Future<R> exec<R>(FutureOr<R> Function(GameHost host) command) async {
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

  /// On given slots: the web runs the game on the UI's thread (docs K218).
  LocalGameController.on(SaveSlots slots) : host = GameHost.on(slots);

  final GameHost host;

  @override
  ProgressChannel progressChannel(void Function(Object? message) onMessage) =>
      (sink: _CallbackSink(onMessage), close: () {});

  @override
  Future<R> exec<R>(FutureOr<R> Function(GameHost host) command) async =>
      command(host);

  @override
  Future<void> dispose() async {
    host.session?.close();
    host.session = null;
  }
}
