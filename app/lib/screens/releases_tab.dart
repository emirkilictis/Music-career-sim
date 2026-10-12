import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// Releases: put out singles and albums, and see the discography.
class ReleasesTab extends StatefulWidget {
  const ReleasesTab({super.key});

  @override
  State<ReleasesTab> createState() => _ReleasesTabState();
}

class _ReleasesTabState extends State<ReleasesTab> {
  List<SongView> _songs = const [];
  List<AlbumView> _albums = const [];
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
    final songs = await career.read(Cmd.songs());
    final albums = await career.read(Cmd.albums());
    if (mounted) {
      setState(() {
        _songs = songs;
        _albums = albums;
      });
    }
  }

  Future<void> _releaseSingle() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final eligible = _songs.where((s) => !s.isSingle).toList()
      ..sort((a, b) => b.estimatedGrade.compareTo(a.estimatedGrade));
    if (eligible.isEmpty) {
      showInfo(context, l.noSongsToRelease);
      return;
    }
    final song = await showModalBottomSheet<SongView>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (c, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child:
                  Text(l.pickSingle, style: Theme.of(c).textTheme.titleLarge),
            ),
            for (final s in eligible)
              ListTile(
                leading: CircleAvatar(child: Text(fmt.grade(s.estimatedGrade))),
                title: Text(s.title),
                subtitle:
                    Text('${fmt.songStatus(s)} · ${fmt.genres(s.genres)}'),
                onTap: () => Navigator.pop(c, s),
              ),
          ],
        ),
      ),
    );
    if (song == null || !mounted) return;
    final campaign = await pickCampaign(context, career);
    if (campaign == null || !mounted) return;
    try {
      await career.act(Cmd.releaseSingle(song.id, campaign));
      if (mounted) showInfo(context, l.singleReleased(song.title));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final singles = _songs.where((s) => s.isSingle).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: career.busy ? null : _releaseSingle,
              icon: const Icon(Icons.music_note),
              label: Text(l.releaseSingle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: career.busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AlbumBuilderScreen(
                              state: career,
                              songs: _songs
                                  .where((s) => s.albumId < 0)
                                  .toList()))),
              icon: const Icon(Icons.album),
              label: Text(l.newAlbum),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Section(
          title: l.albumsAndEps,
          child: _albums.isEmpty
              ? EmptyNote(l.noAlbumsYet)
              : Column(children: [
                  for (final a in _albums)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PosBadge(
                          a.charts
                                  .where((c) => c.chartId == Charts.usAlbums)
                                  .firstOrNull
                                  ?.peak ??
                              0,
                          highlight: true),
                      title: Text(a.title),
                      subtitle: Text(
                          '${fmt.albumType(a.type)} · ${GameTime.yearOf(a.releaseWeek)} · '
                          '${l.firstWeekShort(fmt.compact(a.firstWeekUsUnits))}'),
                      trailing: Text(fmt.compact(a.lifetimeUnits.total)),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                  albumId: a.id, state: career))),
                    ),
                ]),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.singles,
          child: singles.isEmpty
              ? EmptyNote(l.noSinglesYet)
              : Column(children: [
                  for (final s in singles)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PosBadge(
                          s.charts
                                  .where((c) => c.chartId == Charts.usSongs)
                                  .firstOrNull
                                  ?.peak ??
                              0,
                          highlight: true),
                      title: Text(s.title),
                      subtitle: Text(
                          '${GameTime.yearOf(s.singleWeek)} · ${fmt.campaign(s.campaign)}'),
                      trailing: Text(fmt.compact(s.lifetimeStreams.total)),
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
  }
}

/// Campaign choice with prices (docs/game-design.md §9).
Future<Campaign?> pickCampaign(BuildContext context, CareerState career,
    {int extraCents = 0}) {
  final l = context.l10n;
  final fmt = context.fmt;
  final money = career.player.moneyCents;
  return showModalBottomSheet<Campaign>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(l.pickCampaign, style: Theme.of(c).textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l.campaignHint, style: Theme.of(c).textTheme.bodySmall),
        ),
        for (final k in Campaign.values)
          ListTile(
            enabled: k.costCents + extraCents <= money,
            leading: Icon(switch (k) {
              Campaign.none => Icons.volume_off_outlined,
              Campaign.standard => Icons.campaign_outlined,
              Campaign.intensive => Icons.rocket_launch_outlined,
              Campaign.global => Icons.public,
            }),
            title: Text(fmt.campaign(k)),
            subtitle: Text(switch (k) {
              Campaign.none => l.campaignNoneHint,
              Campaign.standard => l.campaignStandardHint,
              Campaign.intensive => l.campaignIntensiveHint,
              Campaign.global => l.campaignGlobalHint,
            }),
            trailing: Text(fmt.money(k.costCents)),
            onTap: () => Navigator.pop(c, k),
          ),
        const SizedBox(height: 8),
      ])),
    ),
  );
}

