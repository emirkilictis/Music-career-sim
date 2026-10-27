import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/core/backup.dart';

void main() {
  test('a backup file keeps the database and the images (K219)', () async {
    final db = Uint8List.fromList(List.generate(70000, (i) => i * 7 % 256));
    final cover = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    final file =
        await CareerBackup(db, {'album_3': cover, 'artist_0_general': cover})
            .encode();
    expect(file.length, lessThan(db.length));
    final back = await CareerBackup.decode(file);
    expect(back.database, db);
    expect(back.images.keys, unorderedEquals(['album_3', 'artist_0_general']));
    expect(back.images['album_3'], cover);
  });

  test('other files are refused', () async {
    await expectLater(CareerBackup.decode(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    await expectLater(
        CareerBackup.decode(Uint8List.fromList(
            [0x1f, 0x8b, ...List.filled(30, 0)])),
        throwsFormatException);
  });

  test('file names come from the artist', () {
    expect(CareerBackup.fileName('Nova / Sky'), 'Nova Sky.mcsave');
    expect(CareerBackup.fileName('  '), 'career.mcsave');
  });
}
