import 'dart:io';

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
  List<UpcomingRelease> _rivals = const [];
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
    final rivals = await career.read(Cmd.upcomingRivalAlbums());
    if (mounted) {
      setState(() {
        _songs = songs;
        _albums = albums;
        _scheduled = scheduled;
        _rivals = rivals;
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
    final groups = <(String, List<SongView>)>[
      for (final a in _albums)
        if (eligible.any((s) => s.albumId == a.id))
          (
            l.fromAlbum(a.title),
            [
              for (final id in a.trackIds) ...eligible.where((s) => s.id == id),
            ]
          ),
      if (eligible.any((s) => s.inVault))
        (l.fromVault, eligible.where((s) => s.inVault).toList()),
    ];
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
            // Album tracks first, grouped by album (newest first), then
            // the vault.
            for (final (header, group) in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(header,
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700)),
              ),
              for (final s in group)
                ListTile(
                  leading: CoverArt(
                      seed: songCoverSeed(s.id, s.coverAlbumId),
                      songId: s.id,
                      albumId: s.coverAlbumId),
                  trailing: GradeTag(fmt.songGrade(s)),
                  title: Text(s.title),
                  subtitle: Text(s.inVault
                      ? fmt.genres(s.genres)
                      : '${fmt.songMain(s, career.week)} · ${fmt.genres(s.genres)}'),
                  onTap: () => Navigator.pop(c, s),
                ),
            ],
          ],
        ),
      ),
    );
    if (song == null || !mounted) return;
    await releaseSingleFlow(context, career, song);
  }

  /// A draft in the vault: release it, give it a date, or delete it.
  Future<void> _editDraft(ScheduledView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final images = context.imagesRead;
    final action = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(s.title,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(l.draftSubtitle(fmt.albumType(s.type),
                s.songIds.length, fmt.week(s.createdWeek))),
          ),
          PendingKeyCoverRow(imageKey: ImageStore.scheduledKey(s.id)),
          ListTile(
            leading: const Icon(Icons.rocket_launch_rounded),
            title: Text(l.releaseDraftNow),
            onTap: () => Navigator.pop(c, 0),
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_rounded),
            title: Text(l.pickDraftDate),
            onTap: () => Navigator.pop(c, 1),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: AppColors.coral),
            title: Text(l.deleteDraft),
            onTap: () => Navigator.pop(c, 2),
          ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 2) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.deleteDraftTitle),
            content: Text(l.deleteDraftBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(l.deleteDraft)),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        await career.act(Cmd.cancelScheduled(s.id));
        images.remove(ImageStore.scheduledKey(s.id));
        if (mounted) showInfo(context, l.draftDeleted);
        return;
      }
      var releaseWeek = career.week, announceWeek = career.week;
      if (action == 1) {
        final when = await pickReleaseTiming(context, career);
        if (when == null || !mounted) return;
        (releaseWeek, announceWeek) = (when.releaseWeek, when.announceWeek);
      }
      final campaign =
          await pickCampaign(context, career, extraCents: s.editionsCostCents);
      if (campaign == null || !mounted) return;
      if (releaseWeek == career.week) {
        final album = await career.act(Cmd.releaseDraft(s.id, campaign));
        images.adoptWithEditions(
            ImageStore.scheduledKey(s.id), ImageStore.albumKey(album.id));
        if (mounted) showInfo(context, l.albumReleased(album.title));
      } else {
        await career
            .act(Cmd.scheduleDraft(s.id, campaign, releaseWeek, announceWeek));
        if (mounted) {
          showInfo(context, l.releaseScheduled(s.title, fmt.week(releaseWeek)));
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
        final when = await pickReleaseTiming(context, career, editing: s);
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
    final dated = _scheduled.where((s) => !s.isDraft).toList();
    final drafts = _scheduled.where((s) => s.isDraft).toList();
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
        if (dated.isNotEmpty) ...[
          Section(
            title: l.upcoming,
            icon: Icons.event_rounded,
            child: Column(children: [
              for (final s in dated)
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
        if (drafts.isNotEmpty) ...[
          Section(
            title: l.drafts,
            icon: Icons.inventory_2_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.draftHint,
                      style: Theme.of(context).textTheme.bodySmall),
                  for (final s in drafts)
                    MediaTile(
                      coverSeed: albumCoverSeed(s.id),
                      imageKey: ImageStore.scheduledKey(s.id),
                      title: s.title,
                      subtitle: l.draftSubtitle(fmt.albumType(s.type),
                          s.songIds.length, fmt.week(s.createdWeek)),
                      onTap: career.busy ? null : () => _editDraft(s),
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
                          '${fmt.albumType(a.type)} · ${GameTime.yearOf(a.releaseWeek)}'
                          '${a.criticScore >= 0 ? ' · ${l.criticName} ${fmt.criticScore(a.criticScore)}' : ''} · '
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
                      coverSeed: songCoverSeed(s.id, s.coverAlbumId),
                      songId: s.id,
                      albumId: s.coverAlbumId,
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
        const SizedBox(height: 12),
        if (_rivals.isNotEmpty) ...[
          Section(
            title: l.rivalReleases,
            icon: Icons.sports_mma_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.rivalReleasesHint,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  for (final r in _rivals.take(6))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.artistName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle:
                          Text(l.rivalReleaseLine(fmt.week(r.week), r.title)),
                      trailing: Text(
                          switch (r.week - career.week) {
                            0 => l.releaseNow,
                            1 => l.inOneWeek,
                            final n => l.inWeeks(n),
                          },
                          style: TextStyle(color: AppColors.textFaint)),
                    ),
                ]),
          ),
        ],
      ],
    );
  }
}

/// Puts [song] out as a single: when (now or later, with its announcement;
/// docs K45), then the campaign. Returns true if it was released or set.
Future<bool> releaseSingleFlow(
    BuildContext context, CareerState career, SongView song) async {
  final l = context.l10n;
  final fmt = context.fmt;
  final when = await pickReleaseTiming(context, career);
  if (when == null || !context.mounted) return false;
  final campaign = await pickCampaign(context, career,
      header: CoverPickRow(songId: song.id, albumId: song.coverAlbumId));
  if (campaign == null || !context.mounted) return false;
  final radio = await pickRadioPush(context, career,
      extraCents: career.player.campaignCosts[campaign.index]);
  if (radio == null || !context.mounted) return false;
  try {
    if (when.releaseWeek == career.week) {
      await career.act(Cmd.releaseSingle(song.id, campaign, radio));
      if (context.mounted) showInfo(context, l.singleReleased(song.title));
    } else {
      await career.act(Cmd.scheduleSingle(
          song.id, campaign, when.releaseWeek, when.announceWeek, radio));
      if (context.mounted) {
        showInfo(context,
            l.releaseScheduled(song.title, fmt.week(when.releaseWeek)));
      }
    }
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// Campaign choice with prices (docs/game-design.md §9).
Future<Campaign?> pickCampaign(BuildContext context, CareerState career,
    {int extraCents = 0, Widget? header}) {
  final l = context.l10n;
  final fmt = context.fmt;
  final money = career.player.moneyCents;
  final label = career.player.label;
  int cost(Campaign k) => career.player.campaignCosts[k.index];
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
            enabled: k.index <= label.maxCampaign.index &&
                cost(k) + extraCents <= money,
            leading: Icon(switch (k) {
              Campaign.none => Icons.volume_off_outlined,
              Campaign.standard => Icons.campaign_outlined,
              Campaign.intensive => Icons.rocket_launch_outlined,
              Campaign.global => Icons.public,
            }),
            title: Text(fmt.campaign(k)),
            subtitle: Text(k.index > label.maxCampaign.index
                ? l.campaignLockedHint
                : switch (k) {
                    Campaign.none => l.campaignNoneHint,
                    Campaign.standard => l.campaignStandardHint,
                    Campaign.intensive => l.campaignIntensiveHint,
                    Campaign.global => l.campaignGlobalHint,
                  }),
            trailing: Text(fmt.money(cost(k))),
            onTap: () => Navigator.pop(c, k),
          ),
        const SizedBox(height: 8),
      ])),
    ),
  );
}

