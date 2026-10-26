import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../ui/palette.dart';
import '../widgets/art.dart';

/// App settings kept outside the careers: language and (until in-app
/// purchases exist) a Premium test switch.
class AppSettings extends ChangeNotifier {
  AppSettings(this._file);

  final File? _file;

  /// null = follow the device language.
  String? languageCode;

  /// Test switch standing in for a Premium subscription (docs §20). Replaced
  /// by the store's entitlement when in-app purchases are added.
  bool premium = false;

  /// Short animation between weeks (feedback B1); can be turned off.
  bool weekTransition = true;

  /// App colors: ink (default) or paper (docs K41, K88).
  bool lightTheme = false;

  /// Corner style: sharp (default since docs K88) or soft (docs F1).
  bool sharpCorners = true;

  /// Drawn faces for people without a photo (docs K212) or initials.
  bool avatarFaces = true;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  static Future<AppSettings> load(File? file) async {
    final s = AppSettings(file);
    if (file != null && file.existsSync()) {
      try {
        final m = jsonDecode(await file.readAsString()) as Map<String, Object?>;
        s.languageCode = m['language'] as String?;
        s.premium = m['premium'] as bool? ?? false;
        s.weekTransition = m['weekTransition'] as bool? ?? true;
        s.lightTheme = m['theme'] == 'light';
        // Stored under a new key in K88: the old one held the old
        // default, so everyone starts sharp once.
        s.sharpCorners = m['cornerStyle'] != 'soft';
        s.avatarFaces = m['avatars'] != 'initials';
      } on FormatException {
        // A broken settings file falls back to defaults.
      }
    }
    AppColors.palette = s.lightTheme ? Palette.light : Palette.ink;
    AppShape.sharp = s.sharpCorners;
    ArtistAvatar.faces = s.avatarFaces;
    return s;
  }

  void setLanguage(String? code) {
    languageCode = code;
    _save();
  }

  void setPremium(bool on) {
    premium = on;
    _save();
  }

  void setLightTheme(bool on) {
    lightTheme = on;
    AppColors.palette = on ? Palette.light : Palette.ink;
    _save();
  }

  void setSharpCorners(bool on) {
    sharpCorners = on;
    AppShape.sharp = on;
    _save();
  }

  void setAvatarFaces(bool on) {
    avatarFaces = on;
    ArtistAvatar.faces = on;
    _save();
  }

  void setWeekTransition(bool on) {
    weekTransition = on;
    _save();
  }

  void _save() {
    notifyListeners();
    final f = _file;
    if (f == null) return;
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode({
      'language': languageCode,
      'premium': premium,
      'weekTransition': weekTransition,
      'theme': lightTheme ? 'light' : 'ink',
      'cornerStyle': sharpCorners ? 'sharp' : 'soft',
      'avatars': avatarFaces ? 'faces' : 'initials',
    }));
  }
}
