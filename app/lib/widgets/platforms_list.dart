import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../screens/game_shell.dart';
import '../screens/platform_screen.dart';
import '../screens/streamify/streamify_tab.dart';
import '../ui/palette.dart';
import 'common.dart';
import 'event_icon.dart';

/// Home → Platforms (docs K67): each open platform with your numbers
/// there last week.
class PlatformsList extends StatefulWidget {
  const PlatformsList({super.key});

  @override
  State<PlatformsList> createState() => _PlatformsListState();
}

class _PlatformsListState extends State<PlatformsList> {
  List<PlatformView> _views = const [];
  int _loadedRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final career = context.career;
    if (career.revision != _loadedRevision) {
      _loadedRevision = career.revision;
      _load();
    }
  }

  Future<void> _load() async {
    final v = await context.careerRead.read(Cmd.platforms());
    if (mounted) setState(() => _views = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    if (_views.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text(l.platformsLater,
            style: TextStyle(color: AppColors.textFaint)),
      );
    }
    return Column(children: [
      for (final v in _views)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: platformColor(v.platform),
                borderRadius: BorderRadius.circular(AppShape.r(18))),
            child:
                Icon(platformIcon(v.platform), color: Colors.black, size: 20),
          ),
          title: Text(v.platform.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              v.playerWeek < 1
                  ? fmt.platformTagline(v.platform)
                  : fmt.platformWeek(v.platform, v.playerWeek),
              style: TextStyle(color: AppColors.textFaint)),
          trailing:
              Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          onTap: () => v.platform == MusicPlatform.streamify
              ? pushInCareer(context, const StreamifyScreen())
              : Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PlatformScreen(platform: v.platform, state: career))),
        ),
    ]);
  }
}
