import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/core/images.dart';

void main() {
  test('an adopted scheduled cover stays with its album after reopening', () {
    final root = Directory.systemTemp.createTempSync('images_');
    addTearDown(() => root.deleteSync(recursive: true));
    final src = File('${root.path}/pick.jpg')..writeAsBytesSync([1, 2, 3]);

    var store = ImageStore(root.path)..open('slot1');
    store.save(ImageStore.scheduledKey(7000), src.path);
    store.save(
        ImageStore.editionKey(ImageStore.scheduledKey(7000), 1), src.path);
    expect(store.scheduledCoverIds, [7000]);

    store.adoptWithEditions(
        ImageStore.scheduledKey(7000), ImageStore.albumKey(3));
    expect(store.albumCover(3), isNotNull);
    expect(store.scheduledCoverIds, isEmpty);
    store.close();

    // Reopened (the app restarted): the files carry the album's name.
    store = ImageStore(root.path)..open('slot1');
    expect(store.albumCover(3), isNotNull);
    expect(store.path(ImageStore.editionKey(ImageStore.albumKey(3), 1)),
        isNotNull);
    expect(store.scheduledCoverIds, isEmpty);
  });
}
