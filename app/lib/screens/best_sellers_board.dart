import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'game_shell.dart' show pushInCareer;
import 'song_detail_screen.dart';
import 'streamify/artist_page.dart';

/// Best sellers in the chart tabs (docs K141): all time (artists, albums,
/// songs; units or copies sold), one year's, or each year's winners.
class BestSellersBoard extends StatefulWidget {
  const BestSellersBoard({super.key});

  @override
  State<BestSellersBoard> createState() => _BestSellersBoardState();
}

/// The board's period: all time, the winners, or a year.
const _allTime = 0;
const _winners = -1;

class _BestSellersBoardState extends State<BestSellersBoard> {
  int _period = _allTime;
  BestSellerKind _kind = BestSellerKind.artists;
  SalesMeasure _measure = SalesMeasure.units;
  List<int> _years = const [];
  List<BestSellerRow>? _rows;
  List<YearWinners>? _wins;
  int _myRank = 0;
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
    final years = await career.read(Cmd.yearEndYears());
    if (_period == _winners) {
      final wins = await career.read(Cmd.yearWinners());
      if (mounted) {
        setState(() {
          _years = years;
          _wins = wins;
        });
      }
      return;
    }
    if (_period == _allTime) {
      final (rows, rank) =
          await career.read(Cmd.bestSellers(_kind, _measure));
      if (mounted) {
        setState(() {
          _years = years;
          _rows = rows;
          _myRank = rank;
        });
      }
      return;
    }
    final rows = await career.read(Cmd.yearBestSellers(_kind, _period));
    if (mounted) {
      setState(() {
        _years = years;
        _rows = rows;
      });
    }
  }

  void _set(VoidCallback f) {
    setState(() {
      f();
      _rows = null;
      _wins = null;
    });
    _load();
  }

  void _openRow(BestSellerRow r) {
    final career = context.careerRead;
    switch (r.kind) {
      case BestSellerKind.artists:
        pushInCareer(context, ArtistPage(artistId: r.artistId));
      case BestSellerKind.albums:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    AlbumDetailScreen(albumId: r.entityId, state: career)));
      case BestSellerKind.songs:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    SongDetailScreen(songId: r.entityId, state: career)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    String kindName(BestSellerKind k) => switch (k) {
          BestSellerKind.artists => l.bestSellersArtists,
          BestSellerKind.albums => l.bestSellersAlbums,
          BestSellerKind.songs => l.bestSellersSongs,
        };
    Widget chips(List<Widget> children, {double top = 8}) => SizedBox(
          height: 44 + top - 8,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(12, top, 12, 0),
            children: [
              for (final c in children)
                Padding(padding: const EdgeInsets.only(right: 6), child: c),
            ],
          ),
        );
    return Column(children: [
      chips([
        ChoiceChip(
          label: Text(l.bestSellersAllTime),
          selected: _period == _allTime,
          onSelected: (_) => _set(() => _period = _allTime),
        ),
        if (_years.isNotEmpty)
          ChoiceChip(
            label: Text(l.bestSellersWinners),
            selected: _period == _winners,
            onSelected: (_) => _set(() => _period = _winners),
          ),
        for (final y in _years)
          ChoiceChip(
            label: Text('$y'),
            selected: _period == y,
            onSelected: (_) => _set(() => _period = y),
          ),
      ]),
      if (_period != _winners)
        chips(top: 4, [
          for (final k in BestSellerKind.values)
            ChoiceChip(
              label: Text(kindName(k)),
              selected: _kind == k,
              onSelected: (_) => _set(() => _kind = k),
            ),
          if (_period == _allTime)
            for (final m in SalesMeasure.values)
              FilterChip(
                label: Text(m == SalesMeasure.units
                    ? l.bestSellersUnits
                    : l.bestSellersCopies),
                selected: _measure == m,
                onSelected: (_) => _set(() => _measure = m),
              ),
        ]),
      if (_period == _allTime &&
          _kind == BestSellerKind.artists &&
          _myRank > 0 &&
          _rows != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l.bestSellersMyRank(_myRank),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: PaperColors.ink)),
          ),
        ),
      if (_period != _allTime && _period != _winners)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
              _kind == BestSellerKind.artists
                  ? l.bestSellersYearArtistsHint
                  : l.bestSellersYearHint,
              style: const TextStyle(fontSize: 12.5, color: PaperColors.muted)),
        ),
      const SizedBox(height: 6),
      Expanded(
        child: _period == _winners
            ? _winnersList(context)
            : _rows == null
                ? const Center(
                    child: CircularProgressIndicator(color: PaperColors.ink))
                : _rows!.isEmpty
                    ? Center(
                        child: Text(l.yearEndEmpty,
                            style: const TextStyle(color: PaperColors.muted)))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _rows!.length,
                        separatorBuilder: (_, __) => const Divider(
                            color: PaperColors.line, height: 1, indent: 16),
                        itemBuilder: (context, i) {
                          final r = _rows![i];
                          return _Line(
                            rank: r.rank,
                            artist: r.kind == BestSellerKind.artists,
                            album: r.kind == BestSellerKind.albums,
                            entityId: r.entityId,
                            albumId: r.albumId,
                            title: r.kind == BestSellerKind.artists
                                ? r.artistName
                                : r.title,
                            subtitle: r.kind == BestSellerKind.artists
                                ? null
                                : _period == _allTime
                                    ? '${r.artistName} · ${r.releaseYear}'
                                    : r.artistName,
                            value: r.kind == BestSellerKind.songs &&
                                    _period != _allTime
                                ? null
                                : fmt.compact(r.value),
                            isPlayer: r.isPlayer,
                            onTap: () => _openRow(r),
                          );
                        },
                      ),
      ),
    ]);
  }

  Widget _winnersList(BuildContext context) {
    final l = context.l10n;
    final wins = _wins;
    if (wins == null) {
      return const Center(
          child: CircularProgressIndicator(color: PaperColors.ink));
    }
    if (wins.isEmpty) {
      return Center(
          child: Text(l.yearEndEmpty,
              style: const TextStyle(color: PaperColors.muted)));
    }
    final career = context.careerRead;
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      for (final y in wins) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('${y.year}',
              style: const TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: PaperColors.ink)),
        ),
        if (y.artist case final a?)
          _Line(
            label: l.bestSellersArtistOfYear,
            artist: true,
            album: false,
            entityId: a.artistId,
            albumId: -1,
            title: a.artistName,
            isPlayer: a.isPlayer,
            onTap: () => pushInCareer(context, ArtistPage(artistId: a.artistId)),
          ),
        if (y.album case final a?)
          _Line(
            label: l.bestSellersAlbumOfYear,
            artist: false,
            album: true,
            entityId: a.entityId,
            albumId: a.entityId,
            title: a.title,
            subtitle: a.artistName,
            isPlayer: a.isPlayer,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AlbumDetailScreen(albumId: a.entityId, state: career))),
          ),
        if (y.song case final s?)
          _Line(
            label: l.bestSellersSongOfYear,
            artist: false,
            album: false,
            entityId: s.entityId,
            albumId: s.albumId,
            title: s.title,
            subtitle: s.artistName,
            isPlayer: s.isPlayer,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        SongDetailScreen(songId: s.entityId, state: career))),
          ),
      ],
    ]);
  }
}

/// One row: a rank or a label, art, names and a number.
class _Line extends StatelessWidget {
  const _Line(
      {this.rank,
      this.label,
      required this.artist,
      required this.album,
      required this.entityId,
      required this.albumId,
      required this.title,
      this.subtitle,
      this.value,
      required this.isPlayer,
      required this.onTap});
  final int? rank;
  final String? label;
  final bool artist;
  final bool album;
  final int entityId;
  final int albumId;
  final String title;
  final String? subtitle;
  final String? value;
  final bool isPlayer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = rank;
    return InkWell(
      onTap: onTap,
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
          if (artist)
            ArtistAvatar(name: title, seed: entityId, size: 42)
          else
            CoverArt(
                seed: album
                    ? albumCoverSeed(entityId)
                    : songCoverSeed(entityId, albumId),
                size: 42,
                radius: 4,
                songId: album ? null : entityId,
                albumId: album ? entityId : albumId),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(label!.toUpperCase(),
                        style: const TextStyle(
                            fontFamily: AppFonts.condensed,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.6,
                            color: PaperColors.muted)),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: PaperColors.ink)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: PaperColors.muted)),
                ]),
          ),
          if (value != null)
            Text(value!,
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: PaperColors.ink)),
        ]),
      ),
    );
  }
}
