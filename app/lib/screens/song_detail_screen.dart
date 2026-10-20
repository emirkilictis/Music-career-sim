import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/profit_card.dart';
import '../widgets/campaign_result.dart';
import '../widgets/image_pickers.dart';
import '../core/images.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart' show platformColor;
import '../widgets/income_card.dart';
import '../widgets/artist_link.dart';
import '../widgets/history_tables.dart';
import '../widgets/line_chart.dart';
import 'album_detail_screen.dart' show buyMastersFlow;
import 'game_shell.dart';
import 'releases_tab.dart';
import 'streamify/editorial_page.dart';

/// One song: numbers, chart records, weekly history.
class SongDetailScreen extends StatefulWidget {
  const SongDetailScreen(
      {super.key, required this.songId, required this.state});
  final int songId;
  final CareerState state;

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  SongView? _song;
  List<HistoryPoint> _history = const [];
  List<ChartWeek> _run = const [];
  List<EditorialPlacement> _playlists = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The song's record money by source (docs K145).
  IncomeBreakdown? _income;

  Future<void> _load() async {
    final song = await widget.state.read(Cmd.song(widget.songId));
    final history = await widget.state.read(Cmd.songHistory(widget.songId));
    final run =
        await widget.state.read(Cmd.chartRun(EntityKind.song, widget.songId));
    final playlists = await widget.state.read(Cmd.placements(widget.songId));
    final income = song.isPlayer && song.releasedWeek >= 0
        ? await widget.state.read(Cmd.songIncome(widget.songId))
        : null;
    if (mounted) {
      setState(() {
        _income = income;
        _song = song;
        _history = history;
        _run = run;
        _playlists = playlists;
      });
    }
  }

