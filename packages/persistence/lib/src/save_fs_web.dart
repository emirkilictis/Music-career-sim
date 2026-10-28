import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'dart:math' as math;

import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

import 'save_fs.dart';

/// Saves in the browser (docs K218): SQLite compiled to WebAssembly runs on
/// files kept in memory, and each changed file goes to IndexedDB whole, a
/// moment after the last save and whenever the page is hidden. (SQLite's
/// own IndexedDB file system wrote a new career block by block, for over a
/// minute.) A career's database is read in only when it is opened.
///
/// The files live in the browser's own byte arrays ([_JsFiles]), so
/// SQLite's page reads and writes are plain array copies.
class WebSaveFs extends SaveFs {
  WebSaveFs._(this._sqlite, this._memory, this._name, this._db, this._stored) {
    _watch(_db!);
  }

  final WasmSqlite3 _sqlite;
  final _JsFiles _memory;
  final String _name;

  /// The IndexedDB connection; null once the browser closed it (Safari
  /// does when a page sits in the background), until it is reopened
  /// (docs K240).
  web.IDBDatabase? _db;
  Future<web.IDBDatabase>? _reopening;

  /// Paths stored in IndexedDB (loaded or not).
  final Set<String> _stored;
  final Set<String> _dirty = {};
  Timer? _timer;
  late final CommonDatabase _index;

  static const _store = 'files';
  static const indexPath = '/index.db';

  /// Loads SQLite from [wasm] and the saves stored under [name].
  static Future<WebSaveFs> open(
      {required Uri wasm, String name = 'music-career-sim'}) async {
    final sqlite = await WasmSqlite3.loadFromUrl(wasm);
    final memory = _JsFiles();
    sqlite.registerVirtualFileSystem(memory, makeDefault: true);
    final db = await _openDb(name);
    // Ask the browser to keep the saves when it runs short of space.
    try {
      web.window.navigator.storage.persist();
    } catch (_) {}
    final keys = (await _done(
            db.transaction(_store.toJS).objectStore(_store).getAllKeys()))
        as JSArray<JSString>;
    final fs = WebSaveFs._(
        sqlite, memory, name, db, {for (final k in keys.toDart) k.toDart});
    await fs.prepare(indexPath);
    fs._index = sqlite.open(indexPath)
      ..execute('PRAGMA journal_mode = MEMORY')
      ..execute('CREATE TABLE IF NOT EXISTS file '
          '(path TEXT PRIMARY KEY, text TEXT NOT NULL)');
    // A hidden page may be closed without warning: store everything now.
    web.document.addEventListener(
        'visibilitychange',
        ((web.Event _) {
          if (web.document.visibilityState == 'hidden') fs.persist();
        }).toJS);
    web.window
        .addEventListener('pagehide', ((web.Event _) => fs.persist()).toJS);
    return fs;
  }