/// Builds an album or EP from vault songs and earlier singles.
class AlbumBuilderScreen extends StatefulWidget {
  const AlbumBuilderScreen(
      {super.key, required this.state, required this.songs});
  final CareerState state;

  /// Songs that are not on a release yet.
  final List<SongView> songs;

  @override
  State<AlbumBuilderScreen> createState() => _AlbumBuilderScreenState();
}

class _AlbumBuilderScreenState extends State<AlbumBuilderScreen> {
  final _title = TextEditingController();
  final Set<int> _picked = {};
  AlbumType _type = AlbumType.album;
  int _editions = 1;
  bool _stagger = true;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<int> get _variantWeeks => [
        0,
        for (var i = 1; i < _editions; i++) _stagger ? i : 0,
      ];

  int get _variantCost => Actions.variantCostCents * (_editions - 1);

  Future<void> _release() async {
    final l = context.l10n;
    final career = widget.state;
    final ordered = [
      for (final s in widget.songs)
        if (_picked.contains(s.id)) s.id
    ];
    final campaign =
        await pickCampaign(context, career, extraCents: _variantCost);
    if (campaign == null || !mounted) return;
    try {
      final album = await career.act(Cmd.releaseAlbum(
        title: _title.text,
        songIds: ordered,
        type: _type,
        variantWeeks: _variantWeeks,
        campaign: campaign,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      showInfo(context, l.albumReleased(album.title));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final (lo, hi) = _type == AlbumType.ep
        ? (GameSession.minEpTracks, GameSession.maxEpTracks)
        : (GameSession.minAlbumTracks, GameSession.maxAlbumTracks);
    final n = _picked.length;
    final ok = n >= lo && n <= hi && _title.text.trim().isNotEmpty;
    final songs = [...widget.songs]
      ..sort((a, b) => b.estimatedGrade.compareTo(a.estimatedGrade));
    return Scaffold(
      appBar: AppBar(title: Text(l.newAlbum)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: l.albumTitle, border: const OutlineInputBorder()),
          ),
          SegmentedButton<AlbumType>(
            segments: [
              ButtonSegment(
                  value: AlbumType.ep,
                  label: Text(fmt.albumType(AlbumType.ep))),
              ButtonSegment(
                  value: AlbumType.album,
                  label: Text(fmt.albumType(AlbumType.album))),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          Section(
            title: l.tracksPicked(n, lo, hi),
            child: songs.isEmpty
                ? EmptyNote(l.noSongsToRelease)
                : Column(children: [
                    for (final s in songs)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _picked.contains(s.id),
                        onChanged: (on) => setState(() =>
                            on! ? _picked.add(s.id) : _picked.remove(s.id)),
                        title: Text(s.title),
                        subtitle: Text(
                            '${fmt.grade(s.estimatedGrade)} · ${fmt.songStatus(s)} · ${fmt.genres(s.genres)}'),
                      ),
                  ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.editions,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text(l.editionsCount(_editions))),
                    IconButton(
                        onPressed: _editions > 1
                            ? () => setState(() => _editions--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline)),
                    IconButton(
                        onPressed: _editions < GameSession.maxVariants
                            ? () => setState(() => _editions++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline)),
                  ]),
                  Text(l.editionsHint(fmt.money(Actions.variantCostCents)),
                      style: Theme.of(context).textTheme.bodySmall),
                  if (_editions > 1)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.staggerEditions),
                      subtitle: Text(l.staggerEditionsHint),
                      value: _stagger,
                      onChanged: (v) => setState(() => _stagger = v),
                    ),
                ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: ok && !widget.state.busy ? _release : null,
            icon: const Icon(Icons.rocket_launch),
            label: Text(_variantCost > 0
                ? l.releaseWithCost(fmt.money(_variantCost))
                : l.release),
          ),
        ),
      ),
    );
  }
}
