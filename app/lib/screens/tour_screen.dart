import 'dart:math' as math;

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
  const TourScreen({super.key, required this.state, this.reunion});
  final CareerState state;

  /// Planning the reunion tour with the old group (docs K196).
  final ReunionView? reunion;

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _LegDraft {
  _LegDraft(this.kind, this.shows);
  TourKind kind;
  int shows;

  /// City → venue option the player picked (null: the routing picks;
  /// docs K223).
  Map<int, int>? stops;

  TourLeg leg(TourMarket m) => TourLeg(m, kind, shows,
      stops: stops == null
          ? null
          : [
              for (final c in stops!.keys.toList()..sort())
                TourStop(c, stops![c]!)
            ]);

  int maxShows(TourMarket m) => Tours.maxShowsOf(leg(m));
}

class _TourScreenState extends State<TourScreen> {
  final _name = TextEditingController();

  /// Chosen markets in the order they were added (the route).
  final Map<TourMarket, _LegDraft> _legs = {};
  double _price = 1.0;
  TourProduction _production = TourProduction.standard;
  OpenerView? _opener;

  /// The set in order (empty: the biggest songs; docs K223).
  List<int> _setlist = const [];
  TourPlanView? _plan;
  int _albumId = -1;
  bool _greatestHits = false;
  List<AlbumView> _albums = [];
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
    _fit(home);
  }

  /// Sizes [m]'s leg to the nights its fans can fill (docs K181).
  Future<void> _fit(TourMarket m) async {
    if (_legs[m] == null) return;
    final n = await widget.state.read(Cmd.suggestTourShows(_request, m));
    if (!mounted) return;
    final d = _legs[m];
    if (d != null) _change(() => d.shows = n);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The biggest venues the player can fill, about a third of the market.
  _LegDraft _defaultLeg(TourMarket m) {
    final fans = _fans;
    final kind = TourKind.values.lastWhere((k) => Tours.canPlay(fans, _fame, k),
        orElse: () => TourKind.club);
    return _LegDraft(kind, _defaultShows(m, kind));
  }

  int _defaultShows(TourMarket m, TourKind k) =>
      (Tours.maxShows(m, k) / 3).round().clamp(1, Tours.maxShows(m, k));

  /// The fans who buy the tickets: the group's on a reunion tour.
  double get _fans =>
      widget.reunion?.audience.fans ?? widget.state.player.coreFans;

  /// A famous enough name books big venues without the fans (docs K206).
  double get _fame => widget.reunion?.audience.fame ?? widget.state.player.fame;

  TourRequest get _request => TourRequest(
        reunion: widget.reunion != null,
        name: _name.text,
        legs: [for (final e in _legs.entries) e.value.leg(e.key)],
        setlist: _setlist,
        albumId: _albumId,
        greatestHits: _greatestHits,
        priceFactor: _price,
        production: _production,
        openerId: _opener?.artistId ?? -1,
      );

  Future<void> _load() async {
    final asked = ++_asked;
    final albums = await widget.state.read(Cmd.tourAlbums(_request));
    final plan = await widget.state.read(Cmd.tourPreview(_request));
    if (mounted && asked == _asked) {
      setState(() {
        _plan = plan;
        _albums = albums;
      });
    }
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

  /// The cities of [m]'s leg and the venue in each (docs K223).
  Future<void> _pickRoute(TourMarket m) async {
    final d = _legs[m];
    if (d == null) return;
    final cities = await widget.state.read(Cmd.tourCities(m, d.kind));
    if (!mounted) return;
    final picked = await showModalBottomSheet<_Route>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) =>
          _RouteSheet(market: m, cities: cities, stops: d.stops ?? const {}),
    );
    if (picked == null) return;
    _change(() {
      d.stops = picked.stops;
      d.shows = d.shows.clamp(1, math.max(1, d.maxShows(m)));
    });
  }

  /// The songs played each night (docs K223).
  Future<void> _editSetlist() async {
    final options = await widget.state.read(Cmd.setlistOptions(_request));
    if (!mounted) return;
    final current = _plan?.setlist.map((s) => s.songId).toList() ?? _setlist;
    final album = _albums.where((a) => a.id == _albumId).firstOrNull;
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => _SetlistSheet(
          options: options,
          picked: current,
          albumId: _albumId,
          focusIds: {...?album?.trackIds, ...?album?.hitTrackIds}),
    );
    if (picked == null) return;
    _change(() => _setlist = picked);
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
      'tourAlbum' => l.tourAlbumProblem,
      'onTour' => l.tourProblemOnTour,
      'tourMarkets' => l.tourProblemMarkets,
      'tourTooBig' => l.tourProblemTooBig,
      'reunionTourLong' => l.tourProblemReunionLong,
      'noReunion' => l.errorNoReunion,
      _ => l.tourProblemShows,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final plan = _plan;
    final fans = _fans;
    final reunion = widget.reunion;
    return Scaffold(
      appBar: AppBar(
          title: Text(reunion == null
              ? l.tourPlan
              : l.reunionTourTitle(reunion.groupName))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (reunion != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l.reunionTourHint(reunion.groupName),
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          TextField(
            controller: _name,
            maxLength: 40,
            decoration: InputDecoration(
                labelText: l.tourName,
                hintText: l.tourNameHint,
                border: const OutlineInputBorder()),
          ),
          DropdownButtonFormField<int>(
            initialValue: _greatestHits ? -2 : _albumId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.tourFocus),
            items: [
              DropdownMenuItem(value: -1, child: Text(l.tourIndependent)),
              DropdownMenuItem(value: -2, child: Text(l.tourGreatestHits)),
              for (final a in _albums)
                DropdownMenuItem(
                    value: a.id,
                    child: Text(a.title, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (id) => _change(() {
              _greatestHits = id == -2;
              _albumId = id! < 0 ? -1 : id;
            }),
          ),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l.tourAlbumEffect)),
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
                      fame: _fame,
                      estimate: plan?.legs
                          .where((v) => v.leg.market == m)
                          .firstOrNull,
                      onToggle: (on) {
                        _change(() {
                          on ? _legs[m] = _defaultLeg(m) : _legs.remove(m);
                        });
                        if (on) _fit(m);
                      },
                      onKind: (k) {
                        _change(() {
                          final d = _legs[m]!;
                          d.kind = k;
                          d.shows =
                              d.shows.clamp(1, math.max(1, d.maxShows(m)));
                        });
                        _fit(m);
                      },
                      onShows: (n) => _change(() => _legs[m]!.shows = n),
                      onFit: () => _fit(m),
                      onRoute: () => _pickRoute(m),
                    ),
                ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.tourSetlist,
            icon: Icons.queue_music_rounded,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (plan == null || plan.setlist.isEmpty)
                    Text(l.tourSetlistEmpty,
                        style: TextStyle(color: AppColors.textMuted))
                  else
                    for (final (i, s) in plan.setlist.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${i + 1}. ${s.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight:
                                    i == 0 || i == plan.setlist.length - 1
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                      ),
                  const SizedBox(height: 6),
                  Text(l.tourSetlistHint,
                      style: Theme.of(context).textTheme.bodySmall),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _editSetlist,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(l.tourSetlistEdit),
                    ),
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
          Text(l.tourHint(Tours.energyPerShow.round()),
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
    required this.fame,
    required this.estimate,
    required this.onToggle,
    required this.onKind,
    required this.onShows,
    required this.onFit,
    required this.onRoute,
  });
  final TourMarket market;
  final _LegDraft? draft;
  final double fans;
  final double fame;
  final TourLegView? estimate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TourKind> onKind;
  final ValueChanged<int> onShows;

  /// Sizes the leg to its demand (docs K181).
  final VoidCallback onFit;

  /// Picks the cities and venues (docs K223).
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final d = draft;
    final e = estimate;
    final max = d == null ? 0 : d.maxShows(market);
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
                  onSelected:
                      Tours.canPlay(fans, fame, k) ? (_) => onKind(k) : null,
                  tooltip: Tours.canPlay(fans, fame, k)
                      ? null
                      : l.tourNeedsFans(fmt.compact(k.minFans)),
                ),
            ]),
          ),
          if (e != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
              child: Row(children: [
                Expanded(
                    child: Text(
                        l.tourLegEstimate((e.fill * 100).round(),
                            fmt.compact(e.tickets), fmt.money(e.priceCents)),
                        style: TextStyle(
                            color: e.fill >= 0.8
                                ? AppColors.mint
                                : e.fill >= 0.5
                                    ? AppColors.textMuted
                                    : AppColors.coral,
                            fontWeight: FontWeight.w600))),
                TextButton.icon(
                  onPressed: onFit,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: Text(context.l10n.tourFit),
                ),
              ]),
            ),
          // Toured here lately, or the fans waited (docs K249).
          if (e != null && (e.mood - 1).abs() >= 0.02)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 0, 0),
              child: Text(
                  e.mood < 1
                      ? l.tourMarketTired(((1 - e.mood) * 100).round())
                      : l.tourMarketWaited(((e.mood - 1) * 100).round()),
                  style: TextStyle(
                      color: e.mood < 1 ? AppColors.coral : AppColors.mint,
                      fontSize: 12.5)),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRoute,
                icon: const Icon(Icons.location_city_rounded, size: 18),
                label: Text(d.stops == null
                    ? l.tourRouteAuto
                    : l.tourRouteCount(d.stops!.length)),
              ),
            ),
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

