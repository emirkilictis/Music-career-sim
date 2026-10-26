import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import 'tour_detail_screen.dart';

/// Every tour the player finished (docs K208): the career's totals on
/// the road, then each tour as a poster-like card, newest first.
class TourHistoryScreen extends StatefulWidget {
  const TourHistoryScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<TourHistoryScreen> createState() => _TourHistoryScreenState();
}

class _TourHistoryScreenState extends State<TourHistoryScreen> {
  List<TourHistoryView>? _tours;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.tourHistory()).then((t) {
      if (mounted) setState(() => _tours = t);
    });
  }

  Future<void> _open(TourHistoryView t) async {
    final v = await widget.state.read(Cmd.pastTour(t.startWeek));
    if (v == null || !mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TourDetailScreen(state: widget.state, past: v)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tours = _tours;
    return Scaffold(
      appBar: AppBar(title: Text(l.tourHistory)),
      body: tours == null
          ? const Center(child: CircularProgressIndicator())
          : tours.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyNote(l.tourHistoryEmpty))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    StatGrid(tiles: [
                      StatTile(
                          label: l.tourHistoryTours, value: '${tours.length}'),
                      StatTile(
                          label: l.tourStatShows,
                          value: '${tours.fold(0, (t, x) => t + x.shows)}'),
                      StatTile(
                          label: l.tourStatTickets,
                          value: fmt.compact(
                              tours.fold(0.0, (t, x) => t + x.tickets))),
                      StatTile(
                          label: l.tourStatGross,
                          value: fmt.money(tours
                              .fold(0.0, (t, x) => t + x.grossCents)
                              .round())),
                    ]),
                    const SizedBox(height: 14),
                    for (final t in tours) ...[
                      _TourCard(
                          tour: t, onTap: t.detailed ? () => _open(t) : null),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }
}

/// One finished tour, like a tour poster: its name big, the years, where
/// it went and how it sold.
class _TourCard extends StatelessWidget {
  const _TourCard({required this.tour, this.onTap});
  final TourHistoryView tour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final t = tour;
    final from = GameTime.yearOf(t.startWeek),
        to = GameTime.yearOf(t.endWeek - 1);
    final years = from == to ? '$from' : '$from–$to';
    final accent = t.reunion ? AppColors.lilac : AppColors.peach;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.r(18)),
          side: BorderSide(color: accent.withValues(alpha: 0.5))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(caps(context, t.artistName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: capsStyle(TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13))),
                ),
                Tag(l.tourHistoryRank(t.allTimeRank),
                    icon: Icons.emoji_events_outlined, color: AppColors.gold),
              ]),
              const SizedBox(height: 6),
              Text(t.kind == null ? t.name : fmt.tourName(t.name, t.kind!),
                  style: const TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontSize: 30,
                      height: 1.0,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  [
                    years,
                    // Unnamed tours are already called by their venues.
                    if (t.kind != null && t.name.isNotEmpty)
                      fmt.tourKind(t.kind!),
                    if (t.reunion) l.tourHistoryReunion,
                  ].join(' · '),
                  style: TextStyle(
                      color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              if (t.markets.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in t.markets)
                    Tag(fmt.tourMarket(m), color: AppColors.sky),
                ]),
              ],
              const SizedBox(height: 12),
              Row(children: [
                _Num(label: l.tourStatShows, value: '${t.shows}'),
                _Num(label: l.tourStatTickets, value: fmt.compact(t.tickets)),
                _Num(
                    label: l.tourStatGross,
                    value: fmt.money(t.grossCents.round())),
                if (t.detailed)
                  _Num(
                      label: l.tourHistorySoldOut,
                      value: '${t.soldOut}/${t.shows}'),
              ]),
              if (t.detailed) ...[
                const SizedBox(height: 8),
                Text(
                    l.tourHistoryNet(
                        '${t.netCents >= 0 ? '+' : '−'}${fmt.money(t.netCents.abs())}',
                        fmt.compact(t.fans)),
                    style: TextStyle(
                        color:
                            t.netCents >= 0 ? AppColors.mint : AppColors.coral,
                        fontWeight: FontWeight.w700)),
              ] else ...[
                const SizedBox(height: 8),
                Text(l.tourHistoryOld,
                    style:
                        TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ),
          Text(caps(context, label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: capsStyle(TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700))),
        ]),
      );
}
