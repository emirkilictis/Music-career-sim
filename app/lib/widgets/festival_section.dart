import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../screens/festivals_screen.dart';
import '../ui/palette.dart';
import 'common.dart';

/// Festivals on the Career tab (docs K77): slots booked, and the calendar.
class FestivalSection extends StatefulWidget {
  const FestivalSection({super.key});

  @override
  State<FestivalSection> createState() => _FestivalSectionState();
}

class _FestivalSectionState extends State<FestivalSection> {
  List<FestivalView> _booked = const [];
  int _loaded = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final career = context.career;
    if (career.revision != _loaded) {
      _loaded = career.revision;
      _load();
    }
  }

  Future<void> _load() async {
    final list = await context.careerRead.read(Cmd.festivals());
    if (mounted) {
      setState(() => _booked = [
            for (final f in list)
              if (f.booked != null) f
          ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    return Section(
      title: l.festivalSection,
      icon: Icons.festival_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_booked.isEmpty)
          Text(l.festivalNone, style: TextStyle(color: AppColors.textMuted))
        else
          for (final f in _booked)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  '${f.festival.name} · ${fmt.week(f.week)} · '
                  '${fmt.festivalSlot(f.booked!)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FestivalsScreen(state: career)));
              _load();
            },
            icon: const Icon(Icons.event_available_rounded),
            label: Text(l.festivalSeason),
          ),
        ),
      ]),
    );
  }
}
