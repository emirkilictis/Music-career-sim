import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/manager_section.dart';
import '../widgets/festival_section.dart';
import '../widgets/tour_section.dart';
import '../widgets/milestones_section.dart';
import '../widgets/common.dart';
import '../widgets/image_pickers.dart';
import 'awards_screen.dart';
import 'discography_screen.dart';
import 'labels_screen.dart';
import 'song_detail_screen.dart';

/// Career summary: totals by region, #1s, year by year, all songs.
class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key, this.embedded = false});

  /// Inside the game's tab bar (no own app bar).
  final bool embedded;

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  List<CareerYear> _years = const [];
  List<SongView> _songs = const [];
  HonorsView? _honors;
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
    final career = context.careerRead;
    final years = await career.read(Cmd.careerByYear());
    final songs = await career.read(Cmd.songs());
    final honors = await career.read(Cmd.honors());
    if (mounted) {
      setState(() {
        _years = years;
        _honors = honors;
        final fmt = context.fmt;
        final week = career.week;
        _songs = songs.where((s) => !s.inVault).toList()
          ..sort((a, b) =>
              fmt.songMainValue(b, week).compareTo(fmt.songMainValue(a, week)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    final t = Theme.of(context).textTheme;
    final era = SalesEra.of(GameTime.yearOf(career.week));
    final hasStreams = p.lifetimeStreams.total >= 1;
    final list = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SkillsSection(),
        const SizedBox(height: 12),
        const MilestonesSection(),
        const SizedBox(height: 12),
        const TourSection(),
        const SizedBox(height: 12),
        const FestivalSection(),
        const SizedBox(height: 12),
        const ManagerSection(),
        const SizedBox(height: 12),
        Section(
          title: l.labelSection,
          icon: Icons.album_outlined,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(fmt.labelName(p.label),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
                p.label == Label.independent
                    ? fmt.labelKind(p.label)
                    : p.contractAlbumsLeft > 0
                        ? l.labelOwed(
                            fmt.labelName(p.label), p.contractAlbumsLeft)
                        : l.labelFree,
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LabelsScreen(state: career))),
                icon: const Icon(Icons.handshake_outlined),
                label: Text(l.labelsButton),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.artistPhotos,
          child: ArtistPhotosSection(artistId: p.id, name: p.name),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.careerTotals,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StatGrid(tiles: [
              if (hasStreams)
                StatTile(
                    label: l.streams,
                    value: fmt.compact(p.lifetimeStreams.total)),
              StatTile(
                  label: l.singleSales,
                  value: fmt.compact(p.lifetimeSingleSales)),
              if (hasStreams)
                StatTile(
                    label: l.singleUnits,
                    value: fmt.compact(
                        p.lifetimeSingleSales + p.lifetimeStreams.total / 150)),
              StatTile(
                  label: l.totalUnits,
                  value: fmt.compact(p.lifetimeTotalUnits.total)),
              StatTile(
                  label: l.pureSales, value: fmt.compact(p.lifetimePure.total)),
              if (era == SalesEra.physical || !hasStreams)
                StatTile(
                    label: l.radioAudience,
                    value: fmt.compact(p.lifetimeRadio)),
              StatTile(label: l.coreFans, value: fmt.compact(p.coreFans)),
            ]),
            const SizedBox(height: 16),
            Text(l.byRegion, style: t.titleSmall),
            const SizedBox(height: 6),
            Table(
              columnWidths: const {0: FlexColumnWidth(1.4)},
              children: [
                TableRow(children: [
                  const SizedBox(),
                  if (hasStreams) Text(l.streams, style: t.labelSmall),
                  Text(l.totalUnits, style: t.labelSmall),
                ]),
                for (final r in Region.values)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(fmt.region(r)),
                    ),
                    if (hasStreams) Text(fmt.compact(p.lifetimeStreams[r])),
                    Text(fmt.compact(p.lifetimeTotalUnits[r])),
                  ]),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.discography,
          icon: Icons.bar_chart_rounded,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.discographyHint,
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DiscographyScreen(state: career))),
                icon: const Icon(Icons.library_music_outlined),
                label: Text(l.discographyButton),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.awardsSection,
          icon: Icons.emoji_events_outlined,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                p.awardNominations > 0
                    ? l.awardsTally(p.awardWins, p.awardNominations)
                    : l.awardsHint,
                style: TextStyle(
                    color: p.awardNominations > 0
                        ? AppColors.text
                        : AppColors.textMuted,
                    fontWeight: p.awardNominations > 0
                        ? FontWeight.w700
                        : FontWeight.w400)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AwardsScreen(state: career))),
                icon: const Icon(Icons.emoji_events_outlined),
                label: Text(l.awardsButton),
              ),
            ),
          ]),
        ),
        if (_honors case final h?) ...[
          const SizedBox(height: 12),
          Section(
            title: l.honorsSection,
            icon: Icons.military_tech_outlined,
            child: h.isEmpty
                ? EmptyNote(l.honorsEmpty)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        for (final line in [
                          if (h.recordsHeld.isNotEmpty)
                            l.honorsRecords(h.recordsHeld
                                .map((k) => fmt.recordName(k))
                                .join(' · ')),
                          if (h.bestYearEndSong
                              case (final r, final y, final t))
                            l.honorsYearEndSong(r, y, t),
                          if (h.bestYearEndAlbum
                              case (final r, final y, final t))
                            l.honorsYearEndAlbum(r, y, t),
                          if (h.musicShowWins > 0)
                            l.honorsMusicShow(h.musicShowWins, h.tripleCrowns),
                          if (h.bestArtistRank > 0)
                            l.honorsArtistRank(
                                h.bestArtistRank, h.weeksTopArtist),
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(line,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                      ]),
          ),
        ],
        const SizedBox(height: 12),
        Section(
          title: l.numberOnes,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in Charts.mainSongCharts)
              Chip(
                  label:
                      Text('${fmt.chartShort(c)}: ${p.numberOneSingles[c]}')),
            for (final c in Charts.mainAlbumCharts)
              Chip(
                  label: Text('${fmt.chartShort(c)}: ${p.numberOneAlbums[c]}')),
          ]),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.yearByYear,
          child: _years.isEmpty
              ? EmptyNote(l.yearByYearEmpty)
              : Table(
                  columnWidths: const {0: FlexColumnWidth(0.8)},
                  children: [
                    TableRow(children: [
                      Text(l.year, style: t.labelSmall),
                      if (hasStreams) Text(l.streams, style: t.labelSmall),
                      Text(l.singleSales, style: t.labelSmall),
                      Text(l.albumUnits, style: t.labelSmall),
                      Text(l.fame, style: t.labelSmall),
                    ]),
                    for (final y in _years.reversed)
                      TableRow(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('${y.year}'),
                        ),
                        if (hasStreams) Text(fmt.compact(y.streams)),
                        Text(fmt.compact(y.singleSales)),
                        Text(fmt.compact(y.units)),
                        Text(fmt.percent(y.fame)),
                      ]),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.topSongs,
          child: _songs.isEmpty
              ? EmptyNote(l.noReleasesYet)
              : Column(children: [
                  for (final s in _songs.take(30))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.title),
                      subtitle: Text([
                        fmt.songStatus(s),
                        fmt.songSecondary(s, career.week),
                      ].where((x) => x.isNotEmpty).join(' · ')),
                      trailing: Text(fmt.songMain(s, career.week)),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SongDetailScreen(
                                  songId: s.id, state: career))),
                    ),
                ]),
        ),
      ],
    );
    if (widget.embedded) return list;
    return Scaffold(appBar: AppBar(title: Text(l.careerSummary)), body: list);
  }
}

