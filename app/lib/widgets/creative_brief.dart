import 'package:flutter/material.dart';
import 'package:game/game.dart';
import '../core/scope.dart';
import '../l10n/gen/app_localizations.dart';

String soundLabel(AppLocalizations l, EraSound s) => switch (s) {
      EraSound.familiar => l.soundFamiliar,
      EraSound.reinvention => l.soundReinvention,
      EraSound.experimental => l.soundExperimental,
    };
String themeLabel(AppLocalizations l, SongTheme s) => switch (s) {
      SongTheme.love => l.themeLove,
      SongTheme.heartbreak => l.themeHeartbreak,
      SongTheme.nightlife => l.themeNightlife,
      SongTheme.anger => l.themeAnger,
      SongTheme.confidence => l.themeConfidence,
    };
String directionLabel(AppLocalizations l, SongDirection s) => switch (s) {
      SongDirection.balanced => l.directionBalanced,
      SongDirection.dance => l.directionDance,
      SongDirection.ballad => l.directionBallad,
      SongDirection.vocal => l.directionVocal,
      SongDirection.experimental => l.directionExperimental,
    };

class CreativeBriefCard extends StatelessWidget {
  const CreativeBriefCard({super.key, required this.brief, this.direction});
  final EraBrief brief;
  final SongDirection? direction;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (brief.name.isNotEmpty)
            Text(brief.name, style: Theme.of(context).textTheme.titleMedium),
          if (brief.name.isNotEmpty)
            Text(
                '${soundLabel(l, brief.sound)} · ${themeLabel(l, brief.theme)}'),
          if (direction != null) Text(directionLabel(l, direction!)),
        ]));
  }
}
