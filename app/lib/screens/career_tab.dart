import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/manager_section.dart';
import '../widgets/festival_section.dart';
import '../widgets/tour_section.dart';
import '../widgets/milestones_section.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/income_card.dart';
import '../widgets/image_pickers.dart';
import 'awards_screen.dart';
import 'discography_screen.dart';
import 'album_detail_screen.dart';
import 'labels_screen.dart';
import 'member_album_screen.dart';
import 'game_shell.dart';
import 'song_detail_screen.dart';
import 'streamify/artist_page.dart';

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

  /// Vault songs not set for a release, for members' solo records.
  List<SongView> _vault = const [];
  HonorsView? _honors;
  List<WrittenSongView> _written = const [];
  List<MemberView> _members = const [];

  /// The group the player left (docs K191).
  (ArtistView, bool)? _former;
  FanClubView? _club;
  ImprintView? _label;
  FycView? _fyc;
  DocumentaryView? _doc;
  List<WrittenSongView> _guest = const [];
  IncomeBreakdown? _income;
  CatalogOfferView? _catalog;
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
    final written = await career.read(Cmd.writtenForOthers());
    final members = await career.read(Cmd.members());
    final former = await career.read(Cmd.formerGroup());
    final club = await career.read(Cmd.fanClub());
    final label = await career.read(Cmd.imprint());
    final fyc = await career.read(Cmd.fyc());
    final doc = await career.read(Cmd.documentary());
    final guest = await career.read(Cmd.guestSongs());
    final income = await career.read(Cmd.careerIncome());
    final catalog = await career.read(Cmd.catalogOffer());
    if (mounted) {
      setState(() {
        _years = years;
        _honors = honors;
        _written = written;
        _members = members;
        _former = former;
        _club = club;
        _label = label;
        _fyc = fyc;
        _doc = doc;
        _guest = guest;
        _income = income;
        _catalog = catalog;
        final fmt = context.fmt;
        final week = career.week;
        _vault = [
          for (final s in songs)
            if (s.inVault &&
                s.scheduledSingleWeek < 0 &&
                s.scheduledAlbumWeek < 0)
              s
        ];
        _songs = songs.where((s) => !s.inVault).toList()
          ..sort((a, b) =>
              fmt.songMainValue(b, week).compareTo(fmt.songMainValue(a, week)));
      });
    }
  }

  Widget _docSection(DocumentaryView d) {
    final l = context.l10n;
    final fmt = context.fmt;
    final muted = TextStyle(color: AppColors.textMuted, fontSize: 12.5);
    return Section(
      title: l.docTitle,
      icon: Icons.movie_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.docHint, style: muted),
        const SizedBox(height: 8),
        for (final x in d.docs)
          Text(
              x.premiered
                  ? l.docOut(x.title, fmt.week(x.premiereWeek))
                  : l.docFilming(x.title, fmt.week(x.premiereWeek)),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        if (d.block == null) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _startDoc(DocDeal.selfFunded),
            icon: const Icon(Icons.smart_display_outlined),
            label: Text(l.docSelf(fmt.money(Documentaries.selfCostCents))),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _startDoc(DocDeal.original),
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(l.docOriginal(fmt.money(d.originalFeeCents))),
          ),
        ] else if (d.block != DocBlock.filming)
          Text(
              switch (d.block!) {
                DocBlock.tooEarly => l.docTooEarly,
                DocBlock.notKnown =>
                  l.docNotKnown((Documentaries.minFame * 100).round()),
                _ => l.docTooSoon(Documentaries.gapYears),
              },
              style: muted),
      ]),
    );
  }

  Future<void> _startDoc(DocDeal deal) async {
    final l = context.l10n;
    final career = context.careerRead;
    final ctrl = TextEditingController(text: l.docDefault(career.player.name));
    final title = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.docName),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 60),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(d, ctrl.text), child: Text(l.ok)),
        ],
      ),
    );
    // Not disposed here: the closing animation still builds with it, and
    // nothing holds it once the route is gone (K188).
    if (title == null || !mounted) return;
    try {
      await career.act(Cmd.startDocumentary(deal, title));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _runFyc(FycTier t) async {
    final l = context.l10n;
    try {
      await context.careerRead.act(Cmd.runFyc(t));
      if (mounted) {
        showInfo(context, l.fycDone, icon: Icons.emoji_events_rounded);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String _fycName(FycTier t) {
    final l = context.l10n;
    return switch (t) {
      FycTier.small => l.fycSmall,
      FycTier.big => l.fycBig,
      FycTier.allOut => l.fycAllOut,
    };
  }

  Widget _labelSection(ImprintView v) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final muted = TextStyle(color: AppColors.textMuted, fontSize: 12.5);
    return Section(
      title: v.founded ? v.name : l.imprintTitle,
      icon: Icons.business_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.imprintHint((Imprints.share * 100).round()), style: muted),
        const SizedBox(height: 8),
        if (!v.founded) ...[
          if (!v.canFound)
            Text(l.imprintNeedFame((Imprints.minFame * 100).round()),
                style: const TextStyle(fontWeight: FontWeight.w700))
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _foundLabel,
                icon: const Icon(Icons.business_rounded),
                label: Text(l.imprintFound(fmt.money(Imprints.foundCents))),
              ),
            ),
        ] else ...[
          Text(
              l.imprintRoster(v.roster.length, Imprints.maxRoster,
                  fmt.money(v.earnedCents.round())),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final s in v.roster)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ArtistAvatar(
                  name: s.name, seed: s.artistId, artistId: s.artistId),
              title: Text(s.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                l.imprintSignee(
                    fmt.money(s.earnedCents.round()), fmt.week(s.signedWeek)),
                if (s.bestPeak > 0) l.imprintSigneePeak(s.bestPeak),
              ].join('\n')),
              isThreeLine: s.bestPeak > 0,
              trailing: TextButton(
                onPressed: () async {
                  try {
                    await career.act(Cmd.dropFromImprint(s.artistId));
                  } catch (e) {
                    if (mounted) showError(context, e);
                  }
                },
                child: Text(l.imprintDrop),
              ),
            ),
          // The label push (docs K170).
          for (final s in v.roster)
            if (s.pushTitle case final title?)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      await career.act(Cmd.pushSignee(s.artistId));
                      if (mounted) {
                        showInfo(context, l.imprintPushed(title),
                            icon: Icons.campaign_rounded);
                      }
                    } catch (e) {
                      if (mounted) showError(context, e);
                    }
                  },
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(
                      '${s.name}: ${l.imprintPush(title, fmt.money(s.pushCostCents))}'),
                ),
              ),
          if (v.roster.any((s) => s.pushTitle != null))
            Text(l.imprintPushHint(Imprints.pushGapWeeks), style: muted),
          if (v.roster.length < Imprints.maxRoster)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _signArtist,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: Text(l.imprintSign),
              ),
            ),
        ],
      ]),
    );
  }

  Future<void> _foundLabel() async {
    final l = context.l10n;
    final career = context.careerRead;
    final ctrl =
        TextEditingController(text: l.imprintDefaultName(career.player.name));
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.imprintName),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 40),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(d, ctrl.text), child: Text(l.ok)),
        ],
      ),
    );
    // Not disposed here: the closing animation still builds with it, and
    // nothing holds it once the route is gone (K188).
    if (name == null || !mounted) return;
    try {
      await career.act(Cmd.foundImprint(name));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _signArtist() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final list = await career.read(Cmd.imprintCandidates());
    if (!mounted) return;
    final money = career.player.moneyCents;
    final pick = await showModalBottomSheet<SigneeCandidateView>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (s) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(s).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.imprintSignTitle,
                  style: Theme.of(s).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in list)
                  ListTile(
                    enabled: c.advanceCents <= money,
                    leading: ArtistAvatar(
                        name: c.name, seed: c.artistId, artistId: c.artistId),
                    title: Text(c.name),
                    subtitle: Text(l.imprintCandidate(
                        fmt.genre(c.genre), c.debutYear, fmt.compact(c.fans))),
                    trailing: Text(fmt.money(c.advanceCents)),
                    onTap: () => Navigator.pop(s, c),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      await career.act(Cmd.signToImprint(pick.artistId));
      if (mounted) {
        showInfo(context, l.imprintSigned(pick.name),
            icon: Icons.business_rounded);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _clubSection(FanClubView c) {
    final l = context.l10n;
    final fmt = context.fmt;
    final muted = TextStyle(color: AppColors.textMuted, fontSize: 12.5);
    return Section(
      title: l.clubTitle,
      icon: Icons.card_membership_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.clubHint, style: muted),
        const SizedBox(height: 8),
        if (!c.open) ...[
          if (!c.canOpen)
            Text(l.clubNeedFans(fmt.compact(FanClubs.minFans.toDouble())),
                style: const TextStyle(fontWeight: FontWeight.w700))
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _clubPrice(c, opening: true),
                icon: const Icon(Icons.card_membership_rounded),
                label: Text(l.clubOpen(fmt.money(FanClubs.setupCents))),
              ),
            ),
        ] else ...[
          Text(l.clubMembers(fmt.compact(c.members), fmt.compact(c.target)),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
              l.clubMoney(fmt.money(c.weekCents.round()),
                  fmt.money(c.revenueCents.round())),
              style: muted),
          if (c.activity < 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.clubQuiet,
                  style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _clubPrice(c, opening: false),
              icon: const Icon(Icons.sell_outlined),
              label: Text(
                  '${l.clubChangePrice} · ${fmt.money(c.price.monthCents)}'),
            ),
          ),
        ],
      ]),
    );
  }

  /// Picks the membership price, opening the club or changing it.
  Future<void> _clubPrice(FanClubView c, {required bool opening}) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final pick = await showModalBottomSheet<ClubPrice>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child:
                Text(l.clubPriceTitle, style: Theme.of(s).textTheme.titleLarge),
          ),
          for (final p in ClubPrice.values)
            ListTile(
              selected: c.open && p == c.price,
              leading: const Icon(Icons.card_membership_rounded),
              title: Text(l.clubPriceLine(
                  fmt.money(p.monthCents), fmt.compact(c.estimates[p] ?? 0))),
              onTap: () => Navigator.pop(s, p),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      await career
          .act(opening ? Cmd.openFanClub(pick) : Cmd.setClubPrice(pick));
      if (mounted && opening) {
        showInfo(context, l.clubOpened, icon: Icons.card_membership_rounded);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// A song the player is on under another name, or wrote (K143, K158).
  Widget _creditTile(WrittenSongView w, CareerState career) {
    final l = context.l10n;
    final fmt = context.fmt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(w.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([
        w.artistName,
        if (!w.released) l.writtenComing,
        if (w.peak > 0) l.writtenPeak(w.peak),
        if (w.streams >= 1) l.streamsValue(fmt.compact(w.streams)),
      ].join(' · ')),
      trailing: Text(fmt.money(w.earnedCents.round()),
          style: const TextStyle(fontWeight: FontWeight.w800)),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  SongDetailScreen(songId: w.songId, state: career))),
    );
  }

  /// Picks how an independent's music gets out (docs K157).
  Future<void> _distribution() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final v = await career.read(Cmd.distribution());
    if (!mounted) return;
    final pick = await showModalBottomSheet<Distributor>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.distributorTitle,
                style: Theme.of(c).textTheme.titleLarge),
          ),
          for (final d in Distributor.values)
            ListTile(
              enabled: v.available.contains(d),
              selected: d == v.current,
              title: Text(fmt.distributor(d)),
              subtitle: Text([
                fmt.distributorHint(d),
                l.distributorTerms(
                    (d.share * 100).round(), (d.reach * 100).round()),
                if (d == Distributor.deal)
                  l.distributorAdvance(fmt.money(v.dealAdvanceCents)),
                if (v.year < d.fromYear) l.distributorFrom(d.fromYear),
                if (d.minFans > 0)
                  l.distributorFans(fmt.compact(d.minFans.toDouble())),
              ].join('\n')),
              isThreeLine: true,
              onTap: () => Navigator.pop(c, d),
            ),
          if (v.current == Distributor.deal && v.unrecoupedCents > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.distributorRecoup(fmt.money(v.unrecoupedCents)),
                  style: Theme.of(c).textTheme.bodySmall),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      await career.act(Cmd.chooseDistributor(pick));
      if (mounted) {
        showInfo(context, l.distributorDone(fmt.distributor(pick)),
            icon: Icons.local_shipping_outlined);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Sells the catalog after asking (docs K153).
  /// A member's roles, popularity and the label's push (docs K192).
  List<Widget> _lineupLines(MemberView m) {
    final l = context.l10n;
    final fmt = context.fmt;
    return [
      if (m.roles.isNotEmpty)
        Text(m.roles.map(fmt.memberRole).join(' · '),
            style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: m.popularity / 100,
          minHeight: 5,
          color: m.focused ? AppColors.gold : AppColors.mint,
          backgroundColor: AppColors.textMuted.withValues(alpha: 0.2),
        ),
      ),
      const SizedBox(height: 2),
      Text(
          [
            l.memberPopularity(m.popularity.round(), (m.share * 100).round()),
            if (m.focused) l.memberFocused(m.focusWeeks),
          ].join(' · '),
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
    ];
  }

  Future<void> _act(SessionCmd<void> cmd) async {
    try {
      await context.careerRead.act(cmd);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Picks [m]'s roles (docs K192).
  Future<void> _editRoles(MemberView m) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final kind = context.careerRead.player.kind;
    final picked = await showModalBottomSheet<Set<MemberRole>>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        final chosen = {...m.roles};
        return StatefulBuilder(
          builder: (c, set) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.memberRolesTitle(m.name),
                        style: Theme.of(c).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(l.memberRolesHint(m.name),
                        style: Theme.of(c).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final r in MemberRole.forKind(kind))
                        FilterChip(
                          label: Text(fmt.memberRole(r)),
                          selected: chosen.contains(r),
                          onSelected: (on) =>
                              set(() => on ? chosen.add(r) : chosen.remove(r)),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(c, chosen),
                        child: Text(l.save),
                      ),
                    ),
                  ]),
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await _act(Cmd.setMemberRoles(m.index, picked));
  }

  /// A member leaves and the player goes on as them (docs K191).
  Future<void> _goSolo(MemberView m) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final GoSoloView v;
    try {
      v = await career.read(Cmd.goSoloPreview(m.index));
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    if (v.block == GoSoloBlock.onTour) {
      showInfo(context, l.errorOnTour, icon: Icons.tour_outlined);
      return;
    }
    final group = career.player.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.goSoloTitle(v.name)),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in [
                  l.goSoloIntro(v.name),
                  l.goSoloFans(
                      v.name, fmt.compact(v.fans), (v.fame * 100).round()),
                  v.hiatus
                      ? l.goSoloHiatus(group, v.name)
                      : v.groupBreaksUp
                          ? l.goSoloGroupEnds(group)
                          : l.goSoloGroupOn(group, fmt.compact(v.groupFans)),
                  if (v.ace)
                    l.goSoloAce(v.name)
                  else if (v.importance < 0.7)
                    l.goSoloQuiet(v.name),
                  l.goSoloRecords,
                  if (v.scheduled > 0) l.goSoloScheduled(v.scheduled),
                  if (v.fanClub) l.goSoloClub,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(line),
                  ),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l.goSoloConfirm)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await career.act(Cmd.goSolo(m.index));
      if (mounted) {
        showInfo(context, l.goSoloDone(v.name), icon: Icons.person_rounded);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _formerSection((ArtistView, bool) former) {
    final l = context.l10n;
    final fmt = context.fmt;
    final (g, ended) = former;
    return Section(
      title: l.formerGroupSection,
      icon: Icons.groups_2_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(
            ended
                ? l.formerGroupEnded
                : l.formerGroupLine(
                    fmt.compact(g.coreFans), (g.fame * 100).round()),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        const SizedBox(height: 4),
        Text(
            l.formerGroupTotals(fmt.compact(g.lifetimeStreams.total),
                fmt.compact(g.lifetimeTotalUnits.total)),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.graphic_eq_rounded, size: 18),
            label: Text(l.formerGroupPage),
            onPressed: () => pushInCareer(context, ArtistPage(artistId: g.id)),
          ),
        ),
      ]),
    );
  }

  Future<void> _sellCatalog(CatalogOfferView c) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.catalogTitle),
        content: Text(l.catalogConfirm(c.songs, fmt.money(c.offerCents))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l.catalogSell(fmt.money(c.offerCents)))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final price = await career.act(Cmd.sellCatalog());
      if (mounted) {
        showInfo(context, l.catalogSold(fmt.money(price)),
            icon: Icons.sell_outlined);
      }
    } catch (e) {
      if (mounted) showError(context, e);
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
            // How an independent's music gets out (docs K157).
            if (p.label == Label.independent) ...[
              const SizedBox(height: 6),
              Text(l.distributorLine(fmt.distributor(p.distributor)),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _distribution,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: Text(l.distributorChange),
                ),
              ),
            ],
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
        // Record money by source (docs K145).
        if (_income case final income? when income.total >= 100) ...[
          const SizedBox(height: 12),
          IncomeCard(income: income, title: l.incomeCareerTitle),
        ],
        // Selling the catalog (docs K153).
        if (_catalog case final c? when c.open && c.offerCents > 0) ...[
          const SizedBox(height: 12),
          Section(
            title: l.catalogTitle,
            icon: Icons.account_balance_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      l.catalogLine(c.songs, fmt.money(c.yearCents.round()),
                          c.multiple.round()),
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _sellCatalog(c),
                    icon: const Icon(Icons.sell_outlined),
                    label: Text(l.catalogSell(fmt.money(c.offerCents))),
                  ),
                ]),
          ),
        ],
        // Documentaries (docs K172).
        if (_doc case final doc?
            when doc.block != DocBlock.tooEarly || doc.docs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _docSection(doc),
        ],
        // The player's own label (docs K169).
        if (_label case final label?) ...[
          const SizedBox(height: 12),
          _labelSection(label),
        ],
        // The paid fan club (docs K164).
        if (_club case final club?) ...[
          const SizedBox(height: 12),
          _clubSection(club),
        ],
        if (_former case final f?) ...[
          const SizedBox(height: 12),
          _formerSection(f),
        ],
        // Members' solo records and the player's features (docs K158).
        if (_members.isNotEmpty) ...[
          const SizedBox(height: 12),
          Section(
            title: l.membersSection,
            icon: Icons.groups_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.membersHint,
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Text(l.lineupHint,
                      style: TextStyle(color: AppColors.textMuted)),
                  for (final m in _members) ...[
                    const SizedBox(height: 14),
                    Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    ..._lineupLines(m),
                    Text(
                        m.artistId < 0
                            ? l.membersNoSolo
                            : l.memberFans(fmt.compact(m.fans)),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                    for (final a in m.albums)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.album_outlined),
                        title: Text(a.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([
                          l.memberAlbumLine(
                              fmt.albumType(a.type), fmt.compact(a.firstWeek)),
                          if (a.peak > 0) l.memberAlbumPeak(a.peak),
                        ].join(' · ')),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AlbumDetailScreen(
                                    albumId: a.id, state: career))),
                      ),
                    for (final w in m.songs) _creditTile(w, career),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.album_outlined, size: 18),
                        label: Text(l.memberAlbumButton),
                        onPressed: career.busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => MemberAlbumScreen(
                                        state: career,
                                        member: m,
                                        songs: _vault))),
                      ),
                    ),
                    // The label's push and the member's roles (docs K192).
                    Wrap(spacing: 4, children: [
                      TextButton.icon(
                        icon: Icon(
                            m.focused
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18),
                        label:
                            Text(m.focused ? l.memberUnfocus : l.memberFocus),
                        onPressed: career.busy
                            ? null
                            : () => _act(
                                Cmd.setMemberFocus(m.focused ? -1 : m.index)),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: Text(l.memberRolesButton),
                        onPressed: career.busy ? null : () => _editRoles(m),
                      ),
                    ]),
                    // Leaving the group (docs K191).
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon:
                            const Icon(Icons.person_outline_rounded, size: 18),
                        label: Text(l.goSoloButton),
                        onPressed: career.busy ? null : () => _goSolo(m),
                      ),
                    ),
                  ],
                ]),
          ),
        ],
        if (_guest.isNotEmpty) ...[
          const SizedBox(height: 12),
          Section(
            title: l.guestSection,
            icon: Icons.mic_external_on_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.guestHint((Credits.guestShare * 100).round()),
                      style: TextStyle(color: AppColors.textMuted)),
                  for (final w in _guest) _creditTile(w, career),
                ]),
          ),
        ],
        // Songs written for others (docs K143).
        if (_written.isNotEmpty) ...[
          const SizedBox(height: 12),
          Section(
            title: l.writtenSection,
            icon: Icons.edit_note_rounded,
            child: Column(children: [
              for (final w in _written)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(w.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    w.artistName,
                    if (!w.released) l.writtenComing,
                    if (w.peak > 0) l.writtenPeak(w.peak),
                  ].join(' · ')),
                  trailing: Text(fmt.money(w.earnedCents.round()),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SongDetailScreen(
                              songId: w.songId, state: career))),
                ),
            ]),
          ),
        ],
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
            // For Your Consideration (docs K171).
            if (_fyc case final f? when f.phase != FycPhase.closed) ...[
              const Divider(height: 24),
              Text(l.fycTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                  f.phase == FycPhase.nominations
                      ? l.fycNominations(f.year)
                      : l.fycVoting(f.year),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              const SizedBox(height: 6),
              if (f.running case final r?)
                Text(l.fycRunning(_fycName(r)),
                    style: const TextStyle(fontWeight: FontWeight.w700))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in FycTier.values)
                    OutlinedButton(
                      onPressed: () => _runFyc(t),
                      child:
                          Text(l.fycTier(_fycName(t), fmt.money(t.costCents))),
                    ),
                ]),
            ],
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
