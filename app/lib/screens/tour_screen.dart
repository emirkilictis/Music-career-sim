import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';

/// Plans a tour (docs K63, K76): markets with a venue size and a number of
/// shows each, ticket price, production, an opening act, a name; then the
/// expected numbers and the schedule night by night.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _LegDraft {
  _LegDraft(this.kind, this.shows);
  TourKind kind;
  int shows;
}

class _TourScreenState extends State<TourScreen> {
  final _name = TextEditingController();

  /// Chosen markets in the order they were added (the route).
  final Map<TourMarket, _LegDraft> _legs = {};
  double _price = 1.0;
  TourProduction _production = TourProduction.standard;
  OpenerView? _opener;
  TourPlanView? _plan;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    final p = widget.state.player;
    final home = switch (p.home) {
      HomeCountry.us => TourMarket.usa,
      HomeCountry.canada => TourMarket.canada,
      HomeCountry.uk => TourMarket.ukIreland,
      HomeCountry.europe => TourMarket.europe,
      HomeCountry.other => TourMarket.latinAmerica,
    };
    _legs[home] = _defaultLeg(home);
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The biggest venues the player can fill, about a third of the market.
  _LegDraft _defaultLeg(TourMarket m) {
    final fans = widget.state.player.coreFans;
    final kind = TourKind.values
        .lastWhere((k) => fans >= k.minFans, orElse: () => TourKind.club);
    return _LegDraft(kind, _defaultShows(m, kind));
  }

  int _defaultShows(TourMarket m, TourKind k) =>
      (Tours.maxShows(m, k) / 3).round().clamp(1, Tours.maxShows(m, k));

  TourRequest get _request => TourRequest(
        name: _name.text,
        legs: [
          for (final e in _legs.entries)
            TourLeg(e.key, e.value.kind, e.value.shows)
        ],
        priceFactor: _price,
        production: _production,
        openerId: _opener?.artistId ?? -1,
      );

  Future<void> _load() async {
    final asked = ++_asked;
    final plan = await widget.state.read(Cmd.tourPreview(_request));
    if (mounted && asked == _asked) setState(() => _plan = plan);
  }

  void _change(VoidCallback f) {
    setState(f);
    _load();
  }