/// What the route sheet returns: the picked stops, or null for the
/// routing's own.
class _Route {
  const _Route(this.stops);
  final Map<int, int>? stops;
}

/// The cities of a leg, each on or off, with the venue played there
/// (docs K223).
class _RouteSheet extends StatefulWidget {
  const _RouteSheet(
      {required this.market, required this.cities, required this.stops});
  final TourMarket market;
  final List<TourCityView> cities;
  final Map<int, int> stops;

  @override
  State<_RouteSheet> createState() => _RouteSheetState();
}

class _RouteSheetState extends State<_RouteSheet> {
  late final Map<int, int> _stops = {...widget.stops};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (c, scroll) => Column(children: [
        Expanded(
          child: ListView(controller: scroll, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(fmt.tourMarket(widget.market),
                  style: Theme.of(c).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child:
                  Text(l.tourRouteHint, style: Theme.of(c).textTheme.bodySmall),
            ),
            for (final city in widget.cities)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        value: _stops.containsKey(city.city),
                        title: Text(city.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        onChanged: (on) => setState(() => on == true
                            ? _stops[city.city] = 0
                            : _stops.remove(city.city)),
                      ),
                      if (_stops.containsKey(city.city))
                        Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: Wrap(spacing: 6, runSpacing: 4, children: [
                            for (final (i, (name, seats))
                                in city.venues.indexed)
                              ChoiceChip(
                                label: Text(
                                    '$name · ${l.tourSeats(fmt.compact(seats.toDouble()))}'),
                                selected: _stops[city.city] == i,
                                onSelected: (_) =>
                                    setState(() => _stops[city.city] = i),
                              ),
                          ]),
                        ),
                    ]),
              ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context, const _Route(null)),
                child: Text(l.tourRouteAuto),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _stops.isEmpty
                    ? null
                    : () => Navigator.pop(context, _Route({..._stops})),
                child: Text(l.done),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Searchable, grouped library with a separately reorderable running order.
class _SetlistSheet extends StatefulWidget {
  const _SetlistSheet(
      {required this.options,
      required this.picked,
      required this.albumId,
      required this.focusIds});
  final List<SetlistSong> options;
  final List<int> picked;
  final int albumId;
  final Set<int> focusIds;
  @override
  State<_SetlistSheet> createState() => _SetlistSheetState();
}

class _SetlistSheetState extends State<_SetlistSheet> {
  late final List<int> _picked = [...widget.picked];
  String _query = '';
  bool _hide = true, _group = true;
  void _add(Iterable<SetlistSong> songs) {
    setState(() {
      for (final s in songs) {
        if (_picked.length == GameSession.maxSetlist) break;
        if (!_picked.contains(s.songId)) _picked.add(s.songId);
      }
    });
  }

