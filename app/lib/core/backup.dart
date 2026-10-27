import 'dart:convert';
import 'dart:typed_data';

import 'platform_files.dart';

/// A career backup file (docs K219): the career's database and the
/// player's own images (covers, photos), gzipped. The same file restores
/// on the phone app and in the browser.
class CareerBackup {
  CareerBackup(this.database, this.images);

  final Uint8List database;

  /// Image key (ImageStore) → the image file's bytes.
  final Map<String, Uint8List> images;

  static const extension = 'mcsave';
  static const _magic = 'MCS1';
  static const _database = 'career.sqlite';
  static const _image = 'image/';

  /// The file: "MCS1", then per entry a name and its bytes, each after
  /// its length (2 and 4 bytes), all gzipped.
  Future<Uint8List> encode() async {
    final entries = <(List<int>, Uint8List)>[
      (utf8.encode(_database), database),
      for (final e in images.entries) (utf8.encode('$_image${e.key}'), e.value),
    ];
    var size = _magic.length;
    for (final (name, data) in entries) {
      size += 2 + name.length + 4 + data.length;
    }
    final out = newBytes(size);
    final view = ByteData.sublistView(out);
    out.setRange(0, _magic.length, ascii.encode(_magic));
    var at = _magic.length;
    for (final (name, data) in entries) {
      view.setUint16(at, name.length);
      at += 2;
      out.setRange(at, at + name.length, name);
      at += name.length;
      view.setUint32(at, data.length);
      at += 4;
      out.setRange(at, at + data.length, data);
      at += data.length;
    }
    return gzipBytes(out);
  }

  /// Reads a backup file; throws [FormatException] if it is not one.
  static Future<CareerBackup> decode(Uint8List file) async {
    // gzip files start with 1F 8B.
    if (file.length < 18 || file[0] != 0x1f || file[1] != 0x8b) {
      throw const FormatException('Not a career backup');
    }
    final Uint8List raw;
    try {
      raw = await gunzipBytes(file);
    } catch (_) {
      throw const FormatException('Not a career backup');
    }
    if (raw.length < 4 || ascii.decode(raw.sublist(0, 4)) != _magic) {
      throw const FormatException('Not a career backup');
    }
    final view = ByteData.sublistView(raw);
    Uint8List? database;
    final images = <String, Uint8List>{};
    var at = 4;
    try {
      while (at < raw.length) {
        final n = view.getUint16(at);
        at += 2;
        final name = utf8.decode(raw.sublist(at, at + n));
        at += n;
        final len = view.getUint32(at);
        at += 4;
        if (at + len > raw.length) throw RangeError('entry past the end');
        final data = raw.sublist(at, at + len);
        at += len;
        if (name == _database) {
          database = data;
        } else if (name.startsWith(_image)) {
          images[name.substring(_image.length)] = data;
        }
      }
    } on RangeError {
      throw const FormatException('A damaged career backup');
    }
    if (database == null) throw const FormatException('No career inside');
    return CareerBackup(database, images);
  }

  /// A file name from the artist's name: "Nova Sky.mcsave".
  static String fileName(String artist) {
    final clean = artist
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${clean.isEmpty ? 'career' : clean}.$extension';
  }
}
