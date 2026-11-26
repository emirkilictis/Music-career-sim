import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game/game.dart';

import '../core/backup.dart';
import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/error_log.dart';
import '../core/game_controller.dart';
import '../core/platform_files.dart';
import '../core/scope.dart';
import 'common.dart';

/// The release this build is (the web build's commit; empty locally).
const buildId = String.fromEnvironment('BUILD_ID');

/// A bug report (docs K307): the player says what happened; the game
/// puts it with the career's save, where they are in it, the release and
/// the last errors into one file to send. The file opens as a career
/// (Restore a backup), so what went wrong can be played again.
Future<void> reportBug(BuildContext context, CareerState career) async {
  final l = context.l10n;
  final controller = context.controller;
  final said = await showDialog<String>(
      context: context, builder: (_) => const _AskDialog());
  if (said == null || !context.mounted) return;
  final Uint8List file;
  final String text;
  try {
    (file, text) = await _withSpinner(context, l.bugReportMaking,
        () => _make(controller, career, said));
  } catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  if (!context.mounted) return;
  final name = 'bug-report ${CareerBackup.fileName(career.player.name)}';
  // Saving waits for a tap: a browser only downloads on one.
  await showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline_rounded),
      title: Text(l.bugReportReady),
      content: Text(l.bugReportSend),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.maybeOf(context)
                ?.showSnackBar(SnackBar(content: Text(l.bugReportCopied)));
          },
          child: Text(l.bugReportCopy),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download_rounded),
          label: Text(l.backupSave),
          onPressed: () {
            saveFileAs(file, name);
            Navigator.pop(d);
          },
        ),
      ],
    ),
  );
}

Future<(Uint8List, String)> _make(
    GameController controller, CareerState career, String said) async {
  final slot = career.slotId;
  if (slot == null) throw GameException('noCareer', 'No career open');
  final db = await controller.exec(Cmd.backupSlot(slot));
  final text = reportText(
    said: said,
    artist: career.player.name,
    week: career.week,
    locale: PlatformDispatcher.instance.locale.toLanguageTag(),
  );
  final file = await CareerBackup(db, const {}, report: text).encode();
  return (file, text);
}

/// What happened, in the player's words (null: cancelled).
class _AskDialog extends StatefulWidget {
  const _AskDialog();

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  final _words = TextEditingController();

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.bug_report_outlined),
      title: Text(l.bugReportTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.bugReportHow),
          const SizedBox(height: 12),
          TextField(
            controller: _words,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
                hintText: l.bugReportHint, border: const OutlineInputBorder()),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _words.text.trim()),
            child: Text(l.bugReportMake)),
      ],
    );
  }
}

/// The report's words: what the player said, then what the game knows.
String reportText(
        {required String said,
        required String artist,
        required int week,
        required String locale}) =>
    [
      'Bug report (Music Career Sim)',
      '',
      said.isEmpty ? '(nothing written)' : said,
      '',
      '---',
      'Artist: $artist',
      'Game week: $week (${GameTime.label(week)})',
      'Release: ${buildId.isEmpty ? 'local' : buildId}',
      'Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}'
          '${const bool.fromEnvironment('dart.tool.dart2wasm') ? ' (WebAssembly)' : ''}',
      'Language: $locale',
      'Made: ${DateTime.now().toIso8601String()}',
      '',
      'Last errors:',
      ErrorLog.text,
    ].join('\n');

Future<T> _withSpinner<T>(
    BuildContext context, String text, Future<T> Function() work) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox.square(
              dimension: 28, child: CircularProgressIndicator()),
          const SizedBox(width: 20),
          Expanded(child: Text(text)),
        ]),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    nav.pop();
  }
}
