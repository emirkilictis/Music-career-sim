import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'award_night_screen.dart';
import 'song_detail_screen.dart';

/// The Golden Record Awards, year by year (docs K91): every category with
/// its nominees and winner, the player's own rows marked.
class AwardsScreen extends StatefulWidget {
  const AwardsScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen> {
  List<int>? _years;
  AwardShowView? _show;

  @override
  void initState() {
    super.initState();
    _load(null);
  }

  Future<void> _load(int? year) async {
    final (years, show) = await widget.state.read(Cmd.awards(year));
    if (!mounted) return;
    setState(() {
      _years = years;
      _show = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final years = _years;
    final show = _show;
    return Scaffold(
      appBar: AppBar(title: Text(l.awardsTitle)),
      body: years == null
          ? const Center(child: CircularProgressIndicator())
          : years.isEmpty || show == null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l.awardsEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                ))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          for (final y in years)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('$y'),
                                selected: show.year == y,
                                onSelected: (_) => _load(y),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Header(show: show),
                    // Relive the night (docs K243).
                    if (show.held && show.playerNominations > 0) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: PaperColors.ink),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                fullscreenDialog: true,
                                builder: (_) => AwardNightScreen(
                                    show: show, state: widget.state))),
                        icon: const Icon(Icons.emoji_events_rounded),
                        label: Text(l.awardNightWatch),
                      ),
                    ],
                    for (final race in show.races) ...[
                      const SizedBox(height: 14),
                      _Race(race: race, held: show.held, state: widget.state),
                    ],
                  ],
                ),
    );
  }
}

/// The year in big type, what it honors, when, and the player's tally.
class _Header extends StatelessWidget {
  const _Header({required this.show});
  final AwardShowView show;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: PaperColors.bg,
        borderRadius: BorderRadius.circular(AppShape.r(14)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.awardsTitle.toUpperCase(),
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    letterSpacing: 1.2,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: PaperColors.muted)),
            Text('${show.year}',
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    fontSize: 56,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: PaperColors.ink)),
            const SizedBox(height: 6),
            Text(
                l.awardsEligible(fmt.monthYear(show.eligibleFrom),
                    fmt.monthYear(show.eligibleTo)),
                style: const TextStyle(color: PaperColors.muted, fontSize: 13)),
            Text(
                show.held
                    ? l.awardsHeld(fmt.week(show.ceremonyWeek))
                    : l.awardsShowOn(fmt.week(show.ceremonyWeek)),
                style: const TextStyle(color: PaperColors.muted, fontSize: 13)),
          ]),
        ),
        if (show.playerNominations > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: show.playerWins > 0 ? AppColors.gold : PaperColors.ink,
            child: Text(
                l
                    .awardsYou(show.playerWins, show.playerNominations)
                    .toUpperCase(),
                style: TextStyle(
                    fontFamily: AppFonts.condensed,
                    letterSpacing: 0.6,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: show.playerWins > 0
                        ? PaperColors.ink
                        : PaperColors.bg)),
          ),
      ]),
    );
  }
}

/// One category: its name and the nominees, the winner on top once the
/// show is held.
class _Race extends StatelessWidget {
  const _Race({required this.race, required this.held, required this.state});
  final AwardRaceView race;
  final bool held;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final nominees = [...race.nominees]
      ..sort((a, b) => (b.isWinner ? 1 : 0) - (a.isWinner ? 1 : 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(fmt.awardCategory(race.category, race.genre).toUpperCase(),
          style: TextStyle(
              fontFamily: AppFonts.condensed,
              letterSpacing: 0.8,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.text)),
      const SizedBox(height: 4),
      Container(height: 2, color: AppColors.text),
      for (final n in nominees) _NomineeRow(n: n, held: held, state: state),
    ]);
  }
}

class _NomineeRow extends StatelessWidget {
  const _NomineeRow({required this.n, required this.held, required this.state});
  final AwardNomineeView n;
  final bool held;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lost = held && !n.isWinner;
    final art = switch (n.entry) {
      AwardEntry.song => CoverArt(
          seed: songCoverSeed(n.id, n.coverAlbumId),
          songId: n.id,
          albumId: n.coverAlbumId,
          size: 44,
          radius: 2),
      AwardEntry.album => CoverArt(
          seed: albumCoverSeed(n.id), albumId: n.id, size: 44, radius: 2),
      AwardEntry.artist =>
        ArtistAvatar(name: n.title, seed: n.id, size: 44, artistId: n.id),
    };
    void open() => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => n.entry == AwardEntry.song
                ? SongDetailScreen(songId: n.id, state: state)
                : AlbumDetailScreen(albumId: n.id, state: state)));
    return InkWell(
      onTap: n.entry == AwardEntry.artist ? null : open,
      child: Container(
        decoration: BoxDecoration(
          color: n.isPlayer ? AppColors.accentSoft : null,
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Opacity(
          opacity: lost ? 0.6 : 1,
          child: Row(children: [
            art,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    if (n.entry != AwardEntry.artist)
                      Text(n.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                  ]),
            ),
            if (n.isWinner)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: AppColors.gold,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.emoji_events_rounded,
                      size: 15, color: PaperColors.ink),
                  const SizedBox(width: 4),
                  Text(l.awardWinner.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: AppFonts.condensed,
                          letterSpacing: 0.6,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PaperColors.ink)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
