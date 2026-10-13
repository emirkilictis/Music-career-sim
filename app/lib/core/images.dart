import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' as picker;

/// Where a player image is shown (docs K8, feedback C5).
enum ArtistPhoto {
  /// Used everywhere unless a platform has its own.
  general,

  /// The streaming platform profile.
  streamify,
}

/// Picks one image from the device; returns its path or null if cancelled.
/// Replaced by a fake in tests.
abstract class ImagePickSource {
  Future<String?> pick();
}

/// The phone's own photo picker (no camera), scaled down on the way in.
class DeviceImagePickSource implements ImagePickSource {
  @override
  Future<String?> pick() async {
    final f = await picker.ImagePicker().pickImage(
      source: picker.ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 88,
    );
    return f?.path;
  }
}

/// The player's own images for the open career: song and album covers and
/// artist photos. Files live next to the career's save
/// (`<careers>/<slotId>/images/`) and never leave the device. Anything
/// without an image keeps its generated art.
class ImageStore extends ChangeNotifier {
  ImageStore(this.careersRoot, {ImagePickSource? source})
      : source = source ?? DeviceImagePickSource();

  final String careersRoot;
  final ImagePickSource source;

  String? _slotId;
  final Map<String, String> _files = {};

  Directory? get _dir =>
      _slotId == null ? null : Directory('$careersRoot/$_slotId/images');

  /// Loads the images of [slotId] (call when a career opens).
  void open(String slotId) {
    if (_slotId == slotId) return;
    _slotId = slotId;
    _files.clear();
    final dir = _dir!;
    if (dir.existsSync()) {
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final key = name.substring(0, name.lastIndexOf('_'));
        _files[key] = f.path;
      }
    }
    notifyListeners();
  }

  void close() {
    _slotId = null;
    _files.clear();
  }

  static String songKey(int songId) => 'song_$songId';
  static String albumKey(int albumId) => 'album_$albumId';

  /// An album cover chosen before a scheduled album exists (docs K45).
  static String scheduledKey(int scheduleId) => 'scheduled_$scheduleId';

  /// The cover of extra edition [k] (1+) of an album or scheduled album
  /// whose own key is [base] (docs K46).
  static String editionKey(String base, int k) => '${base}_ed$k';

  /// Moves an album's cover and its editions' covers from [from] to [to].
  void adoptWithEditions(String from, String to) {
    adopt(from, to);
    for (var k = 1; k <= 8; k++) {
      adopt(editionKey(from, k), editionKey(to, k));
    }
  }

  static String artistKey(int artistId, ArtistPhoto kind) =>
      kind == ArtistPhoto.general
          ? 'artist_$artistId'
          : 'artist_${artistId}_${kind.name}';

  String? path(String key) => _files[key];

  /// A song's cover: its own, else its album's.
  String? songCover(int songId, int albumId) =>
      _files[songKey(songId)] ??
      (albumId >= 0 ? _files[albumKey(albumId)] : null);

  String? albumCover(int albumId) => _files[albumKey(albumId)];

  /// An artist photo for a place, falling back to the general one.
  String? artistPhoto(int artistId, [ArtistPhoto kind = ArtistPhoto.general]) =>
      _files[artistKey(artistId, kind)] ??
      _files[artistKey(artistId, ArtistPhoto.general)];

  /// Asks the device for an image and stores it under [key]; false when the
  /// player cancelled.
  Future<bool> pickFor(String key) async {
    final picked = await source.pick();
    if (picked == null) return false;
    save(key, picked);
    return true;
  }

  /// Copies [sourcePath] in as the image for [key] (replacing an old one).
  void save(String key, String sourcePath) {
    final dir = _dir;
    if (dir == null) return;
    dir.createSync(recursive: true);
    _deleteFile(key);
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    // A fresh name each time, so the image cache never shows the old one.
    final target =
        '${dir.path}/${key}_${DateTime.now().microsecondsSinceEpoch}$ext';
    File(sourcePath).copySync(target);
    _files[key] = target;
    notifyListeners();
  }

  /// Moves the image of [from] to [to] (a scheduled album came out).
  void adopt(String from, String to) {
    final path = _files.remove(from);
    if (path == null) return;
    _deleteFile(to);
    _files[to] = path;
    notifyListeners();
  }

  void remove(String key) {
    _deleteFile(key);
    notifyListeners();
  }

  void _deleteFile(String key) {
    final old = _files.remove(key);
    if (old != null) {
      try {
        File(old).deleteSync();
      } on FileSystemException {
        // Already gone.
      }
    }
  }
}
