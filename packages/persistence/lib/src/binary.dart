import 'dart:convert';
import 'dart:typed_data';

/// Compact binary encoding for rows of (int | double | String | null).
/// Used for the weekly hot-state snapshot: one contiguous blob instead of
/// thousands of scattered row updates.
class RowWriter {
  Uint8List _buf = Uint8List(1 << 16);
  late ByteData _view = ByteData.sublistView(_buf);
  int _pos = 0;

  void _ensure(int n) {
    if (_pos + n <= _buf.length) return;
    var size = _buf.length * 2;
    while (size < _pos + n) {
      size *= 2;
    }
    final next = Uint8List(size)..setRange(0, _pos, _buf);
    _buf = next;
    _view = ByteData.sublistView(_buf);
  }

  void _u8(int v) {
    _ensure(1);
    _buf[_pos++] = v;
  }

  void _i64(int v) {
    _ensure(8);
    _view.setInt64(_pos, v, Endian.little);
    _pos += 8;
  }

  void _f64(double v) {
    _ensure(8);
    _view.setFloat64(_pos, v, Endian.little);
    _pos += 8;
  }

  void row(List<Object?> values) {
    _i64(values.length);
    for (final v in values) {
      switch (v) {
        case null:
          _u8(0);
        case final int i:
          _u8(1);
          _i64(i);
        case final double d:
          _u8(2);
          _f64(d);
        case final String s:
          final bytes = utf8.encode(s);
          _u8(3);
          _i64(bytes.length);
          _ensure(bytes.length);
          _buf.setRange(_pos, _pos + bytes.length, bytes);
          _pos += bytes.length;
        default:
          throw ArgumentError('Unsupported value ${v.runtimeType}');
      }
    }
  }

  void count(int n) => _i64(n);

  Uint8List takeBytes() => Uint8List.sublistView(_buf, 0, _pos);
}

class RowReader {
  RowReader(Uint8List bytes)
      : _bytes = bytes,
        _view = ByteData.sublistView(bytes);

  final Uint8List _bytes;
  final ByteData _view;
  int _pos = 0;

  int _i64() {
    final v = _view.getInt64(_pos, Endian.little);
    _pos += 8;
    return v;
  }

  int count() => _i64();

  /// Reads one row as a column-name map (same shape as a database row).
  Map<String, Object?> row(List<String> columns) {
    final n = _i64();
    assert(n == columns.length);
    final m = <String, Object?>{};
    for (var i = 0; i < n; i++) {
      final tag = _bytes[_pos++];
      m[columns[i]] = switch (tag) {
        0 => null,
        1 => _i64(),
        2 => () {
            final d = _view.getFloat64(_pos, Endian.little);
            _pos += 8;
            return d;
          }(),
        3 => () {
            final len = _i64();
            final s = utf8.decode(_bytes.sublist(_pos, _pos + len));
            _pos += len;
            return s;
          }(),
        _ => throw StateError('Bad tag $tag'),
      };
    }
    return m;
  }
}
