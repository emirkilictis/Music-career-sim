import 'package:sqlite3/common.dart';

/// Where the saves live (docs K218): folders and SQLite files on the
/// device, or a browser's storage on the web. Paths use '/'.
abstract class SaveFs {
  bool exists(String path);

  /// A small text file's contents (null: none).
  String? readText(String path);
  void writeText(String path, String text);

  /// Names of the folders directly in [path].
  List<String> folders(String path);
  void makeFolder(String path);
  void deleteFolder(String path);

  /// Opens (or creates) the database at [path], set up for weekly saves.
  CommonDatabase openDatabase(String path);

  /// Called after each save; the web writes its storage out.
  void saved() {}

  /// Makes [path] ready to open (the web reads a career in only when it
  /// is opened).
  Future<void> prepare(String path) async {}
}
