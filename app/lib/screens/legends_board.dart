import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'game_shell.dart' show pushInCareer;
import 'streamify/artist_page.dart';

/// The legends in the chart tabs (docs K288): the greatest artists of all
/// time by legacy score, and the Hall of Fame class by class.
class LegendsBoard extends StatefulWidget {
  const LegendsBoard({super.key});

  @override
  State<LegendsBoard> createState() => _LegendsBoardState();
}

class _LegendsBoardState extends State<LegendsBoard> {
  bool _hall = false;
  List<LegacyRow>? _rows;
  List<HallOfFameRow>? _hof;
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
    final (rows, hof) = await context.careerRead.read(Cmd.legends());
    if (mounted) {
      setState(() {
        _rows = rows;
        _hof = hof;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final rows = _rows, hof = _hof;
    Widget body;
    if (rows == null || hof == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_hall) {
      body = hof.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.legendsEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PaperColors.muted)))
          : ListView(children: [
              for (var i = 0; i < hof.length; i++) ...[
                if (i == 0 || hof[i - 1].year != hof[i].year)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(l.hallOfFameClass(hof[i].year).toUpperCase(),
                        style: const TextStyle(
                            fontFamily: AppFonts.condensed,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 1,
                            color: PaperColors.ink)),
                  ),
                _Row(
                  rank: null,
                  artistId: hof[i].artistId,
                  name: hof[i].name,
                  subtitle: null,
                  value: l.legendsPoints(fmt.number(hof[i].score.round())),
                  isPlayer: hof[i].isPlayer,
                ),
              ],
            ]);
    } else {
      body = ListView(children: [
        for (final r in rows)
          _Row(
            rank: r.rank,
            artistId: r.artistId,
            name: r.name,
            subtitle: [
              fmt.legacyTitle(r.title),
              if (r.hallOfFameYear > 0) l.legendsInducted(r.hallOfFameYear),
              if (r.retired) l.legendsRetired,
            ].join(' · '),
            value: l.legendsPoints(fmt.number(r.score.round())),
            isPlayer: r.isPlayer,
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l.legendsNote,
              style: const TextStyle(color: PaperColors.muted, fontSize: 12)),
        ),
      ]);
    }
    return Column(children: [
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          children: [
            ChoiceChip(
              label: Text(l.legendsAllTime),
              selected: !_hall,
              onSelected: (_) => setState(() => _hall = false),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(l.legendsHallOfFame),
              selected: _hall,
              onSelected: (_) => setState(() => _hall = true),
            ),
          ],
        ),
      ),
      Expanded(child: body),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.artistId,
    required this.name,
    required this.subtitle,
    required this.value,
    required this.isPlayer,
  });
  final int? rank;
  final int artistId;
  final String name;
  final String? subtitle;
  final String value;
  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    final r = rank;
    return InkWell(
      onTap: () => pushInCareer(context, ArtistPage(artistId: artistId)),
      child: Container(
        color: isPlayer ? const Color(0xFFE6EAFF) : PaperColors.card,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          if (r != null)
            SizedBox(
              width: 44,
              child: Text('$r',
                  style: TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontWeight: FontWeight.w800,
                      fontSize: r == 1 ? 30 : 22,
                      height: 1,
                      color: PaperColors.ink)),
            ),
          ArtistAvatar(name: name, seed: artistId, artistId: artistId, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: PaperColors.ink)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: PaperColors.muted)),
                ]),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: PaperColors.ink)),
        ]),
      ),
    );
  }
}
