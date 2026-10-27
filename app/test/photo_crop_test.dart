import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/widgets/photo_crop.dart';

void main() {
  test('image sizes come from PNG and JPEG headers (K221)', () {
    final png = Uint8List(33)
      ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
      ..setAll(16, [0, 0, 0x06, 0x40, 0, 0, 0x03, 0x84]);
    expect(imageSize(png), (1600, 900));
    final jpeg = Uint8List.fromList([
      0xFF, 0xD8, // start
      0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, 2 bytes of data
      0xFF, 0xC4, 0x00, 0x04, 0x00, 0x00, // a Huffman table, not a frame
      0xFF, 0xC2, 0x00, 0x11, 0x08, 0x0F, 0xC0, 0x0B, 0xD0, // 4032×3024
      ...List.filled(12, 0),
    ]);
    expect(imageSize(jpeg), (3024, 4032));
    expect(imageSize(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