  void _draft(int mode) {
    final songs = [...widget.options];
    songs.sort((a, b) {
      if (mode == 0) {
        final cmp = (widget.focusIds.contains(b.songId) ? 1 : 0)
            .compareTo(widget.focusIds.contains(a.songId) ? 1 : 0);
        if (cmp != 0) return cmp;
      }
      if (mode == 2) {
        final cmp = b.fanScore.compareTo(a.fanScore);
        if (cmp != 0) return cmp;
      }
      if (mode == 1) {
        final cmp =
            (a.peak > 0 ? a.peak : 999).compareTo(b.peak > 0 ? b.peak : 999);
        if (cmp != 0) return cmp;
      }
      return b.streams.compareTo(a.streams);
    });
    setState(() {
      _picked.clear();
      _picked.addAll(songs.take(20).map((s) => s.songId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final byId = {for (final s in widget.options) s.songId: s};
    final visible = widget.options
        .where((s) =>
            (!_hide || !_picked.contains(s.songId)) &&
            '${s.title} ${s.albumTitle ?? ''}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => b.streams.compareTo(a.streams));
    final groups = <int, List<SetlistSong>>{};
    for (final s in visible) {
      groups.putIfAbsent(_group ? s.albumId : -2, () => []).add(s);
    }
    final full = _picked.length >= GameSession.maxSetlist;
    return SizedBox(
        height: (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom) *
            .9,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                Text(
                    '${l.tourSetlist} · ${_picked.length}/${GameSession.maxSetlist}',
                    style: Theme.of(context).textTheme.titleLarge),
                TextField(
                    decoration: InputDecoration(
                        hintText: l.setSearch,
                        prefixIcon: const Icon(Icons.search)),
                    onChanged: (v) => setState(() => _query = v)),
                Wrap(spacing: 8, children: [
                  FilterChip(
                      label: Text(l.setHide),
                      selected: _hide,
                      onSelected: (v) => setState(() => _hide = v)),
                  FilterChip(
                      label: Text(l.setAlbums),
                      selected: _group,
                      onSelected: (v) => setState(() => _group = v)),
                ]),
                Wrap(spacing: 6, children: [
                  ActionChip(
                      label: Text(l.setAlbumDraft),
                      onPressed: widget.albumId < 0 ? null : () => _draft(0)),
                  ActionChip(
                      label: Text(l.setHitsDraft), onPressed: () => _draft(1)),
                  ActionChip(
                      label: Text(l.setFansDraft), onPressed: () => _draft(2)),
                ]),
                Text(l.setDraftHint,
                    style: Theme.of(context).textTheme.bodySmall),
                if (full)
                  Text(l.setFull, style: TextStyle(color: AppColors.coral)),
              ])),
          Expanded(
              child: ListView(children: [
            if (_picked.isNotEmpty) ...[
              ExpansionTile(
                initiallyExpanded: false,
                maintainState: true,
                title: Text('${l.setSelected} (${_picked.length})'),
                children: [
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _picked.length,
                    onReorderItem: (old, next) => setState(() {
                      _picked.insert(next, _picked.removeAt(old));
                    }),
                    itemBuilder: (c, i) {
                      final s = byId[_picked[i]]!;
                      return ListTile(
                        key: ValueKey(s.songId),
                        leading: Text('${i + 1}'),
                        title: Text(s.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(s.albumTitle ?? l.setSingles,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Padding(
                            padding: const EdgeInsets.only(right: 36),
                            child: IconButton(
                                tooltip: MaterialLocalizations.of(c)
                                    .deleteButtonTooltip,
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    setState(() => _picked.remove(s.songId)))),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
            ],
            for (final entry in groups.entries) ...[
              ListTile(
                  title: Text(
                      _group
                          ? entry.value.first.albumTitle ?? l.setSingles
                          : l.setPopular,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: _group
                      ? TextButton(
                          onPressed: full ? null : () => _add(entry.value),
                          child: Text(l.setAddAlbum))
                      : null),
              for (final s in entry.value)
                ListTile(
                  leading: Icon(_picked.contains(s.songId)
                      ? Icons.check_circle
                      : Icons.add_circle_outline),
                  title: Text(s.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(l.earningsStreams(fmt.compact(s.streams))),
                  enabled: !full || _picked.contains(s.songId),
                  onTap: () => _picked.contains(s.songId)
                      ? setState(() => _picked.remove(s.songId))
                      : _add([s]),
                ),
            ],
            if (widget.options.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.tourSetlistEmpty)),
          ])),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    TextButton(
                        onPressed: () => setState(() {
                              _picked.clear();
                              _picked.addAll(
                                  widget.options.take(12).map((s) => s.songId));
                            }),
                        child: Text(l.tourSetlistDefault)),
                    const Spacer(),
                    FilledButton(
                        onPressed: _picked.isEmpty
                            ? null
                            : () => Navigator.pop(context, [..._picked]),
                        child: Text(l.done)),
                  ]))),
        ]));
  }
}
