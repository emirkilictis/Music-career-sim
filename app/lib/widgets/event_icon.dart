import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../ui/palette.dart';
import 'common.dart';

/// Icon bubble for a piece of news (same look on every platform).
class EventIcon extends StatelessWidget {
  const EventIcon(this.event, {super.key, this.size = 40});
  final GameEvent event;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (event) {
      NumberOne() => (Icons.emoji_events_rounded, AppColors.gold),
      StillNumberOne() => (Icons.emoji_events_outlined, AppColors.gold),
      ChartDebut() => (Icons.trending_up_rounded, AppColors.sky),
      NewPeak() => (Icons.arrow_upward_rounded, AppColors.mint),
      AlbumFirstWeek() => (Icons.album_rounded, AppColors.lilac),
      ViralTrend() => (Icons.local_fire_department_rounded, AppColors.peach),
      PlaylistAdded() => (Icons.headphones_rounded, AppColors.mint),
      EraClosed() => (Icons.insights_rounded, AppColors.pink),
      BurnoutOver() => (Icons.edit_note_rounded, AppColors.butter),
      PlatformLaunched() => (Icons.graphic_eq_rounded, AppColors.mint),
      ReleaseOut() => (Icons.rocket_launch_rounded, AppColors.pink),
      LabelOffer() => (Icons.handshake_rounded, AppColors.gold),
      CriticReview() => (Icons.rate_review_rounded, AppColors.sky),
      LabelDropped() => (Icons.heart_broken_rounded, AppColors.coral),
      OpportunityCame(:final kind) => (opportunityIcon(kind), AppColors.butter),
      OpportunityLapsed() => (
          Icons.hourglass_bottom_rounded,
          AppColors.textMuted
        ),
      ReleaseAnnounced() => (Icons.campaign_rounded, AppColors.sky),
      RivalNumberOne() => (Icons.newspaper_rounded, AppColors.textMuted),
    };
    return IconBubble(icon, color: color, size: size);
  }
}

IconData opportunityIcon(OpportunityKind k) => switch (k) {
      OpportunityKind.interview => Icons.mic_external_on_rounded,
      OpportunityKind.feature => Icons.people_alt_rounded,
      OpportunityKind.festival => Icons.festival_rounded,
      OpportunityKind.brandDeal => Icons.storefront_rounded,
      OpportunityKind.scandal => Icons.warning_amber_rounded,
      OpportunityKind.award => Icons.emoji_events_rounded,
    };
