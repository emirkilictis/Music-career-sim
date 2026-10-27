import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../screens/album_version_screen.dart';
import '../ui/palette.dart';
import 'art.dart';
import 'common.dart';

/// What the player chose when an album's anniversary came (docs K226).
enum _Choice { detailed, quick, later }

/// Asks about an album whose anniversary came, if there is one the player
/// was not asked about yet (docs K226): a big card with the cover, then a
/// detailed anniversary edition (own name and cover, new songs), the quick
/// reissue, or later (the album page keeps offering it that year).
Future<void> askAnniversary(BuildContext context, CareerState state) async {
  final p = await state.read(Cmd.anniversaryPrompt());
  if (p == null || !context.mounted) return;
  await state.act(Cmd.anniversaryAsked(p.albumId));
  if (!context.mounted) return;
  final choice = await showGeneralDialog<_Choice>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, a, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child),
    pageBuilder: (c, _, __) => _AnniversaryCard(prompt: p),
  );
  if (!context.mounted) return;
  final l = context.l10n;
  switch (choice) {
    case _Choice.detailed:
      final album = await state.read(Cmd.album(p.albumId));
      if (!context.mounted) return;
      await AlbumVersionScreen.open(context, state, album, anniversary: true);
    case _Choice.quick:
      try {
        await state.act(Cmd.reissueAnniversary(p.albumId));
        if (context.mounted) {
          showInfo(context, l.anniversaryDone(p.years, p.title),
              icon: Icons.cake_outlined);
        }
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    case _Choice.later || null:
      break;
  }
}

class _AnniversaryCard extends StatelessWidget {
  const _AnniversaryCard({required this.prompt});
  final AnniversaryPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = prompt;
    Widget option(_Choice c, IconData icon, String title, String hint,
            {bool main = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Material(
            color: main ? AppColors.gold : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppShape.r(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppShape.r(14)),
              onTap: () => Navigator.pop(context, c),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(icon, color: main ? Colors.black : AppColors.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  color: main ? Colors.black : AppColors.text)),
                          const SizedBox(height: 2),
                          Text(hint,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: main
                                      ? Colors.black87
                                      : AppColors.textMuted)),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        );
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppShape.r(22)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.cake_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: 6),
                      Text(l.anniversaryPromptTag,
                          style: TextStyle(
                              color: AppColors.gold,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(alignment: Alignment.bottomRight, children: [
                        CoverArt(
                            seed: albumCoverSeed(p.albumId),
                            albumId: p.albumId,
                            size: 180),
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(AppShape.r(20)),
                          ),
                          child: Text('${p.years}',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text(l.anniversaryPromptTitle(p.title, p.years),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(l.anniversaryPromptBody(fmt.week(p.releaseWeek)),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                        l.anniversaryPromptStats(
                            p.trackCount, fmt.compact(p.lifetimeUnits)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    option(_Choice.detailed, Icons.auto_awesome_rounded,
                        l.anniversaryDetailed, l.anniversaryDetailedHint,
                        main: true),
                    option(
                        _Choice.quick,
                        Icons.album_rounded,
                        l.anniversaryQuick(fmt.money(p.quickCostCents)),
                        l.anniversaryQuickHint),
                    option(_Choice.later, Icons.schedule_rounded,
                        l.anniversaryLater, l.anniversaryLaterHint),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
