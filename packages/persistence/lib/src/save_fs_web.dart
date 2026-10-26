import 'package:sqlite3/wasm.dart';

import 'save_fs.dart';

/// Saves in the browser (docs K218): SQLite compiled to WebAssembly on a
/// file system kept in IndexedDB; the small text files (career summaries,
/// the account) sit in one more database there.
class WebSaveFs extends SaveFs {
  WebSaveFs._(this._sqlite, this._fs, this._index);

  final WasmSqlite3 _sqlite;
  final IndexedDbFileSystem _fs;
  final CommonDatabase _index;

  /// Loads SQLite from [wasm] and the saves stored under [name].
  static Future<WebSaveFs> open(
      {required Uri wasm, String name = 'music-career-sim'}) async {
    final sqlite = await WasmSqlite3.loadFromUrl(wasm);
    final fs = await IndexedDbFileSystem.open(dbName: name);
    sqlite.registerVirtualFileSystem(fs, makeDefault: true);
    final index = sqlite.open('/index.db')
      ..execute('CREATE TABLE IF NOT EXISTS file '
          '(path TEXT PRIMARY KEY, text TEXT NOT NULL)');
    return WebSaveFs._(sqlite, fs, index);
  }

  @override
  bool exists(String path) =>
      _fs.xAccess(path, 0) != 0 ||
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
    // A slot holds one database and its journal.
    for (final name in const ['career.sqlite', 'career.sqlite-journal']) {
      final p = '$path/$name';
      if (_fs.xAccess(p, 0) != 0) _fs.xDelete(p, 0);
    }
    saved();
  }

  @override
  CommonDatabase openDatabase(String path) {
    final db = _sqlite.open(path);
    // No shared memory for WAL here: a rollback journal in the same store.
    db.execute('PRAGMA foreign_keys = OFF');
    return db;
  }

  @override
  void saved() => _fs.flush();
}