  /// Asks a rival to feature on the song for their fee (docs K117).
  Future<void> _feature(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final money = widget.state.player.moneyCents;
    final list = await widget.state.read(Cmd.featureCandidates(s.id));
    if (!mounted) return;
    final pick = await showModalBottomSheet<FeatureCandidateView>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child:
                  Text(l.featureTitle, style: Theme.of(c).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(s.inVault ? l.featureHint : l.remixFeatureHint,
                  style: Theme.of(c).textTheme.bodySmall),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final a in list)
                  ListTile(
                    enabled: a.willing && a.feeCents <= money,
                    leading: ArtistAvatar(
                        name: a.name, seed: a.artistId, artistId: a.artistId),
                    title: Text(a.name),
                    subtitle: Text([
                      a.willing
                          ? l.featureLine(
                              fmt.genre(a.genre), (a.fame * 100).round())
                          : l.featureLocked,
                      // Put on the player's playlist (docs K159).
                      if (a.favoured) l.ownPlFavoured,
                      // On the player's own label (docs K170).
                      if (a.labelMate) l.labelMate,
                    ].join(' · ')),
                    trailing: Text(fmt.money(a.feeCents)),
                    onTap: () => Navigator.pop(c, a),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      await widget.state.act(Cmd.requestFeature(s.id, pick.artistId));
      if (mounted) {
        showInfo(context, l.featureDone(pick.name, s.title),
            icon: Icons.group_add_rounded);
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Puts the vault song up for free on the audio site (docs K148).
  Future<void> _cloud(SongView s) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.cloudButton),
        content: Text(l.cloudHint),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(l.cloudGo)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.state.act(Cmd.uploadToCloud(s.id));
      if (mounted) {
        showInfo(context, l.cloudDone(s.title), icon: Icons.cloud_rounded);
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Sells the vault song to a rival (docs K143); the song leaves the
  /// vault, so the page closes.
  Future<void> _sell(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = await widget.state.read(Cmd.songBuyers(s.id));
    if (!mounted) return;
    final pick = await showModalBottomSheet<SongBuyerView>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l.sellTitle, style: Theme.of(c).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                  l.sellHint(Songwriting.releaseAfter,
                      (Songwriting.writerShare * 100).round()),
                  style: Theme.of(c).textTheme.bodySmall),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.sellNobody),
              ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final a in list)
                  ListTile(
                    enabled: a.wants,
                    leading: ArtistAvatar(
                        name: a.name, seed: a.artistId, artistId: a.artistId),
                    title: Text(a.name),
                    subtitle: Text(a.wants
                        ? l.featureLine(
                            fmt.genre(a.genre), (a.fame * 100).round())
                        : l.sellNotGoodEnough),
                    trailing: Text(fmt.money(a.feeCents)),
                    onTap: () => Navigator.pop(c, a),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      await widget.state.act(Cmd.sellSong(s.id, pick.artistId));
      if (mounted) {
        showInfo(
            context, l.sellDone(s.title, pick.name, fmt.money(pick.feeCents)),
            icon: Icons.handshake_rounded);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Puts the song on the player's playlist or takes it off (K159).
  Future<void> _ownPlaylist(SongView s) async {
    final l = context.l10n;
    try {
      if (s.onOwnPlaylist) {
        await widget.state.act(Cmd.removeFromPlaylist(s.id));
        if (mounted) showInfo(context, l.ownPlRemoved(s.title));
      } else {
        await widget.state.act(Cmd.addToPlaylist(s.id));
        if (mounted) {
          showInfo(context, l.ownPlAdded(s.title),
              icon: Icons.queue_music_rounded);
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Puts the vault song out as a member's solo single (docs K158); it
  /// leaves the group's vault, so the page closes.
  Future<void> _memberSolo(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = widget.state;
    final members = await career.read(Cmd.members());
    if (!mounted) return;
    final pick = await showModalBottomSheet<MemberView>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l.memberSoloTitle,
                style: Theme.of(c).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child:
                Text(l.memberSoloHint, style: Theme.of(c).textTheme.bodySmall),
          ),
          for (final m in members)
            ListTile(
              leading: ArtistAvatar(name: m.name, seed: m.artistId + m.index),
              title: Text(m.name),
              subtitle: Text(m.artistId < 0
                  ? l.memberFirstSolo
                  : l.memberFans(fmt.compact(m.fans))),
              onTap: () => Navigator.pop(c, m),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      final costs = await career.read(Cmd.memberSoloCosts(pick.index));
      if (!mounted) return;
      final campaign = await pickCampaign(context, career,
          costs: costs,
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.memberSoloCampaign(pick.name),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ));
      if (campaign == null || !mounted) return;
      await career.act(Cmd.releaseMemberSolo(pick.index, s.id, campaign));
      if (mounted) {
        showInfo(context, l.memberSoloDone(s.title, pick.name),
            icon: Icons.person_outline_rounded);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _shootVideo(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final money = widget.state.player.moneyCents;
    final budget = await showModalBottomSheet<VideoBudget>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l.shootVideo, style: Theme.of(c).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.videoHint, style: Theme.of(c).textTheme.bodySmall),
          ),
          for (final b in VideoBudget.values)
            ListTile(
              enabled: b.costCents <= money,
              leading: Icon(switch (b) {
                VideoBudget.low => Icons.videocam_outlined,
                VideoBudget.medium => Icons.movie_creation_outlined,
                VideoBudget.high => Icons.theaters_rounded,
              }),
              title: Text(fmt.videoBudget(b)),
              subtitle: Text(switch (b) {
                VideoBudget.low => l.videoLowHint,
                VideoBudget.medium => l.videoMediumHint,
                VideoBudget.high => l.videoHighHint,
              }),
              trailing: Text(fmt.money(b.costCents)),
              onTap: () => Navigator.pop(c, b),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (budget == null || !mounted) return;
    try {
      await widget.state.act(Cmd.shootVideo(s.id, budget));
      if (mounted) showInfo(context, l.videoShot(s.title));
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Picks another version of the song to put out (docs K92, F26).
  Future<void> _newVersion(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final money = widget.state.player.moneyCents;
    final year = GameTime.yearOf(widget.state.week);
    final recent =
        s.versions.where((x) => widget.state.week - x.$2 < 8).isNotEmpty;
    final v = await showModalBottomSheet<SongVersion>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.newVersion, style: Theme.of(c).textTheme.titleLarge),
          ),
          for (final v in SongVersion.values)
            if (v.onOffer)
              ListTile(
                enabled:
                    v.costCents <= money && !s.versions.any((x) => x.$1 == v),
                leading: Icon(switch (v) {
                  SongVersion.remix => Icons.equalizer_rounded,
                  SongVersion.spedUp => Icons.fast_forward_rounded,
                  SongVersion.slowed => Icons.slow_motion_video_rounded,
                  SongVersion.acapella => Icons.record_voice_over_rounded,
                  SongVersion.instrumental => Icons.piano_rounded,
                  SongVersion.session => Icons.mic_rounded,
                }),
                title: Text(fmt.songVersion(v)),
                subtitle: Text([
                  switch (v.boost(year)) {
                    >= 0.3 => l.waveBig,
                    >= 0.1 => l.waveMid,
                    _ => l.waveSmall,
                  },
                  if (v.trendy && year >= 2020) l.waveTrend,
                  if (recent) l.waveLess,
                ].join(' · ')),
                trailing: Text(fmt.money(v.costCents)),
                onTap: () => Navigator.pop(c, v),
              ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (v == null || !mounted) return;
    try {
      await widget.state.act(Cmd.releaseVersion(s.id, v));
      if (mounted) {
        showInfo(context, l.versionReleased(s.title, fmt.songVersion(v)));
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Buys streams after a warning and a package pick (docs K95).
  Future<void> _buyStreams(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final money = widget.state.player.moneyCents;
    String risk(BotPackage p) {
      final week = p.streams * 0.4 * 0.75;
      final share = week / (s.weekStreams + week);
      return share < 0.2
          ? l.riskLow
          : share < 0.5
              ? l.riskMid
              : l.riskHigh;
    }

    final pkg = await showModalBottomSheet<BotPackage>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l.buyStreams, style: Theme.of(c).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child:
                Text(l.buyStreamsHint, style: Theme.of(c).textTheme.bodySmall),
          ),
          for (final p in BotPackage.values)
            ListTile(
              enabled: p.costCents <= money,
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(l.botPackage(fmt.compact(p.streams))),
              subtitle: Text(risk(p)),
              trailing: Text(fmt.money(p.costCents)),
              onTap: () => Navigator.pop(c, p),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pkg == null || !mounted) return;
    try {
      await widget.state.act(Cmd.buyBots(s.id, pkg));
      if (mounted) {
        showInfo(context, l.botsBought(s.title),
            icon: Icons.smart_toy_outlined);
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _tool(SessionCmd<void> cmd) async {
    try {
      await widget.state.act(cmd);
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Sends the song to independent curators (docs K160).
  Future<void> _curators(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final costs = await widget.state.read(Cmd.curatorCosts());
    if (!mounted) return;
    final money = widget.state.player.moneyCents;
    final pack = await showModalBottomSheet<CuratorPack>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child:
                Text(l.curatorsTitle, style: Theme.of(c).textTheme.titleLarge),
          ),
          for (final k in CuratorPack.values)
            ListTile(
              enabled: costs[k]! <= money,
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(l.curatorsPack(k.curators)),
              trailing: Text(fmt.money(costs[k]!)),
              onTap: () => Navigator.pop(c, k),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pack == null || !mounted) return;
    await _tool(Cmd.submitToCurators(s.id, pack));
  }

  /// What each curator said (docs K160).
  Future<void> _curatorAnswers(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = await widget.state.read(Cmd.curatorAnswers(s.id));
    if (!mounted) return;
    final sorted = [...list]..sort((a, b) {
        if (a.added != b.added) return a.added ? -1 : 1;
        return b.followers.compareTo(a.followers);
      });
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.curatorsAnswersTitle,
                  style: Theme.of(c).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final a in sorted)
                  ListTile(
                    dense: true,
                    leading: Icon(
                        a.added
                            ? Icons.playlist_add_check_rounded
                            : Icons.close_rounded,
                        color: a.added ? AppColors.mint : AppColors.textMuted),
                    title: Text(a.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      l.curatorLine(
                          fmt.genre(a.genre), fmt.compact(a.followers)),
                      switch (a.note) {
                        CuratorNote.added => l.curatorNoteAdded,
                        CuratorNote.notOurSound => l.curatorNoteNotOurSound,
                        CuratorNote.notReady => l.curatorNoteNotReady,
                        CuratorNote.passed => l.curatorNotePassed,
                      },
                    ].join(' · ')),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  /// Picks a physical edition of the single to put out (docs K92, F26).
  Future<void> _newEdition(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final money = widget.state.player.moneyCents;
    final year = GameTime.yearOf(widget.state.week);
    final f = await showModalBottomSheet<SingleFormat>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.newEdition, style: Theme.of(c).textTheme.titleLarge),
          ),
          for (final f in SingleFormat.values)
            ListTile(
              enabled:
                  f.costCents <= money && !s.variants.any((x) => x.$1 == f),
              leading: Icon(switch (f) {
                SingleFormat.cd => Icons.album_rounded,
                SingleFormat.vinyl => Icons.radio_button_checked_rounded,
                SingleFormat.cassette => Icons.cable_rounded,
                SingleFormat.signed => Icons.draw_rounded,
              }),
              title: Text(fmt.singleFormat(f)),
              subtitle: Text(switch (f.appeal(year)) {
                >= 0.9 => l.collectorsHigh,
                >= 0.45 => l.collectorsMid,
                _ => l.collectorsLow,
              }),
              trailing: Text(fmt.money(f.costCents)),
              onTap: () => Navigator.pop(c, f),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (f == null || !mounted) return;
    try {
      await widget.state.act(Cmd.releaseVariant(s.id, f));
      if (mounted) {
        showInfo(context, l.editionReleased(s.title, fmt.singleFormat(f)));
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _scrap(SongView s) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.scrapSongTitle(s.title)),
        content: Text(l.scrapSongBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.scrapSong)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.state.act(Cmd.scrapSong(s.id));
      if (!mounted) return;
      Navigator.pop(context);
      showInfo(context, l.songScrapped(s.title));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _release(SongView s) async {
    if (await releaseSingleFlow(context, widget.state, s)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final s = _song;
    if (s == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    final streams = [for (final h in _history) h.value];
    final sales = [for (final h in _history) h.sales];
    final salesFirst =
        SalesEra.of(GameTime.yearOf(widget.state.week)) != SalesEra.streaming;
    Widget chart(String title, List<double> v) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Section(
            title: title,
            child: LineChart(
                values: v,
                topLabel: fmt.compact(v.reduce((a, b) => a > b ? a : b))),
          ),
        );
    final streamChart = streams.length > 1 && streams.any((x) => x >= 1)
        ? chart(l.weeklyStreams, streams)
        : null;
    final salesChart = sales.length > 1 && sales.any((x) => x >= 1)
        ? chart(l.weeklySingleSales, sales)
        : null;
    final usPos = [
      for (final h in _history) h.positions[Charts.usSongs]?.toDouble()
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReleaseHeader(
            coverSeed: songCoverSeed(s.id, s.coverAlbumId),
            songId: s.id,
            albumId: s.coverAlbumId,
            onCoverTap: s.isPlayer
                ? () => editImage(context, ImageStore.songKey(s.id))
                : null,
            title: s.title,
            subtitle: '${s.artistName} · ${fmt.songStatus(s)}',
            trailing: s.isPlayer ? GradeTag(fmt.songGrade(s)) : null,
          ),
          if (!s.isPlayer)
            ArtistLink(
                artistId: s.artistId, name: s.artistName, state: widget.state),
          if (s.usSingleUnits >= Certification.gold.units) ...[
            const SizedBox(height: 10),
            Center(child: CertificationTag(units: s.usSingleUnits)),
          ],
          const SizedBox(height: 14),
          Section(
            title: fmt.genres(s.genres),
            icon: Icons.sell_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (s.releasedWeek >= 0)
                        l.releasedOn(fmt.week(s.releasedWeek)),
                      if (s.releasedWeek >= 0) fmt.campaign(s.campaign),
                      if (s.isSingle && s.releasedWeek >= 0)
                        fmt.radioPush(s.radioPush),
                      if (s.playlistAdd != PlaylistAdd.none) l.onPlaylist,
                    ].join(' · '),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                  // On the radio (docs K128).
                  if (s.isSingle &&
                      s.releasedWeek >= 0 &&
                      s.radioSpins >= 1) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(radioIcon(s.radioPush),
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            l.radioWeekLine(
                                fmt.compact(s.radioSpins), s.radioStations),
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ]),
                  ],
                  // The format it is worked to (docs K134).
                  if (s.isSingle && s.releasedWeek >= 0) ...[
                    const SizedBox(height: 8),
                    Text(l.radioFormatLine(fmt.radioFormat(s.radioFormat)),
                        style: TextStyle(color: AppColors.textMuted)),
                  ],
                  if (s.radioFormatOptions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(l.radioFormatHint,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final e in s.radioFormatOptions.entries)
                        ChoiceChip(
                          label: Text(l.radioFormatOption(
                              fmt.radioFormat(e.key),
                              (e.value.$1 * 100).round(),
                              (e.value.$2 * 100).round())),
                          selected: e.key == s.radioFormat,
                          onSelected: (_) =>
                              _tool(Cmd.setRadioFormat(s.id, e.key)),
                        ),
                    ]),
                  ],
                  if (s.radioUpgradeCosts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(l.radioUpgradeHint,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final e in s.radioUpgradeCosts.entries)
                        ActionChip(
                          avatar: Icon(radioIcon(e.key), size: 16),
                          label: Text(
                              '${fmt.radioPush(e.key)} · ${fmt.money(e.value)}'),
                          onPressed: () => _tool(Cmd.upgradeRadio(s.id, e.key)),
                        ),
                    ]),
                  ],
                  // A leak (docs K140).
                  if (s.inVault && s.leakedWeek >= 0) ...[
                    const SizedBox(height: 12),
                    Tag(l.leakedTag,
                        icon: Icons.water_drop_rounded, color: AppColors.coral),
                    const SizedBox(height: 6),
                    Text(
                        s.canAnswerLeak
                            ? l.leakAnswerHint(
                                fmt.week(s.leakedWeek + Leaks.answerWeeks))
                            : l.leakLateHint,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                  ],
                  if (s.scheduledSingleWeek >= 0) ...[
                    const SizedBox(height: 12),
                    Tag(l.scheduledSingleTag(fmt.week(s.scheduledSingleWeek)),
                        icon: Icons.event_rounded),
                  ] else if (s.isPlayer &&
                      (s.inVault ||
                          s.cloudOnly ||
                          (!s.isSingle && s.albumId >= 0))) ...[
                    const SizedBox(height: 12),
                    GradientButton(
                      onPressed: () => _release(s),
                      icon: Icons.music_note_rounded,
                      label: l.releaseAsSingle,
                    ),
                  ],
                  if (s.isPlayer && s.video == null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _shootVideo(s),
                      icon: const Icon(Icons.videocam_rounded),
                      label: Text(l.shootVideo),
                    ),
                  ] else if (s.video != null) ...[
                    const SizedBox(height: 8),
                    Tag(l.hasVideo(fmt.videoBudget(s.video!)),
                        icon: Icons.videocam_rounded),
                  ],
                  // A sleeper hit in the making (docs K108).
                  if (s.catchingOn) ...[
                    const SizedBox(height: 8),
                    Tag(l.tagWordOfMouth,
                        icon: Icons.trending_up_rounded, color: AppColors.mint),
                  ],
                  // A rival on the song (docs K117).
                  if (s.isPlayer &&
                      (s.inVault || s.releasedWeek >= 0) &&
                      s.featuredArtistIds.length < 2) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _feature(s),
                      icon: const Icon(Icons.group_add_rounded),
                      label: Text(
                          s.inVault ? l.featureButton : l.remixFeatureButton),
                    ),
                  ],
                  // A snippet test on the short-video app (docs K152).
                  if (s.snippetReaction case final r?) ...[
                    const SizedBox(height: 8),
                    Tag(l.snippetTag(fmt.snippetReaction(r), s.snippetScore),
                        icon: Icons.music_video_outlined,
                        color: switch (r) {
                          SnippetReaction.hot => AppColors.mint,
                          SnippetReaction.good => AppColors.sky,
                          SnippetReaction.lukewarm => AppColors.peach,
                          SnippetReaction.cold => AppColors.coral,
                        }),
                  ],
                  if (s.canSnippet)
                    TextButton.icon(
                      onPressed: () => _tool(Cmd.teaseSnippet(s.id)),
                      icon: const Icon(Icons.music_video_outlined),
                      label: Text(l.snippetButton(Snippets.energy.round())),
                    ),
                  if (s.canSnippet)
                    Text(l.snippetHint(Snippets.waitWeeks),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                  // A free upload to the audio site (docs K148).
                  if (s.cloudOnly) ...[
                    const SizedBox(height: 8),
                    Tag(l.cloudOnlyTag(fmt.compact(s.cloudPlays)),
                        icon: Icons.cloud_rounded,
                        color: platformColor(MusicPlatform.noiseCloud)),
                    const SizedBox(height: 4),
                    Text(l.cloudOfficialHint,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                  ] else if (s.cloudWeek >= 0 && s.cloudPlays >= 1) ...[
                    const SizedBox(height: 8),
                    Tag(l.cloudFromTag(fmt.compact(s.cloudPlays)),
                        icon: Icons.cloud_done_rounded,
                        color: platformColor(MusicPlatform.noiseCloud)),
                  ],
                  // The player's own playlist (docs K159).
                  if (s.onOwnPlaylist || s.canOwnPlaylist)
                    TextButton.icon(
                      onPressed: () => _ownPlaylist(s),
                      icon: Icon(s.onOwnPlaylist
                          ? Icons.playlist_remove_rounded
                          : Icons.playlist_add_rounded),
                      label: Text(
                          s.onOwnPlaylist ? l.ownPlSongRemove : l.ownPlSongAdd),
                    ),
                  if (s.canCloud)
                    TextButton.icon(
                      onPressed: () => _cloud(s),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(l.cloudButton),
                    ),
                  // Writing for others (docs K143).
                  if (s.isPlayer &&
                      s.inVault &&
                      s.rerecordOf < 0 &&
                      s.scheduledSingleWeek < 0 &&
                      s.scheduledAlbumWeek < 0)
                    TextButton.icon(
                      onPressed: () => _sell(s),
                      icon: const Icon(Icons.handshake_outlined),
                      label: Text(l.sellButton),
                    ),
                  // A group member's solo single (docs K158).
                  if (s.isPlayer &&
                      s.inVault &&
                      widget.state.player.kind.isGroup &&
                      s.rerecordOf < 0 &&
                      s.scheduledSingleWeek < 0 &&
                      s.scheduledAlbumWeek < 0)
                    TextButton.icon(
                      onPressed: () => _memberSolo(s),
                      icon: const Icon(Icons.person_outline_rounded),
                      label: Text(l.memberSoloButton),
                    ),
                  if (s.credit == ChartCredit.imprint) ...[
                    const SizedBox(height: 8),
                    Tag(l.creditImprint,
                        icon: Icons.business_rounded, color: AppColors.lilac),
                  ] else if (s.credit != ChartCredit.none) ...[
                    const SizedBox(height: 8),
                    Tag(
                        s.credit == ChartCredit.member
                            ? l.memberSoloTag(fmt.money(s.revenueCents))
                            : l.guestTag(fmt.money(s.guestCents.round())),
                        icon: s.credit == ChartCredit.member
                            ? Icons.person_outline_rounded
                            : Icons.mic_external_on_outlined,
                        color: AppColors.lilac),
                  ],
                  if (s.writerName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Tag(
                        s.writtenByPlayer
                            ? l.writtenByYou(fmt.money(s.writerCents.round()))
                            : l.writtenBy(s.writerName),
                        icon: Icons.edit_note_rounded,
                        color: AppColors.mint),
                  ],
                  if (s.isPlayer &&
                      s.inVault &&
                      s.scheduledSingleWeek < 0 &&
                      s.scheduledAlbumWeek < 0)
                    TextButton.icon(
                      onPressed: () => _scrap(s),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.coral),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l.scrapSong),
                    ),
                ]),
          ),
          // Record money by source (docs K145).
          if (_income case final income? when income.total >= 100) ...[
            const SizedBox(height: 12),
            IncomeCard(income: income, title: l.incomeSongTitle),
          ],
          if (s.isPlayer && s.releasedWeek >= 0) ...[
            const SizedBox(height: 12),
            Section(
              title: l.versionsSection,
              icon: Icons.library_add_rounded,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.versions.isEmpty && s.variants.isEmpty)
                      Text(l.versionsHint,
                          style: TextStyle(color: AppColors.textMuted))
                    else
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final (v, wk) in s.versions)
                          Tag('${fmt.songVersion(v)} · ${fmt.weekInMonth(wk)}',
                              icon: Icons.graphic_eq_rounded),
                        for (final (f, wk) in s.variants)
                          Tag('${fmt.singleFormat(f)} · ${fmt.weekInMonth(wk)}',
                              icon: Icons.album_rounded, color: AppColors.gold),
                      ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: () => _newVersion(s),
                        icon: const Icon(Icons.graphic_eq_rounded),
                        label: Text(l.newVersion),
                      ),
                      if (s.isSingle)
                        OutlinedButton.icon(
                          onPressed: () => _newEdition(s),
                          icon: const Icon(Icons.album_rounded),
                          label: Text(l.newEdition),
                        ),
                    ]),
                    // Versions in other languages (docs K155).
                    if (s.languageVersions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final v in s.languageVersions)
                          Tag(fmt.languageVersion(v),
                              icon: Icons.translate_rounded,
                              color: AppColors.sky),
                      ]),
                    ],
                    if (s.languageOptions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                          l.languageHint(fmt.money(Languages.costCents),
                              Languages.energy.round()),
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final v in s.languageOptions)
                          ActionChip(
                            avatar:
                                const Icon(Icons.translate_rounded, size: 16),
                            label: Text(fmt.languageVersion(v)),
                            onPressed: () =>
                                _tool(Cmd.releaseLanguageVersion(s.id, v)),
                          ),
                      ]),
                    ],
                  ]),
            ),
          ],
          if (s.isPlayer &&
              (s.releasedWeek >= 0 || s.inVault) &&
              (s.streamingOpen || s.autoplayOpen)) ...[
            const SizedBox(height: 12),
            Section(
              title: l.streamingSection,
              icon: Icons.graphic_eq_rounded,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (s.holiday)
                        Tag(l.holidayTag,
                            icon: Icons.ac_unit_rounded, color: AppColors.sky),
                      if (s.leakHurts)
                        Tag(l.leakedTag,
                            icon: Icons.water_drop_outlined,
                            color: AppColors.coral),
                      if (s.liveOf >= 0)
                        Tag(l.liveTag,
                            icon: Icons.mic_external_on_outlined,
                            color: AppColors.lilac),
                      if (s.rerecordOf >= 0)
                        Tag(l.rerecordTag,
                            icon: Icons.replay_rounded, color: AppColors.peach),
                      if (s.masterShare < 1)
                        Tag(l.mastersTag((s.masterShare * 100).round()),
                            icon: Icons.copyright_rounded,
                            color: AppColors.textMuted),
                      if (s.botStatus == BotStatus.running &&
                          s.botWeeksLeft > 0)
                        Tag(l.botsRunning(s.botWeeksLeft),
                            icon: Icons.smart_toy_outlined,
                            color: AppColors.peach),
                      if (s.botStatus == BotStatus.caught)
                        Tag(l.botsCaughtTag(fmt.compact(s.botRemoved)),
                            icon: Icons.gpp_bad_rounded,
                            color: AppColors.coral),
                      if (s.chartFiltered)
                        Tag(l.chartFilteredTag,
                            icon: Icons.filter_alt_rounded,
                            color: AppColors.coral),
                      if (s.pitchWeek >= 0 && s.pitchLanded)
                        Tag(l.pitchLandedTag,
                            icon: Icons.playlist_add_check_rounded,
                            color: AppColors.mint)
                      else if (s.pitchWeek >= 0 &&
                          (s.pitchAnswerWeek < 0 ||
                              s.pitchAnswerWeek >= widget.state.week))
                        Tag(
                            s.pitchAnswerWeek < 0
                                ? l.pitchPendingRelease
                                : l.pitchPending,
                            icon: Icons.schedule_rounded)
                      else if (s.pitchWeek >= 0)
                        Tag(l.pitchDeclinedTag,
                            icon: Icons.playlist_remove_rounded),
                      // The algorithm (docs K119).
                      if (s.inDiscover)
                        Tag(l.tagDiscover,
                            icon: Icons.auto_awesome_rounded,
                            color: AppColors.mint),
                      if (s.inReleaseRadar)
                        Tag(l.tagReleaseRadar,
                            icon: Icons.radar_rounded, color: AppColors.mint),
                    ]),
                    // Buying a loose single's master back (docs K162).
                    if (s.masterBuyCents case final price?)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: widget.state.busy
                              ? null
                              : () => buyMastersFlow(
                                  context,
                                  widget.state,
                                  s.title,
                                  price,
                                  Cmd.buySongMaster(s.id),
                                  _load),
                          icon: const Icon(Icons.copyright_rounded),
                          label: Text(l.mastersBuyButton(fmt.money(price))),
                        ),
                      ),
                    // On the editorial playlists (docs K125).
                    if (_playlists.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(l.edOnPlaylists,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final pl in _playlists)
                          ActionChip(
                            avatar: Container(
                                width: 14,
                                height: 14,
                                color: editorialColor(pl.playlist)),
                            label: Text(
                                '${pl.playlist.displayName} #${pl.position}'),
                            onPressed: () => pushInCareer(
                                context, EditorialPage(playlist: pl.playlist)),
                          ),
                      ]),
                    ],
                    if (s.canPitch) ...[
                      const SizedBox(height: 8),
                      Text(l.pitchHint,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _tool(Cmd.pitchSong(s.id)),
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: Text(l.pitchSong),
                        ),
                      ),
                    ],
                    // Independent curators (docs K160).
                    if (s.curatorWeek >= 0) ...[
                      const SizedBox(height: 10),
                      if (!s.curatorAnswered)
                        Tag(l.curatorsPending(s.curatorSent),
                            icon: Icons.schedule_rounded)
                      else ...[
                        Text(
                            l.curatorsResult(s.curatorAdds, s.curatorSent,
                                fmt.compact(s.curatorReach)),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        if (s.curatorStreams >= 1)
                          Text(l.curatorsPlays(fmt.compact(s.curatorStreams)),
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _curatorAnswers(s),
                            icon: const Icon(Icons.forum_outlined),
                            label: Text(l.curatorsSeeAnswers),
                          ),
                        ),
                      ],
                    ],
                    if (s.canCurators) ...[
                      const SizedBox(height: 8),
                      Text(l.curatorsHint,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _curators(s),
                          icon: const Icon(Icons.queue_music_rounded),
                          label: Text(l.curatorsButton),
                        ),
                      ),
                    ],
                    // Creators on the short-video app (docs K131).
                    if (s.creatorWeek >= 0) ...[
                      const SizedBox(height: 10),
                      Text(
                          switch (s.creatorResult) {
                            CreatorResult.running => l.creatorsRunning(
                                s.creatorTier.creators,
                                widget.state.week - s.creatorWeek + 1,
                                CreatorCampaign.weeks),
                            CreatorResult.caughtOn => l.creatorsCaughtOn,
                            CreatorResult.flopped => l.creatorsFlopped,
                          },
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: s.creatorResult == CreatorResult.caughtOn
                                  ? AppColors.mint
                                  : null)),
                    ] else if (s.creatorCosts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(l.creatorsTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(l.creatorsHint,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final e in s.creatorCosts.entries)
                          ActionChip(
                            avatar:
                                const Icon(Icons.videocam_outlined, size: 16),
                            label: Text(
                                '${l.creatorsCount(e.key.creators)} · ${fmt.money(e.value)}'),
                            onPressed: e.value > widget.state.player.moneyCents
                                ? null
                                : () => _tool(Cmd.runCreators(s.id, e.key)),
                          ),
                      ]),
                    ],
                    // The app's Marquee and Showcase (docs K147).
                    if (s.marqueeCostCents case final cost?) ...[
                      const SizedBox(height: 10),
                      Text(l.marqueeTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(l.marqueeHint(StreamingTools.marqueeWeeks),
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      ActionChip(
                        avatar: const Icon(Icons.campaign_outlined, size: 16),
                        label: Text('${l.marqueeRun} · ${fmt.money(cost)}'),
                        onPressed: cost > widget.state.player.moneyCents
                            ? null
                            : () => _tool(Cmd.runMarquee(s.id)),
                      ),
                    ] else if (s.marqueeWeek >= 0) ...[
                      const SizedBox(height: 10),
                      Text(l.marqueeRan(fmt.week(s.marqueeWeek)),
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                    if (s.showcaseCostCents case final cost?) ...[
                      const SizedBox(height: 10),
                      Text(l.showcaseTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(l.showcaseHint,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      ActionChip(
                        avatar: const Icon(Icons.history_rounded, size: 16),
                        label: Text('${l.showcaseRun} · ${fmt.money(cost)}'),
                        onPressed: cost > widget.state.player.moneyCents
                            ? null
                            : () => _tool(Cmd.runShowcase(s.id)),
                      ),
                    ],
                    if (s.autoplayOpen) ...[
                      const SizedBox(height: 10),
                      AutoplayLevelPicker(
                          value: s.autoplayLevel,
                          onChanged: (a) =>
                              _tool(Cmd.setAutoplayLevel(s.id, a))),
                    ],
                    if (s.preSaves >= 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l.preSavesHint(fmt.compact(s.preSaves)),
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                      ),
                    // Where the listening came from (docs K120).
                    if (s.streamSources.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SourcesBar(shares: s.streamSources),
                      const SizedBox(height: 8),
                    ],
                    if (s.autoplayOpen)
                      Text(
                          l.skipRateLine((s.skipRate * 100).round(),
                              (s.autoplayLift * 100).round()),
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                    if (s.streamingOpen &&
                        s.releasedWeek >= 0 &&
                        s.botStatus != BotStatus.caught &&
                        s.botWeeksLeft == 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.coral),
                          onPressed: () => _buyStreams(s),
                          icon: const Icon(Icons.smart_toy_outlined),
                          label: Text(l.buyStreams),
                        ),
                      ),
                  ]),
            ),
          ],
          if (!s.inVault) ...[
            const SizedBox(height: 12),
            _SongNumbers(song: s, salesFirst: salesFirst),
            if (s.isPlayer) ...[
              const SizedBox(height: 12),
              ProfitCard(
                revenueCents: s.revenueCents,
                costsCents: s.costsCents,
                sold: s.singleUnits,
                globalPeak: s.charts
                    .where((c) => c.chartId == Charts.globalSongs)
                    .firstOrNull
                    ?.peak,
              ),
            ],
            if (s.isPlayer &&
                (s.campaignCostCents > 0 || s.campaignReturnCents > 0)) ...[
              const SizedBox(height: 12),
              CampaignResult(
                  campaign: s.campaign,
                  costCents: s.campaignCostCents,
                  returnCents: s.campaignReturnCents),
            ],
            const SizedBox(height: 12),
            _ChartRecords(records: s.charts),
            const SizedBox(height: 12),
            Section(
              title: l.chartRunTitle,
              icon: Icons.timeline_rounded,
              child: ChartRunTable(run: _run),
            ),
            ...[
              if (salesFirst) salesChart,
              streamChart,
              if (!salesFirst) salesChart,
            ].whereType<Widget>(),
            if (usPos.whereType<double>().length > 1) ...[
              const SizedBox(height: 12),
              Section(
                title: l.positionOn(fmt.chart(Charts.usSongs)),
                child: LineChart(
                  values: usPos,
                  invert: true,
                  color: Theme.of(context).colorScheme.tertiary,
                  topLabel:
                      '#${usPos.whereType<double>().reduce((a, b) => a < b ? a : b).round()}',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The song's numbers (F46): four headline figures for the era, where its
/// streams come from as one bar, the rest folded away.
class _SongNumbers extends StatefulWidget {
  const _SongNumbers({required this.song, required this.salesFirst});
  final SongView song;
  final bool salesFirst;

  @override
  State<_SongNumbers> createState() => _SongNumbersState();
}

class _SongNumbersState extends State<_SongNumbers> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final s = widget.song;
    final streams = s.lifetimeStreams.total;
    final hasStreams = streams >= 1;
    StatTile tile(String label, double v) =>
        StatTile(label: label, value: fmt.compact(v));
    final head = widget.salesFirst || !hasStreams
        ? [
            tile(l.singleSales, s.singleSales),
            tile(l.radioAudience, s.lifetimeRadio),
            if (hasStreams) tile(l.streams, streams),
            tile(l.singleUnits, s.singleUnits),
          ]
        : [
            tile(l.streams, streams),
            tile(l.thisWeekStreams, s.weekStreams),
            tile(l.singleUnits, s.singleUnits),
            tile(l.singleSales, s.singleSales),
          ];
    Widget row(String label, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child:
                    Text(label, style: TextStyle(color: AppColors.textMuted))),
            Text(fmt.compact(v),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        );
    final regionColors = [AppColors.lilac, AppColors.pink, AppColors.sky];
    return Section(
      title: l.numbers,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatGrid(tiles: head),
        if (hasStreams) ...[
          const SizedBox(height: 18),
          Text(l.streamsByRegion,
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in Region.values)
                      if (s.lifetimeStreams[r] > 0)
                        Expanded(
                            flex: (s.lifetimeStreams[r] / streams * 1000)
                                .round()
                                .clamp(1, 1000),
                            child:
                                ColoredBox(color: regionColors[r.index % 3])),
                  ]),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (final r in Region.values)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: regionColors[r.index % 3],
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                    '${fmt.region(r)} '
                    '${(s.lifetimeStreams[r] / streams * 100).round()}%',
                    style: const TextStyle(fontSize: 13)),
              ]),
          ]),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _more = !_more),
            icon: Icon(
                _more ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_more ? l.fewerNumbers : l.moreNumbers),
          ),
        ),
        if (_more) ...[
          if (hasStreams)
            for (final r in Region.values)
              row(fmt.region(r), s.lifetimeStreams[r]),
          row(l.downloads, s.lifetimeDownloads),
          if (s.lifetimePhysical >= 1) row(l.cdSingles, s.lifetimePhysical),
          if (!widget.salesFirst && hasStreams)
            row(l.radioAudience, s.lifetimeRadio),
          if (widget.salesFirst && hasStreams)
            row(l.thisWeekStreams, s.weekStreams),
        ],
      ]),
    );
  }
}

