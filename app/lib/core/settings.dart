import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

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

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  static Future<AppSettings> load(File? file) async {
    final s = AppSettings(file);
    if (file != null && file.existsSync()) {
      try {
        final m = jsonDecode(await file.readAsString()) as Map<String, Object?>;
        s.languageCode = m['language'] as String?;
        s.premium = m['premium'] as bool? ?? false;
        s.weekTransition = m['weekTransition'] as bool? ?? true;
      } on FormatException {
        // A broken settings file falls back to defaults.
      }
    }
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
    }));
  }
}