/// Radio push for a single, bought on top of the campaign (docs K84).
Future<RadioPush?> pickRadioPush(BuildContext context, CareerState career,
    {int extraCents = 0}) {
  final l = context.l10n;
  final fmt = context.fmt;
  final p = career.player;
  int cost(RadioPush r) => p.radioPushCosts[r.index];
  return showModalBottomSheet<RadioPush>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(l.pickRadioPush, style: Theme.of(c).textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l.radioPushHint, style: Theme.of(c).textTheme.bodySmall),
        ),
        for (final r in RadioPush.values)
          ListTile(
            enabled: r.index <= p.maxRadioPush.index &&
                cost(r) + extraCents <= p.moneyCents,
            leading: Icon(switch (r) {
              RadioPush.none => Icons.radio_outlined,
              RadioPush.standard => Icons.radio,
              RadioPush.heavy => Icons.cell_tower_rounded,
            }),
            title: Text(fmt.radioPush(r)),
            subtitle: Text(r.index > p.maxRadioPush.index
                ? l.radioLockedHint
                : switch (r) {
                    RadioPush.none => l.radioNoneHint,
                    RadioPush.standard => l.radioStandardHint,
                    RadioPush.heavy => l.radioHeavyHint,
                  }),
            trailing: Text(fmt.money(cost(r))),
            onTap: () => Navigator.pop(c, r),
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

  /// Extra editions after the standard one (docs K46).
  final List<_Edition> _extras = [];

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
        for (var i = 1; i <= _extras.length; i++) _stagger ? i : 0,
      ];

  List<EditionFormat?> get _variantFormats =>
      [null, for (final e in _extras) e.format];

  int get _variantCost => _extras.fold(0, (sum, e) => sum + e.format.costCents);

  /// Saves the covers chosen here under the album's (or schedule's) key.
  void _saveCovers(ImageStore images, String base) {
    final cover = _cover;
    if (cover != null) images.save(base, cover);
    for (var i = 0; i < _extras.length; i++) {
      final c = _extras[i].cover;
      if (c != null) images.save(ImageStore.editionKey(base, i + 1), c);
    }
  }

  List<int> get _ordered => [
        for (final s in widget.songs)
          if (_picked.contains(s.id)) s.id
      ];

  /// Keeps the album in the vault with no date (docs F31).
  Future<void> _saveDraft() async {
    final l = context.l10n;
    try {
      final images = context.imagesRead;
      final s = await widget.state.act(Cmd.saveDraft(
        title: _title.text,
        songIds: _ordered,
        type: _type,
        variantWeeks: _variantWeeks,
        variantFormats: _variantFormats,
      ));
      _saveCovers(images, ImageStore.scheduledKey(s.id));
      if (!mounted) return;
      Navigator.pop(context);
      showInfo(context, l.draftSaved(s.title));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _release() async {
    final l = context.l10n;
    final career = widget.state;
    final ordered = _ordered;
    final when = await pickReleaseTiming(context, career);
    if (when == null || !mounted) return;
    final campaign =
        await pickCampaign(context, career, extraCents: _variantCost);
    if (campaign == null || !mounted) return;
    try {
      final images = context.imagesRead;
      if (when.releaseWeek == career.week) {
        final album = await career.act(Cmd.releaseAlbum(
          title: _title.text,
          songIds: ordered,
          type: _type,
          variantWeeks: _variantWeeks,
          variantFormats: _variantFormats,
          campaign: campaign,
        ));
        _saveCovers(images, ImageStore.albumKey(album.id));
        if (!mounted) return;
        Navigator.pop(context);
        showInfo(context, l.albumReleased(album.title));
      } else {
        final s = await career.act(Cmd.scheduleAlbum(
          title: _title.text,
          songIds: ordered,
          type: _type,
          variantWeeks: _variantWeeks,
          variantFormats: _variantFormats,
          campaign: campaign,
          releaseWeek: when.releaseWeek,
          announceWeek: when.announceWeek,
        ));
        _saveCovers(images, ImageStore.scheduledKey(s.id));
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
    final (lo, hi) = GameSession.trackRange(_type);
    final n = _picked.length;
    final ok = n >= lo && n <= hi && _title.text.trim().isNotEmpty;
    final songs = [...widget.songs]
      ..sort((a, b) => b.estimatedGrade.compareTo(a.estimatedGrade));
    final year = GameTime.yearOf(widget.state.week);
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
              ButtonSegment(
                  value: AlbumType.mixtape,
                  label: Text(fmt.albumType(AlbumType.mixtape))),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (_type == AlbumType.mixtape) _extras.clear();
            }),
          ),
          if (_type == AlbumType.mixtape)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.mixtapeHint,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
                            '${fmt.songGrade(s)} · ${fmt.songStatus(s)} · ${fmt.genres(s.genres)}'),
                      ),
                  ]),
          ),
          if (_type != AlbumType.mixtape) ...[
            const SizedBox(height: 12),
            Section(
              title: l.editions,
              trailing: Text(l.editionsCount(_extras.length + 1),
                  style: TextStyle(color: AppColors.textMuted)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.editionsHint,
                        style: Theme.of(context).textTheme.bodySmall),
                    for (var i = 0; i < _extras.length; i++)
                      _EditionEditor(
                        index: i + 2,
                        edition: _extras[i],
                        year: year,
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() => _extras.removeAt(i)),
                      ),
                    if (_extras.length < GameSession.maxVariants - 1)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _extras.add(_Edition(
                              year >= 2015
                                  ? EditionFormat.vinyl
                                  : EditionFormat.cd))),
                          icon: const Icon(Icons.add_circle_outline),
                          label: Text(l.editionN(_extras.length + 2)),
                        ),
                      ),
                    if (_extras.isNotEmpty)
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GradientButton(
              onPressed: ok && !widget.state.busy ? _release : null,
              icon: Icons.rocket_launch_rounded,
              label: _variantCost > 0
                  ? l.releaseWithCost(fmt.money(_variantCost))
                  : l.release,
            ),
            TextButton.icon(
              onPressed: ok && !widget.state.busy ? _saveDraft : null,
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text(l.saveDraft),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Edition {
  _Edition(this.format);
  EditionFormat format;
  String? cover;
}

/// One extra edition: its cover (the player's own photo), its format and
/// how that format sells right now.
class _EditionEditor extends StatelessWidget {
  const _EditionEditor({
    required this.index,
    required this.edition,
    required this.year,
    required this.onChanged,
    required this.onRemove,
  });
  final int index;
  final _Edition edition;
  final int year;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final cover = edition.cover;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppShape.r(16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppShape.r(8)),
            onTap: () async {
              final picked = await context.imagesRead.source.pick();
              if (picked != null) {
                edition.cover = picked;
                onChanged();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppShape.r(8)),
              child: SizedBox.square(
                dimension: 56,
                child: cover == null
                    ? ColoredBox(
                        color: AppColors.surface,
                        child: Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.textMuted))
                    : Image.file(File(cover), fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.editionN(index),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                  '${fmt.editionFormat(edition.format)} · '
                  '${fmt.money(edition.format.costCents)}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Text(fmt.formatAppeal(edition.format, year),
                  style: TextStyle(
                      color: edition.format.appeal(year) >= 1.0
                          ? AppColors.mint
                          : edition.format.appeal(year) >= 0.7
                              ? AppColors.textMuted
                              : AppColors.coral,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          IconButton(
              tooltip: l.delete,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final f in EditionFormat.values)
            ChoiceChip(
              label: Text(fmt.editionFormat(f)),
              selected: f == edition.format,
              onSelected: (_) {
                edition.format = f;
                onChanged();
              },
            ),
        ]),
      ]),
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
        borderRadius: BorderRadius.circular(AppShape.r(22)),
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppShape.r(22)),
            gradient: AppColors.haze(color, AppColors.surface),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppShape.r(22)),
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