/// The five skills with a + button each while skill points are left
/// (docs K43: one point a week, each skill up to 100).
class SkillsSection extends StatelessWidget {
  const SkillsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final career = context.career;
    final p = career.player;
    final names = {
      SkillKind.songwriting: l.statSongwriting,
      SkillKind.vocals: l.statVocals,
      SkillKind.production: l.statProduction,
      SkillKind.performance: l.statPerformance,
      SkillKind.charisma: l.statCharisma,
    };
    Future<void> run(SessionCmd<Object?> cmd) async {
      try {
        await career.act(cmd);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    final maxed =
        SkillKind.values.every((k) => p.skills[k]! >= Actions.maxSkill);

    return Section(
      title: l.skillsTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              p.skillPoints > 0
                  ? l.skillPointsLeft(p.skillPoints)
                  : maxed
                      ? l.skillsMaxed
                      : l.skillPointsHint(Actions.skillPointsPerWeek),
              style: TextStyle(
                  color:
                      p.skillPoints > 0 ? AppColors.lilac : AppColors.textMuted,
                  fontWeight:
                      p.skillPoints > 0 ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          // Many points at once, lowest skill first (docs F34).
          if (p.skillPoints > 1)
            TextButton.icon(
              onPressed:
                  career.busy ? null : () => run(Cmd.spreadSkillPoints()),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(l.skillsSpreadAll),
            ),
        ]),
        const SizedBox(height: 6),
        for (final k in SkillKind.values)
          Row(children: [
            Expanded(
              child: MeterRow(
                  label: names[k]!,
                  value: p.skills[k]! / Actions.maxSkill,
                  text: p.skills[k]!.floor().toString()),
            ),
            SizedBox(
              width: 50,
              child: p.skillPoints > 1 && p.skills[k]! < Actions.maxSkill - 1
                  ? TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact),
                      onPressed: career.busy
                          ? null
                          : () => run(Cmd.spendSkillPoints(k, 10)),
                      child: Text('+10',
                          semanticsLabel: l.skillRaiseMany(names[k]!, 10)),
                    )
                  : null,
            ),
            SizedBox(
              width: 44,
              child: p.skillPoints > 0 && p.skills[k]! < Actions.maxSkill
                  ? IconButton(
                      tooltip: l.skillRaise(names[k]!),
                      visualDensity: VisualDensity.compact,
                      onPressed: career.busy
                          ? null
                          : () => run(Cmd.spendSkillPoint(k)),
                      icon: Icon(Icons.add_circle_rounded,
                          color: AppColors.lilac),
                    )
                  : null,
            ),
          ]),
      ]),
    );
  }
}