  static Future<web.IDBDatabase> _openDb(String name) async {
    final request = web.window.indexedDB.open(name, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    return (await _done(request)) as web.IDBDatabase;
  }

  /// Forgets [db] when the browser closes it.
  void _watch(web.IDBDatabase db) {
    db.onclose = ((web.Event _) {
      if (identical(_db, db)) _db = null;
    }).toJS;
  }

  Future<web.IDBDatabase> _reopen() => _reopening ??= _openDb(_name).then(
        (db) {
          _db = db;
          _watch(db);
          _reopening = null;
          return db;
        },
        onError: (Object e) {
          _reopening = null;
          throw e;
        },
      );

  /// A transaction on the store, or null when the connection is gone
  /// ("The database connection is closing"); it is then reopened.
  web.IDBTransaction? _tx(String mode) {
    final db = _db;
    if (db != null) {
      try {
        return db.transaction(_store.toJS, mode);
      } catch (_) {
        _db = null;
      }
    }
    _reopen().ignore();
    return null;
  }

  /// [_tx], waiting for the connection to come back.
  Future<web.IDBTransaction> _txAsync(String mode) async =>
      _tx(mode) ?? (await _reopen()).transaction(_store.toJS, mode);

  /// Runs [f] on the store now, or once the connection is back.
  void _write(void Function(web.IDBObjectStore store) f) {
    final tx = _tx('readwrite');
    if (tx != null) {
      f(tx.objectStore(_store));
    } else {
      _txAsync('readwrite').then((t) => f(t.objectStore(_store))).ignore();
    }
  }

  /// Reads [path] in from IndexedDB, if it is stored and not loaded yet.
  @override
  Future<void> prepare(String path) async {
    if (_memory.fileData.containsKey(path) || !_stored.contains(path)) return;
    final value = await _done(
        (await _txAsync('readonly')).objectStore(_store).get(path.toJS));
    if (value == null) return;
    final bytes = (value as JSArrayBuffer).toDart.asUint8List();
    _memory.fileData[path] = _JsFile(bytes, bytes.length);
  }

  /// Text files under [prefix] (path → text), for the browser's image
  /// store.
  Map<String, String> textsUnder(String prefix) => {
        for (final r in _index.select(
            'SELECT path, text FROM file WHERE path LIKE ?', ['$prefix%']))
          r['path'] as String: r['text'] as String
      };

  void deleteText(String path) {
    _index.execute('DELETE FROM file WHERE path = ?', [path]);
    saved();
  }

  @override
  bool exists(String path) =>
      _memory.fileData.containsKey(path) ||
      _stored.contains(path) ||
      _index.select('SELECT 1 FROM file WHERE path = ? OR path LIKE ?',
          [path, '$path/%']).isNotEmpty;

  @override
  String? readText(String path) {
    final r = _index.select('SELECT text FROM file WHERE path = ?', [path]);
    return r.isEmpty ? null : r.first['text'] as String;
  }

  @override
  void writeText(String path, String text) {
    _index.execute(
        'INSERT OR REPLACE INTO file (path, text) VALUES (?, ?)', [path, text]);
    saved();
  }

  @override
  Uint8List? readBytes(String path) => _memory.fileData[path]?.copy();

  @override
  void writeBytes(String path, Uint8List bytes) {
    final f = _JsFile(_JsFile._alloc(bytes.length), bytes.length);
    f.bytes.setRange(0, bytes.length, bytes);
    _memory.fileData[path] = f;
    saved();
  }

  @override
  void deleteFile(String path) {
    _memory.fileData.remove(path);
    _dirty.remove(path);
    if (_stored.remove(path)) _write((store) => store.delete(path.toJS));
  }

  @override
  List<String> folders(String path) {
    final prefix = '$path/';
    final out = <String>{};
    for (final r in _index
        .select('SELECT path FROM file WHERE path LIKE ?', ['$prefix%'])) {
      final rest = (r['path'] as String).substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash > 0) out.add(rest.substring(0, slash));
    }
    return out.toList();
  }

  @override
  void makeFolder(String path) {}

  @override
  void deleteFolder(String path) {
    _index.execute('DELETE FROM file WHERE path LIKE ?', ['$path/%']);
    final gone = [
      for (final p in {..._memory.fileData.keys, ..._stored})
        if (p.startsWith('$path/')) p
    ];
    final drop = <String>[];
    for (final p in gone) {
      _memory.fileData.remove(p);
      _dirty.remove(p);
      if (_stored.remove(p)) drop.add(p);
    }
    if (drop.isNotEmpty) {
      _write((store) {
        for (final p in drop) {
          store.delete(p.toJS);
        }
      });
    }
    saved();
  }

  @override
  CommonDatabase openDatabase(String path) {
    final db = _sqlite.open(path);
    // The journal stays in memory: the file goes to IndexedDB whole.
    db.execute('PRAGMA journal_mode = MEMORY');
    db.execute('PRAGMA foreign_keys = OFF');
    return db;
  }

  /// Every loaded file may have changed: store them at most a moment
  /// after the first unstored save. (Waiting for the saves to pause never
  /// stored a player who kept pressing Next week, and a phone may drop a
  /// hidden page before the last write ends.)
  @override
  void saved() {
    for (final p in _memory.fileData.keys) {
      if (!p.endsWith('-journal')) _dirty.add(p);
    }
    _timer ??= Timer(const Duration(seconds: 1), persist);
  }

  /// Writes the changed files to IndexedDB now.
  void persist() {
    _timer?.cancel();
    _timer = null;
    if (_dirty.isEmpty) return;
    final paths = _dirty.toList();
    _dirty.clear();
    // A failed write (storage full, a page being closed) is tried again.
    void retry([Duration wait = const Duration(seconds: 5)]) {
      _dirty.addAll(paths.where(_memory.fileData.containsKey));
      _timer ??= Timer(wait, persist);
    }

    // One transaction: the save list and the careers change together.
    final tx = _tx('readwrite');
    if (tx == null) {
      // The browser closed the connection: write once it is back.
      retry(const Duration(seconds: 1));
      return;
    }
    try {
      final store = tx.objectStore(_store);
      for (final p in paths) {
        final data = _memory.fileData[p];
        if (data == null) continue;
        // A copy of the file's bytes: SQLite may change them meanwhile.
        store.put(data.copy().buffer.toJS, p.toJS);
        _stored.add(p);
      }
    } catch (_) {
      _db = null;
      retry(const Duration(seconds: 1));
      return;
    }
    tx.onerror = ((web.Event _) => retry()).toJS;
    tx.onabort = ((web.Event _) => retry()).toJS;
  }

