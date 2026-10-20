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
      CatchingOn() => (Icons.trending_up_rounded, AppColors.mint),
      SurpriseDrop() => (Icons.bolt_rounded, AppColors.gold),
      WrappedOut() => (Icons.graphic_eq_rounded, AppColors.gold),
      YearEndCharts() => (Icons.workspace_premium_rounded, AppColors.gold),
      RecordBroken() => (Icons.military_tech_rounded, AppColors.gold),
      TopArtist() => (Icons.public_rounded, AppColors.gold),
      DiscoverPick() => (Icons.auto_awesome_rounded, AppColors.mint),
      AdvanceRecouped() => (Icons.task_alt_rounded, AppColors.mint),
      VideoMilestone() => (Icons.smart_display_rounded, AppColors.coral),
      StreamMilestone() => (Icons.graphic_eq_rounded, AppColors.mint),
      MusicShowResult(:final won) => won
          ? (Icons.emoji_events_rounded, AppColors.gold)
          : (Icons.tv_rounded, AppColors.lilac),
      RivalAlbumClash(:final clash) => clash.moved
          ? (Icons.event_repeat_rounded, AppColors.mint)
          : (Icons.sports_mma_rounded, AppColors.coral),
      EraClosed() => (Icons.insights_rounded, AppColors.pink),
      BurnoutOver() => (Icons.edit_note_rounded, AppColors.butter),
      PlatformLaunched() => (Icons.graphic_eq_rounded, AppColors.mint),
      HolidaySeason() => (Icons.card_giftcard_rounded, AppColors.mint),
      ReleaseOut() => (Icons.rocket_launch_rounded, AppColors.pink),
      LabelOffer() => (Icons.handshake_rounded, AppColors.gold),
      CriticReview() => (Icons.rate_review_rounded, AppColors.sky),
      LabelDropped() => (Icons.heart_broken_rounded, AppColors.coral),
      OpportunityCame(:final kind) => (opportunityIcon(kind), AppColors.butter),
      MilestoneReached() => (Icons.flag_rounded, AppColors.gold),
      TourFinished() => (Icons.stadium_rounded, AppColors.peach),
      FestivalPlayed() => (Icons.festival_rounded, AppColors.pink),
      ChartBattle(:final won) => (
          Icons.sports_mma_rounded,
          won ? AppColors.gold : AppColors.coral
        ),
      PlatformOpened(:final platform) => (
          platformIcon(platform),
          platformColor(platform)
        ),
      OpportunityLapsed() => (
          Icons.hourglass_bottom_rounded,
          AppColors.textMuted
        ),
      ReleaseAnnounced() => (Icons.campaign_rounded, AppColors.sky),
      RivalNumberOne() => (Icons.newspaper_rounded, AppColors.textMuted),
      AwardNominated() => (Icons.workspace_premium_rounded, AppColors.gold),
      AwardResults(:final won) => (
          won.isEmpty
              ? Icons.workspace_premium_outlined
              : Icons.emoji_events_rounded,
          won.isEmpty ? AppColors.textMuted : AppColors.gold
        ),
      AwardWinners() => (Icons.newspaper_rounded, AppColors.textMuted),
      BotsCaught() => (Icons.gpp_bad_rounded, AppColors.coral),
      RivalBotsCaught() => (Icons.newspaper_rounded, AppColors.textMuted),
      PitchDeclined() => (Icons.playlist_remove_rounded, AppColors.textMuted),
      CreatorsFlopped() => (Icons.videocam_off_outlined, AppColors.textMuted),
      HolidayReturn() => (Icons.ac_unit_rounded, AppColors.sky),
      SongLeaked() => (Icons.water_drop_rounded, AppColors.coral),
      SalesMilestone() => (Icons.album_rounded, AppColors.gold),
      AllTimeBestSeller() => (Icons.emoji_events_rounded, AppColors.gold),
      SongOfSummer() => (Icons.wb_sunny_rounded, AppColors.gold),
      BrandDealBroken() => (Icons.link_off_rounded, AppColors.coral),
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
      OpportunityKind.memberSolo => Icons.person_rounded,
      OpportunityKind.memberRift => Icons.group_off_rounded,
    };

/// Each platform's brand colour and icon (docs K67).
Color platformColor(MusicPlatform p) => switch (p) {
      MusicPlatform.fruitTunes => const Color(0xFF3E8EF7),
      MusicPlatform.viewTube => const Color(0xFFFF2D3B),
      MusicPlatform.noiseCloud => const Color(0xFFFF6A1A),
      MusicPlatform.streamify => const Color(0xFF2BD97C),
      MusicPlatform.fruitMusic => const Color(0xFFFA2D6A),
      MusicPlatform.tikTak => const Color(0xFF25F4EE),
    };

IconData platformIcon(MusicPlatform p) => switch (p) {
      MusicPlatform.fruitTunes => Icons.shopping_bag_rounded,
      MusicPlatform.viewTube => Icons.smart_display_rounded,
      MusicPlatform.noiseCloud => Icons.cloud_rounded,
      MusicPlatform.streamify => Icons.graphic_eq_rounded,
      MusicPlatform.fruitMusic => Icons.music_note_rounded,
      MusicPlatform.tikTak => Icons.music_video_rounded,
    };
