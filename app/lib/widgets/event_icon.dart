import 'package:flutter/material.dart';
import 'package:game/game.dart';

/// Icon for a piece of news (same look on every platform).
class EventIcon extends StatelessWidget {
  const EventIcon(this.event, {super.key, this.size = 24});
  final GameEvent event;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (icon, color) = switch (event) {
      NumberOne() => (Icons.emoji_events, const Color(0xFFE6B422)),
      ChartDebut() => (Icons.trending_up, Colors.lightBlueAccent),
      NewPeak() => (Icons.arrow_upward, Colors.greenAccent),
      AlbumFirstWeek() => (Icons.album, s.primary),
      ViralTrend() => (Icons.local_fire_department, Colors.deepOrangeAccent),
      PlaylistAdded() => (Icons.headphones, Colors.tealAccent),
      EraClosed() => (Icons.insights, s.tertiary),
      BurnoutOver() => (Icons.edit_note, s.secondary),
      RivalNumberOne() => (Icons.newspaper, s.outline),
    };
    return Icon(icon, color: color, size: size);
  }
}