/// Peak, weeks and #1 weeks per chart.
class _ChartRecords extends StatelessWidget {
  const _ChartRecords({required this.records});
  final List<ChartRecord> records;

  @override
  Widget build(BuildContext context) => ChartRecords(records: records);
}

class ChartRecords extends StatelessWidget {
  const ChartRecords({super.key, required this.records});
  final List<ChartRecord> records;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Section(
      title: l.chartHistory,
      child: records.isEmpty
          ? EmptyNote(l.neverCharted)
          : Column(children: [
              for (final r in records)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: PosBadge(r.peak, highlight: true),
                  title: Text(fmt.chart(r.chartId)),
                  subtitle: Text(l.chartRecordLine(
                      r.debutPos, r.weeksOn, r.weeksAtNo1, r.lastPos)),
                ),
            ]),
    );
  }
}

/// Big cover with title and artist, centered (detail pages).
class ReleaseHeader extends StatelessWidget {
  const ReleaseHeader(
      {super.key,
      required this.coverSeed,
      required this.title,
      required this.subtitle,
      this.trailing,
      this.songId,
      this.albumId,
      this.onCoverTap});
  final int coverSeed;
  final int? songId;
  final int? albumId;

  /// Opens the cover picker (the player's own releases).
  final VoidCallback? onCoverTap;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppShape.r(18)),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 30, offset: Offset(0, 12), color: Colors.black54),
            ],
          ),
          child: GestureDetector(
            onTap: onCoverTap,
            child: Stack(children: [
              CoverArt(
                  seed: coverSeed,
                  size: 190,
                  radius: 18,
                  songId: songId,
                  albumId: albumId),
              if (onCoverTap != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_camera_outlined,
                        color: Colors.white, size: 18),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      ]);
}

/// Last week's listening by source, Spotify for Artists style (K120).
class _SourcesBar extends StatelessWidget {
  const _SourcesBar({required this.shares});
  final List<double> shares;

  static const _colors = [
    Color(0xFF4B63FF),
    Color(0xFF8E9BFF),
    Color(0xFF2BD97C),
    Color(0xFFF5B83D),
    Color(0xFFFF5A5F),
    Color(0xFF9E9E9E),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = [
      l.sourceFans,
      l.sourceLibrary,
      l.sourceAlgorithm,
      l.sourceEditorial,
      l.sourceViral,
      l.sourcePromotion,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.sourcesTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 12,
          child: Row(children: [
            for (var i = 0; i < shares.length; i++)
              if (shares[i] > 0.005)
                Expanded(
                    flex: (shares[i] * 1000).round(),
                    child: ColoredBox(color: _colors[i])),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 12, runSpacing: 4, children: [
        for (var i = 0; i < shares.length; i++)
          if (shares[i] >= 0.01)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, color: _colors[i]),
              const SizedBox(width: 4),
              Text('${names[i]} ${(shares[i] * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
      ]),
    ]);
  }
}
