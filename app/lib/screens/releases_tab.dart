import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../core/images.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/image_pickers.dart';
import '../widgets/media_tile.dart';
import '../widgets/release_timing.dart';
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
  List<ScheduledView> _scheduled = const [];
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
    final scheduled = await career.read(Cmd.scheduled());
    if (mounted) {
      setState(() {
        _songs = songs;
        _albums = albums;
        _scheduled = scheduled;
      });
    }
  }

  Future<void> _releaseSingle() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final eligible = _songs
        .where((s) => !s.isSingle && s.scheduledSingleWeek < 0)
        .toList()
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
                leading: CoverArt(
                    seed: songCoverSeed(s.id, s.albumId),
                    songId: s.id,
                    albumId: s.albumId),
                trailing: GradeTag(fmt.grade(s.estimatedGrade)),
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
    final when = await pickReleaseTiming(context, week: career.week);
    if (when == null || !mounted) return;
    final campaign = await pickCampaign(context, career,
        header: CoverPickRow(songId: song.id, albumId: song.albumId));
    if (campaign == null || !mounted) return;
    try {
      if (when.releaseWeek == career.week) {
        await career.act(Cmd.releaseSingle(song.id, campaign));
        if (mounted) showInfo(context, l.singleReleased(song.title));
      } else {
        await career.act(Cmd.scheduleSingle(
            song.id, campaign, when.releaseWeek, when.announceWeek));
        if (mounted) {
          showInfo(context,
              l.releaseScheduled(song.title, fmt.week(when.releaseWeek)));
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Change the date of a scheduled release, or call it off.
  Future<void> _editScheduled(ScheduledView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final action = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(s.title,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${fmt.albumType(s.type)} · '
                '${l.releaseDate(fmt.week(s.releaseWeek))}'),
          ),
          if (s.isAlbum)
            PendingKeyCoverRow(imageKey: ImageStore.scheduledKey(s.id)),
          ListTile(
            leading: const Icon(Icons.edit_calendar_rounded),
            title: Text(l.changeDate),
            onTap: () => Navigator.pop(c, true),
          ),
          ListTile(
            leading: Icon(Icons.event_busy_rounded, color: AppColors.coral),
            title: Text(l.cancelRelease),
            onTap: () => Navigator.pop(c, false),
          ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action) {
        final when =
            await pickReleaseTiming(context, week: career.week, editing: s);
        if (when == null || !mounted) return;
        await career
            .act(Cmd.reschedule(s.id, when.releaseWeek, when.announceWeek));
        if (mounted) showInfo(context, l.dateSaved);
      } else {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.cancelReleaseTitle),
            content: Text(l.cancelReleaseBody(fmt.money(s.paidCents))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(l.cancelRelease)),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        final images = context.imagesRead;
        await career.act(Cmd.cancelScheduled(s.id));
        images.remove(ImageStore.scheduledKey(s.id));
        if (mounted) showInfo(context, l.releaseCancelled);
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
    final singles = _songs.where((s) => s.isSingle).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.music_note_rounded,
              color: AppColors.pink,
              label: l.releaseSingle,
              onTap: career.busy ? null : _releaseSingle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.album_rounded,
              color: AppColors.lilac,
              label: l.newAlbum,
              onTap: career.busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AlbumBuilderScreen(
                              state: career,
                              songs: _songs
                                  .where((s) =>
                                      s.albumId < 0 && s.scheduledAlbumWeek < 0)
                                  .toList()))),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (_scheduled.isNotEmpty) ...[
          Section(
            title: l.upcoming,
            icon: Icons.event_rounded,
            child: Column(children: [
              for (final s in _scheduled)
                MediaTile(
                  coverSeed: s.isAlbum
                      ? albumCoverSeed(s.id)
                      : songCoverSeed(s.songIds.single, -1),
                  songId: s.isAlbum ? null : s.songIds.single,
                  imageKey: s.isAlbum ? ImageStore.scheduledKey(s.id) : null,
                  title: s.title,
                  subtitleLines: 2,
                  subtitle: '${fmt.albumType(s.type)} · '
                      '${l.releaseDate(fmt.week(s.releaseWeek))}\n'
                      '${s.isSurprise ? l.announceSurprise : s.announced ? '${l.statusAnnounced} · ${l.buzzLabel} ${(100 * s.buzz / s.buzzCap).round()}%' : l.announceDate(fmt.week(s.announceWeek))}',
                  onTap: career.busy ? null : () => _editScheduled(s),
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        Section(
          title: l.albumsAndEps,
          icon: Icons.album_outlined,
          child: _albums.isEmpty
              ? EmptyNote(l.noAlbumsYet)
              : Column(children: [
                  for (final a in _albums)
                    MediaTile(
                      coverSeed: albumCoverSeed(a.id),
                      albumId: a.id,
                      badge: PeakTag(a.charts
                              .where((c) => c.chartId == Charts.usAlbums)
                              .firstOrNull
                              ?.peak ??
                          0),
                      title: a.title,
                      subtitle:
                          '${fmt.albumType(a.type)} · ${GameTime.yearOf(a.releaseWeek)} · '
                          '${l.firstWeekShort(fmt.compact(a.firstWeekUsUnits))}',
                      value: fmt.compact(a.lifetimeUnits.total),
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
          icon: Icons.music_note_outlined,
          child: singles.isEmpty
              ? EmptyNote(l.noSinglesYet)
              : Column(children: [
                  for (final s in singles)
                    MediaTile(
                      coverSeed: songCoverSeed(s.id, s.albumId),
                      songId: s.id,
                      albumId: s.albumId,
                      badge: PeakTag(s.charts
                              .where((c) => c.chartId == Charts.usSongs)
                              .firstOrNull
                              ?.peak ??
                          0),
                      title: s.title,
                      subtitle:
                          '${GameTime.yearOf(s.singleWeek)} · ${fmt.campaign(s.campaign)}',
                      value: fmt.songMain(s, career.week),
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
    {int extraCents = 0, Widget? header}) {
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
        if (header != null) ...[header, const Divider(height: 20)],
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

  /// Cover picked before the album exists; saved once it is released.
  String? _cover;
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
    final when = await pickReleaseTiming(context, week: career.week);
    if (when == null || !mounted) return;
    final campaign =
        await pickCampaign(context, career, extraCents: _variantCost);
    if (campaign == null || !mounted) return;
    try {
      final cover = _cover;
      final images = context.imagesRead;
      if (when.releaseWeek == career.week) {
        final album = await career.act(Cmd.releaseAlbum(
          title: _title.text,
          songIds: ordered,
          type: _type,
          variantWeeks: _variantWeeks,
          campaign: campaign,
        ));
        if (cover != null) images.save(ImageStore.albumKey(album.id), cover);
        if (!mounted) return;
        Navigator.pop(context);
        showInfo(context, l.albumReleased(album.title));
      } else {
        final s = await career.act(Cmd.scheduleAlbum(
          title: _title.text,
          songIds: ordered,
          type: _type,
          variantWeeks: _variantWeeks,
          campaign: campaign,
          releaseWeek: when.releaseWeek,
          announceWeek: when.announceWeek,
        ));
        if (cover != null) images.save(ImageStore.scheduledKey(s.id), cover);
        if (!mounted) return;
        Navigator.pop(context);
        showInfo(context,
            l.releaseScheduled(s.title, context.fmt.week(s.releaseWeek)));
      }
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
          PendingCoverRow(
              path: _cover, onChanged: (p) => setState(() => _cover = p)),
          const SizedBox(height: 8),
          SegmentedButton<AlbumType>(
            showSelectedIcon: false,
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
          child: GradientButton(
            onPressed: ok && !widget.state.busy ? _release : null,
            icon: Icons.rocket_launch_rounded,
            label: _variantCost > 0
                ? l.releaseWithCost(fmt.money(_variantCost))
                : l.release,
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        borderRadius: BorderRadius.circular(22),
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: AppColors.haze(color, AppColors.surface),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBubble(icon, color: color),
                    const SizedBox(height: 14),
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15.5)),
                  ]),
            ),
          ),
        ),
      );
}
