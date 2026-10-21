import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';
import 'package:intl/intl.dart';

import '../../core/commands.dart';
import '../../core/images.dart';
import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';
import '../song_detail_screen.dart';
import 'album_page.dart';
import 'this_is_page.dart';
import '../game_shell.dart';

/// Streamify artist page, laid out like a big streaming app's: large header,
/// monthly listeners, popular tracks with play counts, discography, about.
class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId});
  final int artistId;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  ArtistPageView? _page;
  bool _showAll = false;

  /// The player's Artist Pick (docs K185; null on others' pages).
  PickView? _pick;

  /// The artist's This Is list (docs K189).
  ThisIsView? _thisIs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final career = context.careerRead;
    final page = await career.read(Cmd.artistPage(widget.artistId));
    final pick = widget.artistId == career.player.id
        ? await career.read(Cmd.artistPick())
        : null;
    final thisIs = await career.read(Cmd.thisIs(widget.artistId));
    if (mounted) {
      setState(() {
        _page = page;
        _pick = pick;
        _thisIs = thisIs;
      });
    }
  }

  Future<void> _choosePick(PickView v) async {
    final l = context.l10n;
    final career = context.careerRead;
    final picked = await showModalBottomSheet<(PickKind, int)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: StreamifyColors.surface,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (c, scroll) => ListView(controller: scroll, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l.pickTitleStreamify,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.pickChooseHint,
                style: const TextStyle(color: StreamifyColors.muted)),
          ),
          for (final (kind, label, items) in [
            (PickKind.upcoming, l.pickUpcoming, v.upcoming),
            (PickKind.album, l.pickAlbums, v.albums),
            (PickKind.song, l.pickSongs, v.songs),
          ])
            if (items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              for (final x in items)
                ListTile(
                  title: Text(x.title),
                  trailing: v.current?.kind == kind && v.current?.id == x.id
                      ? const Icon(Icons.push_pin_rounded,
                          color: StreamifyColors.accent)
                      : null,
                  onTap: () => Navigator.pop(c, (kind, x.id)),
                ),
            ],
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await career.act(Cmd.setArtistPick(picked.$1, picked.$2));
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _pickTile(PickView v) {
    final l = context.l10n;
    final p = v.current;
    return InkWell(
      onTap: () => _choosePick(v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: StreamifyColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(
              p?.kind == PickKind.upcoming
                  ? Icons.hourglass_top_rounded
                  : Icons.push_pin_rounded,
              color: StreamifyColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  p?.kind == PickKind.upcoming
                      ? l.pickCountdown
                      : l.pickTitleStreamify,
                  style: const TextStyle(
                      color: StreamifyColors.muted, fontSize: 12.5)),
              Text(p == null ? l.pickNone : v.title,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (p != null && p.kind != PickKind.upcoming)
                Text(l.pickFresh((v.freshness * 100).round()),
                    style: const TextStyle(
                        color: StreamifyColors.muted, fontSize: 12)),
            ]),
          ),
          Text(l.pickChange,
              style: const TextStyle(
                  color: StreamifyColors.accent, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: StreamifyColors.bg,
        colorScheme: Theme.of(context)
            .colorScheme
            .copyWith(primary: StreamifyColors.accent),
      ),
      child: Scaffold(
        backgroundColor: StreamifyColors.bg,
        body: page == null
            ? const Center(
                child: CircularProgressIndicator(color: StreamifyColors.accent))
            : _content(context, page),
      ),
    );
  }

  Widget _thisIsTile(BuildContext context, ThisIsView t, int seed) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.thisIsFeaturing,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () =>
              pushInCareer(context, ThisIsPage(view: t, seed: seed)),
          child: Row(children: [
            ThisIsCover(
                name: t.artistName, seed: seed, size: 96, locked: !t.made),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.thisIsTitle(t.artistName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                        t.made
                            ? l.thisIsSongs(t.songs.length)
                            : l.thisIsLockedShort,
                        style: const TextStyle(
                            color: StreamifyColors.muted, fontSize: 13)),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: StreamifyColors.muted),
          ]),
        ),
      ]),
    );
  }

  Widget _content(BuildContext context, ArtistPageView page) {
    final l = context.l10n;
    final fmt = context.fmt;
    final a = page.artist;
    final plays = NumberFormat.decimalPattern(l.localeName);
    final popular = page.popular.take(_showAll ? 10 : 5).toList();
    final career = context.careerRead;
    final releases = <(String, int, String, VoidCallback?, int?, int)>[
      for (final al in page.albums)
        (
          al.title,
          albumCoverSeed(al.id),
          '${GameTime.yearOf(al.releaseWeek)} · ${fmt.albumType(al.type)}',
          () => pushInCareer(context, StreamifyAlbumPage(albumId: al.id)),
          null,
          al.id,
        ),
      for (final s in page.singles)
        (
          s.title,
          songCoverSeed(s.id, s.coverAlbumId),
          '${GameTime.yearOf(s.singleWeek)} · ${fmt.albumType(AlbumType.single)}',
          a.isPlayer
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          SongDetailScreen(songId: s.id, state: career)))
              : null,
          s.id,
          s.coverAlbumId,
        ),
    ];
    final (c1, c2) = streamifyHeaderColors(a.id);
    final regions = a.lifetimeStreams;

    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 300,
        pinned: true,
        backgroundColor: c2,
        foregroundColor: Colors.white,
        flexibleSpace: LayoutBuilder(builder: (context, box) {
          // 0 = collapsed bar, 1 = fully open header. The name grows from
          // the bar's title to a big left-aligned headline under the badge.
          final top = MediaQuery.paddingOf(context).top;
          final t =
              ((box.maxHeight - top - kToolbarHeight) / (300 - kToolbarHeight))
                  .clamp(0.0, 1.0);
          return Stack(fit: StackFit.expand, children: [
            FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c1, c2],
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0.7, -0.2),
                  child: Opacity(
                    opacity: 0.9,
                    child: ArtistAvatar(
                        name: a.name,
                        seed: a.id,
                        size: 170,
                        artistId: a.id,
                        photo: ArtistPhoto.streamify),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC121212)],
                      stops: [0.45, 1],
                    ),
                  ),
                ),
                if (a.fame > 0.25)
                  Positioned(
                    left: 16,
                    bottom: 70,
                    child: Row(children: [
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF4CB3FF), size: 20),
                      const SizedBox(width: 6),
                      Text(l.verifiedArtist,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ),
            Positioned(
              left: 16 + 40 * (1 - t),
              right: 16,
              bottom: 14,
              child: Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 20 + 20 * t,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ]);
        }),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  l.monthlyListeners(
                      plays.format(page.monthlyListeners.round())),
                  style: const TextStyle(
                      color: StreamifyColors.muted,
                      fontWeight: FontWeight.w600)),
              // The player's high (docs K156).
              if (page.peakListeners >= 1)
                Text(l.peakListeners(plays.format(page.peakListeners.round())),
                    style: const TextStyle(
                        color: StreamifyColors.muted, fontSize: 12.5)),
              // Like the apps: a place in the world for the top 500 (K113).
              if (page.worldRank > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: StreamifyColors.accent,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(l.worldRank(page.worldRank),
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w800)),
                ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: StreamifyColors.muted),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {},
                  child: Text(a.isPlayer ? l.you : l.follow),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.more_horiz_rounded,
                    color: StreamifyColors.muted),
                const Spacer(),
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                      color: StreamifyColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.black, size: 34),
                ),
              ]),
              const SizedBox(height: 18),
              // The player's pinned release (docs K185).
              if (_pick case final v? when v.open) _pickTile(v),
              Text(l.popular,
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      if (popular.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.noReleasesYet,
                style: const TextStyle(color: StreamifyColors.muted)),
          ),
        ),
      SliverList.builder(
        itemCount: popular.length,
        itemBuilder: (context, i) {
          final s = popular[i];
          return InkWell(
            onTap: a.isPlayer
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            SongDetailScreen(songId: s.id, state: career)))
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: StreamifyColors.muted,
                          fontWeight: FontWeight.w600)),
                ),
                CoverArt(
                    seed: songCoverSeed(s.id, s.coverAlbumId),
                    size: 46,
                    radius: 2,
                    songId: s.id,
                    albumId: s.coverAlbumId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text(
                            plays.format(
                                (s.lifetimeStreams.total * Streamify.share)
                                    .round()),
                            style: const TextStyle(
                                color: StreamifyColors.muted, fontSize: 13)),
                      ]),
                ),
                const Icon(Icons.more_vert_rounded,
                    color: StreamifyColors.muted, size: 20),
              ]),
            ),
          );
        },
      ),
      if (page.popular.length > 5)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: StreamifyColors.muted),
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(_showAll ? l.showLess : l.seeMore),
              ),
            ),
          ),
        ),
      if (releases.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Text(l.discography,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: releases.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final (title, seed, sub, onTap, songId, albumId) = releases[i];
                return InkWell(
                  onTap: onTap,
                  child: SizedBox(
                    width: 146,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CoverArt(
                              seed: seed,
                              size: 146,
                              radius: 4,
                              songId: songId,
                              albumId: albumId),
                          const SizedBox(height: 8),
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(sub,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: StreamifyColors.muted,
                                  fontSize: 12.5)),
                        ]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
      // The editors' This Is list (docs K189).
      if (_thisIs case final t? when t.open && (t.made || t.isPlayer))
        SliverToBoxAdapter(child: _thisIsTile(context, t, a.id)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Container(
            decoration: BoxDecoration(
              color: StreamifyColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.about,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(
                  '${fmt.kind(a.kind)} · ${fmt.genre(a.genre)} · ${fmt.home(a.home)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (a.members.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(a.members.join(', '),
                    style: const TextStyle(color: StreamifyColors.muted)),
              ],
              const SizedBox(height: 14),
              Text(l.followersValue(fmt.compact(page.followers)),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              // Monthly listeners over half a year (docs K130).
              if (page.listenerHistory.length > 2) ...[
                const SizedBox(height: 14),
                Text(l.listenersHistory,
                    style: const TextStyle(
                        color: StreamifyColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                LineChart(
                  values: page.listenerHistory,
                  height: 110,
                  color: StreamifyColors.accent,
                  topLabel: fmt.compact(
                      page.listenerHistory.reduce((a, b) => a > b ? a : b)),
                  bottomLabel: l.weeksAgo(page.listenerHistory.length),
                ),
              ],
              // The cities with the most listeners (docs K130).
              if (page.topCities.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(l.topCities,
                    style: const TextStyle(
                        color: StreamifyColors.muted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final c in page.topCities)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      Text(l.cityListeners(plays.format(c.listeners.round())),
                          style: const TextStyle(color: StreamifyColors.muted)),
                    ]),
                  ),
              ],
              const SizedBox(height: 14),
              Text(l.whereListen,
                  style: const TextStyle(
                      color: StreamifyColors.muted,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final r in Region.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(fmt.region(r))),
                    Text(
                        regions.total <= 0
                            ? '–'
                            : fmt.percent(regions[r] / regions.total),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// Header colors of an artist page, taken from the avatar like Streamify
/// takes them from the artist's picture.
(Color, Color) streamifyHeaderColors(int seed) {
  final c = avatarColor(seed);
  return (Color.lerp(c, Colors.black, 0.3)!, Color.lerp(c, Colors.black, 0.8)!);
}

/// Small helper so other screens can show Streamify play counts.
String streamifyPlays(BuildContext context, double allPlatformStreams) =>
    NumberFormat.decimalPattern(context.l10n.localeName)
        .format((allPlatformStreams * Streamify.share).round());
