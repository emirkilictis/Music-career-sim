import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart';
import 'package:web/web.dart' as web;

import 'save_fs.dart';

/// Saves in the browser (docs K218): SQLite compiled to WebAssembly runs on
/// files kept in memory, and each changed file goes to IndexedDB whole, a
/// moment after the last save and whenever the page is hidden. (SQLite's
/// own IndexedDB file system wrote a new career block by block, for over a
/// minute.) A career's database is read in only when it is opened.
class WebSaveFs extends SaveFs {
  WebSaveFs._(this._sqlite, this._memory, this._db, this._stored);

  final WasmSqlite3 _sqlite;
  final InMemoryFileSystem _memory;
  final web.IDBDatabase _db;

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
    final memory = InMemoryFileSystem();
    sqlite.registerVirtualFileSystem(memory, makeDefault: true);
    final request = web.window.indexedDB.open(name, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    final db = (await _done(request)) as web.IDBDatabase;
    final keys = (await _done(
            db.transaction(_store.toJS).objectStore(_store).getAllKeys()))
        as JSArray<JSString>;
    final fs = WebSaveFs._(
        sqlite, memory, db, {for (final k in keys.toDart) k.toDart});
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
    web.window.addEventListener(
        'pagehide', ((web.Event _) => fs.persist()).toJS);
    return fs;
  }

  /// Reads [path] in from IndexedDB, if it is stored and not loaded yet.
  @override
  Future<void> prepare(String path) async {
    if (_memory.fileData.containsKey(path) || !_stored.contains(path)) return;
    final value = await _done(
        _db.transaction(_store.toJS).objectStore(_store).get(path.toJS));
    if (value == null) return;
    final bytes = (value as JSArrayBuffer).toDart.asUint8List();
    // Typed copies: an element-by-element one of 25 MB takes seconds.
    _memory.fileData[path] = Uint8Buffer(bytes.length)
      ..setRange(0, bytes.length, bytes);
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
    final store = _db.transaction(_store.toJS, 'readwrite').objectStore(_store);
    for (final p in gone) {
      _memory.fileData.remove(p);
      _dirty.remove(p);
      if (_stored.remove(p)) store.delete(p.toJS);
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

  /// Every loaded file may have changed: store them a moment after the
  /// last save (a skip saves every week).
  @override
  void saved() {
    for (final p in _memory.fileData.keys) {
      if (!p.endsWith('-journal')) _dirty.add(p);
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), persist);
  }

  /// Writes the changed files to IndexedDB now.
  void persist() {
    _timer?.cancel();
    _timer = null;
    if (_dirty.isEmpty) return;
    final store = _db.transaction(_store.toJS, 'readwrite').objectStore(_store);
    for (final p in _dirty) {
      final data = _memory.fileData[p];
      if (data == null) continue;
      final bytes = Uint8List(data.length)
        ..setRange(0, data.length, data.buffer.asUint8List(0, data.length));
      store.put(bytes.buffer.toJS, p.toJS);
      _stored.add(p);
    }
    _dirty.clear();
  }

  static Future<JSAny?> _done(web.IDBRequest request) {
    final c = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => c.complete(request.result)).toJS;
    request.onerror =
        ((web.Event _) => c.completeError(StateError('${request.error}')))
            .toJS;
    return c.future;
  }
}
