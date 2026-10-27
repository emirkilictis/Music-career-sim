import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'song_detail_screen.dart';

/// What each song has earned (docs K220): the player's own records (their
/// share, against what the campaign cost) and the songs they wrote for
/// others, the best earner first.
class SongEarningsScreen extends StatefulWidget {
  const SongEarningsScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<SongEarningsScreen> createState() => _SongEarningsScreenState();
}

class _SongEarningsScreenState extends State<SongEarningsScreen> {
  List<SongEarningView>? _songs;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.songEarnings()).then((s) {
      if (mounted) setState(() => _songs = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final songs = _songs;
    final total = songs?.fold(0.0, (t, s) => t + s.earnedCents) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(l.earningsTitle)),
      body: songs == null
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(32),
                      child:
                          Text(l.earningsEmpty, textAlign: TextAlign.center)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: songs.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fmt.money(total.round()),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              Text(l.earningsHint,
                                  style: TextStyle(color: AppColors.textMuted)),
                            ]),
                      );
                    }
                    final s = songs[i - 1];
                    final profit = s.earnedCents - s.costCents;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CoverArt(
                          seed: songCoverSeed(s.songId, s.albumId),
                          size: 46,
                          songId: s.songId,
                          albumId: s.albumId),
                      title: Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        '${s.year}',
                        if (s.forArtist != null)
                          l.earningsWrittenFor(s.forArtist!),
                        l.earningsStreams(fmt.compact(s.streams)),
                        if (s.costCents > 0)
                          l.earningsCampaign(fmt.money(s.costCents)),
                      ].join(' · ')),
                      trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(fmt.money(s.earnedCents.round()),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            if (s.costCents > 0)
                              Text(
                                  '${profit >= 0 ? '+' : '−'}${fmt.money(profit.abs().round())}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: profit >= 0
                                          ? AppColors.mint
                                          : AppColors.coral)),
                          ]),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SongDetailScreen(
                                  songId: s.songId, state: widget.state))),
                    );
                  },
                ),
    );
  }
}