  Future<void> _pickOpener() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final openers = await widget.state.read(Cmd.tourOpeners());
    if (!mounted) return;
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (c, scroll) => ListView(controller: scroll, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child:
                Text(l.tourPickOpener, style: Theme.of(c).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child:
                Text(l.tourOpenerHint, style: Theme.of(c).textTheme.bodySmall),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: Text(l.tourOpenerNone),
            onTap: () => Navigator.pop(c, false),
          ),
          for (final o in openers)
            ListTile(
              leading: const Icon(Icons.mic_external_on_rounded),
              title: Text(o.name),
              subtitle: Text('${fmt.genres([o.genre])} · '
                  '${l.fansValue(fmt.compact(o.coreFans))}'),
              trailing: Text(l.tourOpenerFee(fmt.money(o.feeCents)),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(c, o),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    _change(() => _opener = picked is OpenerView ? picked : null);
  }

  Future<void> _start() async {
    try {
      await widget.state.act(Cmd.startTour(_request));
      if (!mounted) return;
      showInfo(context, context.l10n.tourStarted, icon: Icons.stadium_rounded);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String _problem(String code) {
    final l = context.l10n;
    return switch (code) {
      'onTour' => l.tourProblemOnTour,
      'tourMarkets' => l.tourProblemMarkets,
      'tourTooBig' => l.tourProblemTooBig,
      _ => l.tourProblemShows,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final plan = _plan;
    final fans = widget.state.player.coreFans;
    return Scaffold(
      appBar: AppBar(title: Text(l.tourPlan)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            maxLength: 40,
            decoration: InputDecoration(
                labelText: l.tourName,
                hintText: l.tourNameHint,
                border: const OutlineInputBorder()),
          ),
          Section(
            title: l.tourWhere,
            icon: Icons.public_rounded,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.tourLegsHint,
                      style: Theme.of(context).textTheme.bodySmall),
                  for (final m in TourMarket.values)
                    _MarketTile(
                      market: m,
                      draft: _legs[m],
                      fans: fans,
                      estimate: plan?.legs
                          .where((v) => v.leg.market == m)
                          .firstOrNull,
                      onToggle: (on) => _change(() {
                        on ? _legs[m] = _defaultLeg(m) : _legs.remove(m);
                      }),
                      onKind: (k) => _change(() {
                        final d = _legs[m]!;
                        d.kind = k;
                        d.shows = d.shows.clamp(1, Tours.maxShows(m, k));
                      }),
                      onShows: (n) => _change(() => _legs[m]!.shows = n),
                    ),
                ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.tourTickets,
            icon: Icons.confirmation_number_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.tourPriceFactor((_price * 100).round()),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Slider(
                    value: _price,
                    min: Tours.minPriceFactor,
                    max: Tours.maxPriceFactor,
                    divisions: 14,
                    onChanged: (v) => setState(() => _price = v),
                    onChangeEnd: (_) => _load(),
                  ),
                  if (plan != null)
                    Text(
                        {
                          for (final v in plan.legs)
                            '${fmt.tourKind(v.leg.kind)} ${fmt.money(v.priceCents)}'
                        }.join(' · '),
                        style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(l.tourPriceHint,
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.tourProduction,
            icon: Icons.light_mode_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<TourProduction>(
                    showSelectedIcon: false,
                    segments: [
                      for (final p in TourProduction.values)
                        ButtonSegment(
                            value: p, label: Text(fmt.tourProduction(p))),
                    ],
                    selected: {_production},
                    onSelectionChanged: (s) =>
                        _change(() => _production = s.first),
                  ),
                  const SizedBox(height: 6),
                  Text(l.tourProdHint,
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.tourOpener,
            icon: Icons.mic_external_on_outlined,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_opener?.name ?? l.tourOpenerNone,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_opener == null
                  ? l.tourOpenerHint
                  : l.tourOpenerFee(fmt.money(_opener!.feeCents))),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickOpener,
            ),
          ),
          const SizedBox(height: 12),
          if (plan != null && plan.schedule.isNotEmpty) ...[
            _EstimateCard(plan: plan),
            const SizedBox(height: 12),
            _ScheduleCard(shows: plan.schedule),
          ],
          const SizedBox(height: 8),
          Text(l.tourHint(Tours.energyPerWeek.round()),
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (plan != null && !plan.available)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_problem(plan.problems.first),
                    style: TextStyle(
                        color: AppColors.coral, fontWeight: FontWeight.w600)),
              ),
            GradientButton(
              height: 50,
              label: l.tourStart,
              icon: Icons.directions_bus_rounded,
              onPressed: plan != null && plan.available && !widget.state.busy
                  ? _start
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}

/// One market: on or off, its venue size, its number of shows and what
/// the leg would do.
class _MarketTile extends StatelessWidget {
  const _MarketTile({
    required this.market,
    required this.draft,
    required this.fans,
    required this.estimate,
    required this.onToggle,
    required this.onKind,
    required this.onShows,
  });
  final TourMarket market;
  final _LegDraft? draft;
  final double fans;
  final TourLegView? estimate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TourKind> onKind;
  final ValueChanged<int> onShows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final d = draft;
    final e = estimate;
    final max = d == null ? 0 : Tours.maxShows(market, d.kind);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 8),
      decoration: BoxDecoration(
        color: d == null ? null : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppShape.r(14)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Checkbox(value: d != null, onChanged: (v) => onToggle(v ?? false)),
          Expanded(
            child: Text(fmt.tourMarket(market),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (d != null) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: d.shows > 1 ? () => onShows(d.shows - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            GestureDetector(
              onLongPress: () => onShows(max),
              child: Text(l.tourShowsCount(d.shows),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: d.shows < max ? () => onShows(d.shows + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ]),
        if (d != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (final k in TourKind.values)
                ChoiceChip(
                  label: Text(fmt.tourKind(k)),
                  selected: d.kind == k,
                  onSelected: fans >= k.minFans ? (_) => onKind(k) : null,
                  tooltip: fans >= k.minFans
                      ? null
                      : l.tourNeedsFans(fmt.compact(k.minFans)),
                ),
            ]),
          ),
          if (e != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
              child: Text(
                  l.tourLegEstimate((e.fill * 100).round(),
                      fmt.compact(e.tickets), fmt.money(e.priceCents)),
                  style: TextStyle(
                      color: e.fill >= 0.8
                          ? AppColors.mint
                          : e.fill >= 0.5
                              ? AppColors.textMuted
                              : AppColors.coral,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ]),
    );
  }
}

/// The money and crowds as planned.
class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.plan});
  final TourPlanView plan;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final e = plan.estimate;
    final net = plan.netCents;
    return Section(
      title: l.tourExpected,
      icon: Icons.insights_rounded,
      child: StatGrid(tiles: [
        StatTile(label: l.tourStatShows, value: '${e.shows}'),
        StatTile(label: l.tourStatWeeks, value: '${plan.weeks}'),
        StatTile(label: l.tourStatTickets, value: fmt.compact(e.tickets)),
        StatTile(label: l.tourStatFill, value: '${(e.fill * 100).round()}%'),
        StatTile(label: l.tourStatSoldOut, value: '${e.soldOut}'),
        StatTile(
            label: l.tourStatGross, value: fmt.money(e.grossCents.round())),
        StatTile(
            label: l.tourStatMerch, value: fmt.money(e.merchCents.round())),
        StatTile(
            label: l.tourStatProduction,
            value: fmt.money(e.productionCents.round())),
        if (e.openerCents > 0)
          StatTile(
              label: l.tourOpener, value: fmt.money(e.openerCents.round())),
        StatTile(
            label: l.tourStatFreight, value: fmt.money(e.freightCents.round())),
        StatTile(
            label: l.tourStatNet,
            value: '${net >= 0 ? '+' : '−'}${fmt.money(net.abs())}',
            color: net >= 0 ? AppColors.mint : AppColors.coral),
        StatTile(label: l.tourStatFans, value: '+${fmt.compact(e.fans)}'),
      ]),
    );
  }
}

/// Every night: week, city, venue, seats and tickets.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.shows});
  final List<TourShowView> shows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Section(
      title: l.tourSchedule,
      icon: Icons.event_note_rounded,
      trailing: Text(l.tourShowsCount(shows.length),
          style: TextStyle(color: AppColors.textMuted)),
      child: Column(children: [for (final s in shows) TourShowRow(show: s)]),
    );
  }
}

/// One night in a schedule or a box score.
class TourShowRow extends StatelessWidget {
  const TourShowRow({super.key, required this.show});
  final TourShowView show;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final s = show;
    final dim = !s.played && s.tickets == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 58,
          child: Text(l.tourShowWeek(s.weekOfTour),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        ),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.city, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(s.venue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
              dim
                  ? fmt.compact(s.capacity.toDouble())
                  : '${fmt.compact(s.tickets)} / ${fmt.compact(s.capacity.toDouble())}',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: s.soldOut ? AppColors.mint : null)),
          Text(
              s.soldOut
                  ? l.tourSoldOutTag
                  : s.played
                      ? fmt.money(s.grossCents)
                      : fmt.money(s.priceCents),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}