  static Future<JSAny?> _done(web.IDBRequest request) {
    final c = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => c.complete(request.result)).toJS;
    request.onerror =
        ((web.Event _) => c.completeError(StateError('${request.error}'))).toJS;
    return c.future;
  }
}

/// A file's bytes in a browser array, with room to grow: the first
/// [length] bytes are the file.
class _JsFile {
  _JsFile(this.bytes, this.length);
  Uint8List bytes;
  int length;

  /// A browser array, not one in Dart's memory: copies between it and
  /// SQLite's memory (also a browser array) are one native copy each. A
  /// copy from a Dart array to a browser one goes byte by byte (dart2wasm).
  static Uint8List _alloc(int n) => JSUint8Array.withLength(n).toDart;

  void resize(int n) {
    if (n > bytes.length) {
      final grown = _alloc(math.max(n, bytes.length * 2));
      grown.setRange(0, length, bytes);
      bytes = grown;
    } else if (n < length) {
      bytes.fillRange(n, length, 0);
    }
    length = n;
  }

  Uint8List copy() => _alloc(length)..setRange(0, length, bytes);
}

/// SQLite's files kept in memory, in browser arrays (see [_JsFile]).
final class _JsFiles extends BaseVirtualFileSystem {
  _JsFiles() : super(name: 'mcs-memory');

  final Map<String, _JsFile> fileData = {};

  @override
  int xAccess(String path, int flags) => fileData.containsKey(path) ? 1 : 0;

  @override
  void xDelete(String path, int syncDir) => fileData.remove(path);

  @override
  String xFullPathName(String path) => path.startsWith('/') ? path : '/$path';

  @override
  XOpenResult xOpen(Sqlite3Filename path, int flags) {
    final name = path.path ?? random.nextInt(1 << 31).toRadixString(36);
    final full = name.startsWith('/') ? name : '/$name';
    if (!fileData.containsKey(full)) {
      if (flags & SqlFlag.SQLITE_OPEN_CREATE == 0) {
        throw VfsException(SqlError.SQLITE_CANTOPEN);
      }
      fileData[full] = _JsFile(_JsFile._alloc(0), 0);
    }
    return (
      outFlags: 0,
      file: _JsFileHandle(
          this, full, flags & SqlFlag.SQLITE_OPEN_DELETEONCLOSE != 0),
    );
  }

  @override
  void xSleep(Duration duration) {}
}

class _JsFileHandle extends BaseVfsFile {
  _JsFileHandle(this.vfs, this.path, this.deleteOnClose);
  final _JsFiles vfs;
  final String path;
  final bool deleteOnClose;
  var _lock = SqlFileLockingLevels.SQLITE_LOCK_NONE;

  @override
  int readInto(Uint8List buffer, int offset) {
    final f = vfs.fileData[path];
    if (f == null || f.length <= offset) return 0;
    final n = math.min(buffer.length, f.length - offset);
    buffer.setRange(0, n, f.bytes, offset);
    return n;
  }

  @override
  void xWrite(Uint8List buffer, int fileOffset) {
    final f =
        vfs.fileData.putIfAbsent(path, () => _JsFile(_JsFile._alloc(0), 0));
    final end = fileOffset + buffer.length;
    if (end > f.length) f.resize(end);
    f.bytes.setRange(fileOffset, end, buffer);
  }

  @override
  void xTruncate(int size) => vfs.fileData
      .putIfAbsent(path, () => _JsFile(_JsFile._alloc(0), 0))
      .resize(size);

  @override
  int xFileSize() => vfs.fileData[path]?.length ?? 0;

  @override
  int xCheckReservedLock() =>
      _lock >= SqlFileLockingLevels.SQLITE_LOCK_RESERVED ? 1 : 0;

  @override
  void xClose() {
    if (deleteOnClose) vfs.xDelete(path, 0);
  }

  @override
  void xLock(int mode) => _lock = mode;

  @override
  void xUnlock(int mode) => _lock = mode;

  @override
  void xSync(int flags) {}
}
