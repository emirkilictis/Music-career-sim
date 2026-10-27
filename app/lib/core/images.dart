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

/// A picked image's bytes: a file on the device, a blob URL on the web.
Future<Uint8List> readPicked(String path) async => kIsWeb
    ? await picker.XFile(path).readAsBytes()
    : File(path).readAsBytesSync();

/// The player's own images for the open career: song and album covers and
/// artist photos. Files live next to the career's save
/// (`<careers>/<slotId>/images/`) and never leave the device. Anything
/// without an image keeps its generated art.
class ImageStore extends ChangeNotifier {
  ImageStore(this.careersRoot, {ImagePickSource? source})
      : source = source ?? DeviceImagePickSource();

  final String careersRoot;
  final ImagePickSource source;

  /// The open career and its images (key → file path, or on the web a
  /// data URL; docs K218).
  @protected
  String? openSlot;
  @protected
  final Map<String, String> files = {};

  Directory? get _dir =>
      openSlot == null ? null : Directory('$careersRoot/$openSlot/images');

  /// Loads the images of [slotId] (call when a career opens).
  void open(String slotId) {
    if (openSlot == slotId) return;
    openSlot = slotId;
    files.clear();
    final dir = _dir!;
    if (dir.existsSync()) {
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final key = name.substring(0, name.lastIndexOf('_'));
        files[key] = f.path;
      }
    }
    notifyListeners();
  }

  void close() {
    openSlot = null;
    files.clear();
  }

  /// [key]'s image in a career that is not open (the career list), if any.
  String? pathIn(String slotId, String key) {
    final dir = Directory('$careersRoot/$slotId/images');
    if (!dir.existsSync()) return null;
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.startsWith('${key}_')) return f.path;
    }
    return null;
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

  String? path(String key) => files[key];

  /// A song's cover: its own, else its album's.
  String? songCover(int songId, int albumId) =>
      files[songKey(songId)] ??
      (albumId >= 0 ? files[albumKey(albumId)] : null);

  String? albumCover(int albumId) => files[albumKey(albumId)];

  /// An artist photo for a place, falling back to the general one.
  String? artistPhoto(int artistId, [ArtistPhoto kind = ArtistPhoto.general]) =>
      files[artistKey(artistId, kind)] ??
      files[artistKey(artistId, ArtistPhoto.general)];

  /// Stores [bytes] (a cropped photo) as the image for [key] (docs K221).
  void saveBytes(String key, Uint8List bytes) {
    final dir = _dir;
    if (dir == null) return;
    dir.createSync(recursive: true);
    _deleteFile(key);
    final target = '${dir.path}/${key}_${DateTime.now().microsecondsSinceEpoch}'
        '.${mimeOf(bytes).split('/').last}';
    File(target).writeAsBytesSync(bytes);
    files[key] = target;
    notifyListeners();
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
    files[key] = target;
    notifyListeners();
  }

  /// Moves the image of [from] to [to] (a scheduled album came out). The
  /// file is renamed too, so the link survives reopening the career.
  void adopt(String from, String to) {
    final path = files.remove(from);
    if (path == null) return;
    _deleteFile(to);
    final dot = path.lastIndexOf('.');
    final ext = dot > path.lastIndexOf('/') ? path.substring(dot) : '.jpg';
    final target = '${File(path).parent.path}/'
        '${to}_${DateTime.now().microsecondsSinceEpoch}$ext';
    try {
      File(path).renameSync(target);
      files[to] = target;
    } on FileSystemException {
      files[to] = path;
    }
    notifyListeners();
  }

  /// Schedule ids whose album cover is still stored under the schedule
  /// (older versions forgot to rename it when the album came out).
  List<int> get scheduledCoverIds => [
        for (final k in files.keys)
          if (k.startsWith('scheduled_') && !k.contains('_ed'))
            int.tryParse(k.substring('scheduled_'.length)) ?? -1,
      ]..removeWhere((id) => id < 0);

  void remove(String key) {
    _deleteFile(key);
    notifyListeners();
  }

  /// [slotId]'s images (key → bytes), for a backup (docs K219).
  Map<String, Uint8List> imagesOf(String slotId) {
    final dir = Directory('$careersRoot/$slotId/images');
    if (!dir.existsSync()) return {};
    return {
      for (final f in dir.listSync().whereType<File>())
        if (f.uri.pathSegments.last.contains('_'))
          f.uri.pathSegments.last.substring(
              0, f.uri.pathSegments.last.lastIndexOf('_')): f.readAsBytesSync(),
    };
  }

  /// Puts a backup's images into [slotId] (docs K219).
  void addImages(String slotId, Map<String, Uint8List> images) {
    if (images.isEmpty) return;
    final dir = Directory('$careersRoot/$slotId/images')
      ..createSync(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    images.forEach((key, bytes) {
      final ext = '.${mimeOf(bytes).split('/').last}';
      File('${dir.path}/${key}_$stamp$ext').writeAsBytesSync(bytes);
    });
  }

  /// An image's type from its first bytes.
  static String mimeOf(List<int> b) =>
      b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E
          ? 'image/png'
          : b.length > 2 && b[0] == 0x47 && b[1] == 0x49
              ? 'image/gif'
              : b.length > 12 && b[8] == 0x57 && b[9] == 0x45
                  ? 'image/webp'
                  : 'image/jpeg';

  void _deleteFile(String key) {
    final old = files.remove(key);
    if (old != null) {
      try {
        File(old).deleteSync();
      } on FileSystemException {
        // Already gone.
      }
    }
  }
}
