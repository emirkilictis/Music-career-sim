import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/event_lines.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'art.dart';
import 'common.dart';

/// Full-screen alert when the platform removes the player's bought
/// streams (docs K95, F65): the song, what was removed and what it costs.
Future<void> showRemovalAlert(BuildContext context, EventLine line) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => _RemovalAlert(line: line),
  );
}

class _RemovalAlert extends StatelessWidget {
  const _RemovalAlert({required this.line});
  final EventLine line;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final e = line.event as BotsCaught;
    const red = Color(0xFFE5383B);
    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text, style: TextStyle(color: AppColors.text))),
          ]),
        );
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 330,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: red, width: 2),
                borderRadius: BorderRadius.circular(AppShape.r(16)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const Icon(Icons.gpp_bad_rounded,
                            color: Colors.white, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(l.removalTitle.toUpperCase(),
                              style: const TextStyle(
                                  fontFamily: AppFonts.condensed,
                                  fontSize: 26,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              CoverArt(
                                  seed: songCoverSeed(e.songId, line.albumId),
                                  songId: e.songId,
                                  albumId: line.albumId,
                                  size: 64,
                                  radius: 4),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(l.removalBody(line.title),
                                    style: TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            Text(l.removalRemoved(fmt.compact(e.removed)),
                                style: const TextStyle(
                                    fontFamily: AppFonts.condensed,
                                    fontSize: 44,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: red)),
                            row(Icons.payments_outlined,
                                l.removalRefund(fmt.money(e.refundCents))),
                            row(Icons.filter_alt_rounded, l.removalFilter),
                            row(Icons.forum_rounded, l.removalFans),
                            const SizedBox(height: 18),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: red,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48)),
                              onPressed: () => Navigator.pop(context),
                              child: Text(l.continueLabel),
                            ),
                          ]),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
