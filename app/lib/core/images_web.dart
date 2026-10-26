import 'dart:convert';

import 'package:image_picker/image_picker.dart' as picker;
import 'package:persistence/web.dart';

import 'images.dart';

/// The player's images in the browser (docs K218): kept as data URLs in
/// the same storage as the saves, under the career's folder, so they go
/// when the career is deleted.
class WebImageStore extends ImageStore {
  WebImageStore(this.fs, String careersRoot, {super.source})
      : super(careersRoot);

  final WebSaveFs fs;

  String _prefix(String slot) => '$careersRoot/$slot/images/';

  @override
  void open(String slotId) {
    if (openSlot == slotId) return;
    openSlot = slotId;
    files.clear();
    final prefix = _prefix(slotId);
    fs.textsUnder(prefix).forEach((path, url) {
      files[path.substring(prefix.length)] = url;
    });
    notifyListeners();
  }

  @override
  String? pathIn(String slotId, String key) =>
      fs.readText('${_prefix(slotId)}$key');

  @override
  void save(String key, String sourcePath) {
    final slot = openSlot;
    if (slot == null) return;
    // The picked image's blob URL shows right away; its bytes are kept
    // once read.
    files[key] = sourcePath;
    notifyListeners();
    picker.XFile(sourcePath).readAsBytes().then((bytes) {
      final url = 'data:${_mime(bytes)};base64,${base64Encode(bytes)}';
      fs.writeText('${_prefix(slot)}$key', url);
      if (openSlot == slot && files[key] == sourcePath) {
        files[key] = url;
        notifyListeners();
      }
    });
  }

  @override
  void adopt(String from, String to) {
    final slot = openSlot;
    final url = files.remove(from);
    if (slot == null || url == null) return;
    files[to] = url;
    fs.deleteText('${_prefix(slot)}$from');
    if (url.startsWith('data:')) fs.writeText('${_prefix(slot)}$to', url);
    notifyListeners();
  }

  @override
  void remove(String key) {
    final slot = openSlot;
    files.remove(key);
    if (slot != null) fs.deleteText('${_prefix(slot)}$key');
    notifyListeners();
  }

  static String _mime(List<int> b) =>
      b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E
          ? 'image/png'
          : b.length > 2 && b[0] == 0x47 && b[1] == 0x49
              ? 'image/gif'
              : b.length > 12 && b[8] == 0x57 && b[9] == 0x45
                  ? 'image/webp'
                  : 'image/jpeg';
}
