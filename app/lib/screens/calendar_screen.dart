import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';

/// The next six months for picking a release week (docs K177).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<CalendarWeek>? _weeks;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.calendar()).then((c) {
      if (mounted) setState(() => _weeks = c);
    });
  }

  (IconData, Color) _icon(CalendarKind k) => switch (k) {
        CalendarKind.release => (Icons.rocket_launch_rounded, AppColors.pink),
        CalendarKind.announce => (Icons.campaign_rounded, AppColors.pink),
        CalendarKind.edition => (Icons.album_outlined, AppColors.lilac),
        CalendarKind.onStreaming => (Icons.play_circle_outline, AppColors.lilac),
        CalendarKind.tour => (Icons.stadium_rounded, AppColors.lilac),
        CalendarKind.festival => (Icons.festival_rounded, AppColors.lilac),
        CalendarKind.rivalAlbum => (Icons.album_rounded, AppColors.textMuted),
        CalendarKind.awardCutoff ||
        CalendarKind.nominations ||
        CalendarKind.ceremony =>
          (Icons.emoji_events_outlined, AppColors.textMuted),
        CalendarKind.holidays => (Icons.ac_unit_rounded, AppColors.textMuted),
        CalendarKind.summerStart ||
        CalendarKind.summerEnd =>
          (Icons.wb_sunny_outlined, AppColors.textMuted),
        CalendarKind.yearEnd ||
        CalendarKind.wrapped =>
          (Icons.insights_rounded, AppColors.textMuted),
      };

  String _text(CalendarEntry e) {
    final l = context.l10n;
    final fmt = context.fmt;
    return switch (e.kind) {
      CalendarKind.release => l.calRelease(fmt.albumType(e.type), e.title),
      CalendarKind.announce => l.calAnnounce(e.title),
      CalendarKind.edition => l.calEdition(e.title),
      CalendarKind.onStreaming => l.calOnStreaming(e.title),
      CalendarKind.tour => l.calTour(e.title),
      CalendarKind.festival => l.calFestival(e.title),
      CalendarKind.rivalAlbum => l.calRival(e.artistName, e.title),
      CalendarKind.awardCutoff => l.calAwardCutoff(e.year),
      CalendarKind.nominations => l.calNominations(e.year),
      CalendarKind.ceremony => l.calCeremony(e.year),
      CalendarKind.holidays => l.calHolidays,
      CalendarKind.summerStart => l.calSummerStart,
      CalendarKind.summerEnd => l.calSummerEnd,
      CalendarKind.yearEnd => l.calYearEnd(e.year),
      CalendarKind.wrapped => l.calWrapped(e.year),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final weeks = _weeks;
    final now = widget.state.week;
    return Scaffold(
      appBar: AppBar(title: Text(l.calTitle)),
      body: weeks == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(l.calHint, style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              if (weeks.isEmpty) EmptyNote(l.calEmpty),
              for (final w in weeks) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text(fmt.week(w.week),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Text(
                      switch (w.week - now) {
                        0 => l.calThisWeek,
                        1 => l.calNextWeek,
                        final n => l.calInWeeks(n),
                      },
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ]),
                for (final e in w.entries)
                  InkWell(
                    onTap: e.albumId < 0
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AlbumDetailScreen(
                                    albumId: e.albumId, state: widget.state))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Icon(_icon(e.kind).$1,
                            size: 18, color: _icon(e.kind).$2),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_text(e),
                              style: TextStyle(
                                  fontWeight: e.isPlayer
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: e.isSeason
                                      ? AppColors.textMuted
                                      : null)),
                        ),
                      ]),
                    ),
                  ),
                const Divider(height: 12),
              ],
            ]),
    );
  }
}
