import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The app's last errors (docs K308): kept for a bug report (docs K307),
/// so a player who sees something break can send what broke.
abstract final class ErrorLog {
  static const size = 10;

  /// Newest last: when, what and where (the first lines of its stack).
  static final entries = <String>[];

  /// Opens the bug report from an error panel; set while a career is open.
  static void Function(BuildContext context)? reporter;

  static void add(Object error, StackTrace? stack) {
    final where = (stack?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(12)
        .join('\n');
    entries.add('${DateTime.now().toIso8601String()} $error\n$where');
    if (entries.length > size) entries.removeAt(0);
  }

  static String get text => entries.isEmpty ? '(none)' : entries.join('\n\n');

  /// Catches what goes wrong anywhere in the app; a widget that fails to
  /// build shows [ErrorPanel] instead of Flutter's gray box.
  static void install() {
    final present = FlutterError.onError;
    FlutterError.onError = (details) {
      add(details.exception, details.stack);
      present?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      add(error, stack);
      debugPrint('$error\n$stack');
      return true;
    };
    ErrorWidget.builder = (details) => ErrorPanel(details: details);
  }
}

/// Where a part of a screen failed to draw (docs K308): what happened in
/// a few words, the way to report it and the details to copy. It cannot
/// count on the app's translations or theme being above it.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final tr = PlatformDispatcher.instance.locale.languageCode == 'tr';
    final report = ErrorLog.reporter;
    final hasNav = Navigator.maybeOf(context) != null;
    // Drawn wherever the failed part was, even with no height limit.
    return LayoutBuilder(builder: (context, box) {
      final body = _body(context, tr, report, hasNav);
      return Container(
        color: const Color(0xFF2A1518),
        padding: const EdgeInsets.all(12),
        child: box.hasBoundedHeight ? SingleChildScrollView(child: body) : body,
      );
    });
  }

  Widget _body(BuildContext context, bool tr,
          void Function(BuildContext)? report, bool hasNav) =>
      Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                tr
                    ? 'Burada bir şey ters gitti.'
                    : 'Something went wrong here.',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: Color(0xFFFFD7DC),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none)),
            const SizedBox(height: 4),
            Text(
                tr
                    ? 'Oyunun geri kalanı çalışıyor. Bildirirsen düzeltilebilir.'
                    : 'The rest of the game still works. Report it and it can be fixed.',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: Color(0xFFE6B8BE),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none)),
            if (report != null && hasNav) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => report(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFD7DC),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(tr ? 'Hata bildir' : 'Report a bug',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Color(0xFF2A1518),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none)),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(details.exceptionAsString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: Color(0xFF9E7F84),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none)),
          ]);
}
