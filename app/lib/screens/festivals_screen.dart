import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';

/// The festival calendar (docs K77): every festival's next edition, the
/// slot the player would get, booking, and each bill.
class FestivalsScreen extends StatefulWidget {
  const FestivalsScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<FestivalsScreen> createState() => _FestivalsScreenState();
}

class _FestivalsScreenState extends State<FestivalsScreen> {
  List<FestivalView>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.state.read(Cmd.festivals());
    if (mounted) setState(() => _list = list);
  }

  Future<void> _book(FestivalView f) async {
    try {
      await widget.state.act(Cmd.bookFestival(f.index));
      if (mounted) {
        showInfo(context, context.l10n.festivalBookedToast(f.festival.name),
            icon: Icons.festival_rounded);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    _load();
  }

  Future<void> _cancel(FestivalView f) async {
    try {
      await widget.state.act(Cmd.cancelFestival(f.index, f.year));
    } catch (e) {
      if (mounted) showError(context, e);
    }
    _load();
  }

  Future<void> _lineup(FestivalView f) async {
    final fmt = context.fmt;
    final bill = await widget.state.read(Cmd.festivalLineup(f.index, f.year));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (c, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(f.festival.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    letterSpacing: 1.5)),
            Text('${f.festival.city} · ${fmt.week(f.week)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            for (final s in FestivalSlot.values) ...[
              Text(fmt.festivalSlot(s).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 2,
                children: [
                  for (final a in bill[s] ?? const <FestivalAct>[])
                    Text(a.name,
                        style: TextStyle(
                            fontFamily: AppFonts.condensed,
                            fontWeight: FontWeight.w800,
                            fontSize: switch (s) {
                              FestivalSlot.headliner => 26,
                              FestivalSlot.subHeadliner => 20,
                              FestivalSlot.mainStage => 16,
                              FestivalSlot.smallStage => 13.5,
                            },
                            color: a.isPlayer ? AppColors.pink : null)),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: Text(l.festivalSeason)),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l.festivalHint,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final f in list)
                  _FestivalCard(
                    festival: f,
                    busy: widget.state.busy,
                    onBook: () => _book(f),
                    onCancel: () => _cancel(f),
                    onLineup: () => _lineup(f),
                  ),
              ],
            ),
    );
  }
}

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({
    required this.festival,
    required this.busy,
    required this.onBook,
    required this.onCancel,
    required this.onLineup,
  });
  final FestivalView festival;
  final bool busy;
  final VoidCallback onBook;
  final VoidCallback onCancel;
  final VoidCallback onLineup;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final f = festival;
    final info = f.festival;
    final shown = f.booked ?? f.slot;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.r(18)),
        border: f.booked != null
            ? Border.all(color: AppColors.pink, width: 1.5)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.r(18)),
        onTap: onLineup,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(info.name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Text(fmt.week(f.week),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ]),
            const SizedBox(height: 2),
            Text(
                l.festivalWhere('${info.city}, ${fmt.tourMarket(info.market)}',
                    info.days, fmt.compact(info.crowd.toDouble())),
                style: TextStyle(color: AppColors.textMuted)),
            Text(
                info.genres.isEmpty
                    ? l.festivalAllGenres
                    : l.festivalGenres(fmt.genres(info.genres)),
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            if (!f.fitsGenre)
              Text(l.festivalWrongGenre,
                  style: TextStyle(color: AppColors.textMuted))
            else if (shown == null)
              Text(
                  l.festivalTooSmall(
                      fmt.compact(FestivalSlot.smallStage.minFans)),
                  style: TextStyle(color: AppColors.coral))
            else
              Text(
                  l.festivalOffer(
                      fmt.festivalSlot(shown),
                      fmt.money(f.feeCents),
                      fmt.compact(f.watched),
                      fmt.compact(f.fans)),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              TextButton.icon(
                onPressed: onLineup,
                icon: const Icon(Icons.groups_rounded, size: 18),
                label: Text(l.festivalLineup),
              ),
              const Spacer(),
              if (f.booked != null) ...[
                Text(l.festivalBooked(fmt.festivalSlot(f.booked!)),
                    style: TextStyle(
                        color: AppColors.pink, fontWeight: FontWeight.w700)),
                TextButton(
                    onPressed: busy ? null : onCancel,
                    child: Text(l.festivalCancel)),
              ] else if (f.canBook)
                FilledButton(
                    onPressed: busy ? null : onBook,
                    child: Text(l.festivalBook)),
            ]),
          ]),
        ),
      ),
    );
  }
}
