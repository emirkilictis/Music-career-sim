import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import 'save_fs.dart';

/// Saves as folders and SQLite files on the device (docs K218).
class IoSaveFs extends SaveFs {
  @override
  bool exists(String path) =>
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  @override
  String? readText(String path) {
    final f = File(path);
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  @override
  void writeText(String path, String text) {
    final f = File(path);
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  }

  @override
  Uint8List? readBytes(String path) {
    final f = File(path);
    return f.existsSync() ? f.readAsBytesSync() : null;
  }

  @override
  void writeBytes(String path, Uint8List bytes) {
    final f = File(path);
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes, flush: true);
  }

  @override
  void deleteFile(String path) {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }

  @override
  List<String> folders(String path) {
    final d = Directory(path);
    if (!d.existsSync()) return const [];
    return [
      for (final e in d.listSync().whereType<Directory>())
        e.uri.pathSegments.where((s) => s.isNotEmpty).last
    ];
  }

  @override
  void makeFolder(String path) => Directory(path).createSync(recursive: true);

  @override
  void deleteFolder(String path) {
    final d = Directory(path);
    if (d.existsSync()) d.deleteSync(recursive: true);
  }

  @override
  CommonDatabase openDatabase(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = NORMAL');
    // Checkpoint the WAL ourselves every few weeks instead of on random
    // commits (each checkpoint syncs the database file).
    db.execute('PRAGMA wal_autocheckpoint = 0');
    db.execute('PRAGMA foreign_keys = OFF');
    return db;
  }
}

SaveFs defaultSaveFs() => IoSaveFs();
