import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../core/images.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/rollout_checklist.dart';
import '../widgets/image_pickers.dart';
import '../widgets/media_tile.dart';
import '../widgets/release_timing.dart';
import '../widgets/stored_image.dart';
import 'album_detail_screen.dart';
import 'calendar_screen.dart';
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

  /// Tours a live album can come from (docs K146).
  List<LiveTourView> _liveTours = const [];
  CompilationBlock? _hitsBlock = CompilationBlock.tooEarly;
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
    final liveTours = await career.read(Cmd.liveAlbumTours());
    final hitsBlock = await career.read(Cmd.compilationBlock());
    if (mounted) {
      setState(() {
        _hitsBlock = hitsBlock;
        _liveTours = liveTours;
        _songs = songs;
        _albums = albums;
        _scheduled = scheduled;
        _rivals = rivals;
      });
    }
  }

  /// Picks hits and new songs and puts out a greatest hits album (K161).
  Future<void> _greatestHits() async {
    final l = context.l10n;
    final career = context.careerRead;
    final hits = await career.read(Cmd.compilationCandidates());
    if (!mounted) return;
    final fresh = [
      for (final s in _songs)
        if (s.inVault &&
            s.scheduledSingleWeek < 0 &&
            s.scheduledAlbumWeek < 0 &&
            s.albumId < 0)
          s
    ];
    if (fresh.isEmpty) {
      showInfo(context, l.ghNeedNew);
      return;
    }
    final name = TextEditingController(text: l.ghDefaultTitle);
    final picked = await showModalBottomSheet<(String, List<int>, List<int>)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        // The biggest hits are ticked to start with.
        final chosen = [
          for (final h in hits.take(Compilations.minHits + 2)) h.songId
        ];
        final added = <int>[];
        return StatefulBuilder(
          builder: (c, set) => Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(c).size.height * 0.9),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(l.ghTitle,
                        style: Theme.of(c).textTheme.titleLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                        l.ghHint(Compilations.minHits, Compilations.maxHits,
                            Compilations.minNew, Compilations.maxNew),
                        style: Theme.of(c).textTheme.bodySmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: TextField(
                      controller: name,
                      maxLength: 60,
                      decoration: InputDecoration(labelText: l.rerecordName),
                    ),
                  ),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      ListTile(
                          dense: true,
                          title: Text(l.ghNew(added.length),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      for (final s in fresh)
                        CheckboxListTile(
                          value: added.contains(s.id),
                          onChanged: !added.contains(s.id) &&
                                  added.length >= Compilations.maxNew
                              ? null
                              : (v) => set(() => v == true
                                  ? added.add(s.id)
                                  : added.remove(s.id)),
                          title: Text(s.title),
                          subtitle: Text(context.fmt.songGrade(s)),
                        ),
                      ListTile(
                          dense: true,
                          title: Text(l.ghHits(chosen.length),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      for (final h in hits)
                        CheckboxListTile(
                          value: chosen.contains(h.songId),
                          onChanged: !chosen.contains(h.songId) &&
                                  chosen.length >= Compilations.maxHits
                              ? null
                              : (v) => set(() => v == true
                                  ? chosen.add(h.songId)
                                  : chosen.remove(h.songId)),
                          title: Text(h.title),
                          subtitle: Text(h.peak > 0
                              ? l.ghPeak(h.peak, h.year)
                              : l.ghNoPeak(h.year)),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: chosen.length < Compilations.minHits ||
                              added.length < Compilations.minNew
                          ? null
                          : () => Navigator.pop(
                              c, (name.text, List.of(chosen), List.of(added))),
                      child: Text(l.ghGo(chosen.length, added.length)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
    // Not disposed here: the closing animation still builds with it, and
    // nothing holds it once the route is gone (K188).
    if (picked == null || !mounted) return;
    final campaign = await pickCampaign(context, career);
    if (campaign == null || !mounted) return;
    try {
      final al = await career.act(Cmd.releaseGreatestHits(
          picked.$1, picked.$2, picked.$3, campaign));
      if (mounted) showInfo(context, l.albumReleased(al.title));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Picks songs from the tour's set and puts out a live album (K146).
  Future<void> _liveAlbum(LiveTourView t) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final songs = [
      for (final s in _songs)
        if (s.releasedWeek >= 0 && s.liveOf < 0) s
    ];
    final name = TextEditingController(
        text: l.liveDefaultTitle(t.name.isEmpty ? career.player.name : t.name));
    final picked = await showModalBottomSheet<(String, List<int>)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        final chosen = <int>[];
        return StatefulBuilder(
          builder: (c, set) => Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(c).size.height * 0.85),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(l.liveTitle,
                        style: Theme.of(c).textTheme.titleLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                        l.liveHint(
                            LiveAlbums.minTracks,
                            LiveAlbums.maxTracks,
                            fmt.money(LiveAlbums.costPerTrackCents),
                            LiveAlbums.energyPerTrack.round()),
                        style: Theme.of(c).textTheme.bodySmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: TextField(
                      controller: name,
                      maxLength: 60,
                      decoration: InputDecoration(labelText: l.rerecordName),
                    ),
                  ),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final s in songs)
                        CheckboxListTile(
                          value: chosen.contains(s.id),
                          onChanged: !chosen.contains(s.id) &&
                                  chosen.length >= LiveAlbums.maxTracks
                              ? null
                              : (v) => set(() => v == true
                                  ? chosen.add(s.id)
                                  : chosen.remove(s.id)),
                          title: Text(s.title),
                          subtitle: Text(fmt.songGrade(s)),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: chosen.length < LiveAlbums.minTracks
                          ? null
                          : () => Navigator.pop(c, (name.text, List.of(chosen))),
                      child: Text(l.liveGo(chosen.length)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
    // Not disposed here: the closing animation still builds with it, and
    // nothing holds it once the route is gone (K188).
    if (picked == null || !mounted) return;
    final campaign = await pickCampaign(context, career,
        extraCents: LiveAlbums.costCents(picked.$2.length));
    if (campaign == null || !mounted) return;
    try {
      final al = await career.act(
          Cmd.releaseLiveAlbum(t.startWeek, picked.$1, picked.$2, campaign));
      if (mounted) showInfo(context, l.albumReleased(al.title));
    } catch (e) {
      if (mounted) showError(context, e);
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
        // A greatest hits album (docs K161), and why not yet.
        if (_hitsBlock != CompilationBlock.tooEarly) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: career.busy || _hitsBlock != null ? null : _greatestHits,
            icon: const Icon(Icons.star_rounded),
            label: Text(l.ghButton),
          ),
          if (_hitsBlock case final b?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  switch (b) {
                    CompilationBlock.tooEarly =>
                      l.ghTooEarly(Compilations.minYears),
                    CompilationBlock.tooSoon =>
                      l.ghTooSoon(Compilations.gapYears),
                    CompilationBlock.fewSongs =>
                      l.ghFewSongs(Compilations.minHits),
                  },
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
        ],
        // A live album from a finished tour (docs K146).
        for (final t in _liveTours) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: career.busy ? null : () => _liveAlbum(t),
            icon: const Icon(Icons.mic_external_on_outlined),
            label: Text(l.liveButton(t.name.isEmpty ? l.liveTourFallback : t.name,
                t.shows)),
          ),
        ],
        // Picking a week: the next six months at a glance (docs K177).
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CalendarScreen(state: career))),
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(l.calTitle),
        ),
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
                      '${s.isSurprise ? l.announceSurprise : s.announced ? '${l.statusAnnounced} · ${l.buzzLabel} ${(100 * s.buzz / s.buzzCap).round()}%${s.preSaves >= 1 ? ' · ${l.preSavesValue(fmt.compact(s.preSaves))}' : ''}${s.preOrders >= 1 ? ' · ${l.preOrdersValue(fmt.compact(s.preOrders))}' : ''}' : l.announceDate(fmt.week(s.announceWeek))}',
                  onTap: career.busy ? null : () => _editScheduled(s),
                ),
              // How the album's rollout stands (docs K165).
              for (final s in dated)
                if (s.rollout case final r?) ...[
                  const SizedBox(height: 4),
                  Text('${s.title} · ${l.rolloutTitle(r.doneCount, r.count)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                      l.rolloutHint(
                          (Rollouts.fullHype * 100).round()),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  RolloutChecklist(status: r),
                ],
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
                          '${a.metascore >= 0 ? ' · ${l.metascoreLabel} ${a.metascore}' : ''} · '
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
  // Playlist pitch and autoplay before it comes out (docs K101).
  var pitch = false, autoplay = song.autoplayLevel;
  if (song.canPitch || song.autoplayOpen) {
    final picked = await pickStreamingOptions(context, song);
    if (picked == null || !context.mounted) return false;
    (pitch, autoplay) = picked;
  }
  try {
    if (pitch) await career.act(Cmd.pitchSong(song.id));
    if (autoplay != song.autoplayLevel) {
      await career.act(Cmd.setAutoplayLevel(song.id, autoplay));
    }
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

/// Pitch to the playlist editors and autoplay, chosen while putting a song
/// out (docs K101). Null when cancelled.
Future<(bool, AutoplayLevel)?> pickStreamingOptions(
    BuildContext context, SongView song) {
  final l = context.l10n;
  var pitch = song.canPitch;
  var autoplay = song.autoplay
      ? song.autoplayLevel
      : song.autoplayOpen
          ? AutoplayLevel.standard
          : AutoplayLevel.off;
  return showModalBottomSheet<(bool, AutoplayLevel)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.streamingSection,
                    style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(l.streamingStepHint,
                    style: Theme.of(c).textTheme.bodySmall),
                if (song.canPitch)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: pitch,
                    onChanged: (v) => set(() => pitch = v),
                    title: Text(l.pitchSong,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(l.pitchHint),
                  ),
                if (song.autoplayOpen) ...[
                  const SizedBox(height: 8),
                  AutoplayLevelPicker(
                      value: autoplay,
                      onChanged: (v) => set(() => autoplay = v)),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(c, (pitch, autoplay)),
                  child: Text(l.continueLabel),
                ),
              ]),
        ),
      ),
    ),
  );
}

/// Campaign choice with prices (docs/game-design.md §9).
Future<Campaign?> pickCampaign(BuildContext context, CareerState career,
    {int extraCents = 0, Widget? header, List<int>? costs}) {
  final l = context.l10n;
  final fmt = context.fmt;
  final money = career.player.moneyCents;
  int cost(Campaign k) => (costs ?? career.player.campaignCosts)[k.index];
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
            enabled: k.index <= career.player.maxCampaign.index &&
                cost(k) + extraCents <= money,
            leading: Icon(switch (k) {
              Campaign.none => Icons.volume_off_outlined,
              Campaign.standard => Icons.campaign_outlined,
              Campaign.intensive => Icons.rocket_launch_outlined,
              Campaign.global => Icons.public,
            }),
            title: Text(fmt.campaign(k)),
            subtitle: Text(k.index > career.player.maxCampaign.index
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
        for (final r in RadioPush.ladder)
          ListTile(
            enabled: r.rank <= p.maxRadioPush.rank &&
                cost(r) + extraCents <= p.moneyCents,
            leading: Icon(radioIcon(r)),
            title: Text(fmt.radioPush(r)),
            subtitle: Text(r.rank > p.maxRadioPush.rank
                ? l.radioLockedHint
                : fmt.radioPushHint(r)),
            trailing: Text(fmt.money(cost(r))),
            onTap: () => Navigator.pop(c, r),
          ),
        const SizedBox(height: 8),
      ])),
    ),
  );
}

IconData radioIcon(RadioPush r) => switch (r) {
      RadioPush.none => Icons.radio_outlined,
      RadioPush.light => Icons.radio,
      RadioPush.standard => Icons.radio,
      RadioPush.heavy => Icons.cell_tower_rounded,
      RadioPush.blitz => Icons.campaign_rounded,
    };

/// The autoplay levels as chips (docs K128).
class AutoplayLevelPicker extends StatelessWidget {
  const AutoplayLevelPicker(
      {super.key, required this.value, required this.onChanged});
  final AutoplayLevel value;
  final ValueChanged<AutoplayLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.autoplayLabel,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in AutoplayLevel.ladder)
          ChoiceChip(
            label: Text(fmt.autoplayLevel(a)),
            selected: a == value,
            onSelected: (_) => onChanged(a),
          ),
      ]),
      const SizedBox(height: 6),
      Text(fmt.autoplayTerms(value),
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
    ]);
  }
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

  /// Picked songs in tracklist order (docs K133).
  final List<int> _picked = [];
  AlbumType _type = AlbumType.album;

  /// Extra editions after the standard one (docs K46).
  final List<_Edition> _extras = [];

  /// Cover picked before the album exists; saved once it is released.
  String? _cover;
  bool _stagger = true;

  /// The second streaming service's offer for an exclusive (docs K135).
  int? _exclusiveOffer;
  bool _exclusive = false;

  /// Weeks the album stays off streaming (docs K174), and whether it can.
  int _window = 0;
  bool _canWindow = false;

  /// Album bundles on offer and the one picked (docs K144).
  Map<AlbumBundle, double> _bundles = const {};
  AlbumBundle _bundle = AlbumBundle.none;

  /// Joint album partners and the one picked (docs K150).
  List<JointPartnerView> _partners = const [];
  int _partner = -1;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.exclusiveOffer()).then((fee) {
      if (mounted) setState(() => _exclusiveOffer = fee);
    });
    widget.state.read(Cmd.canWindow()).then((ok) {
      if (mounted) setState(() => _canWindow = ok);
    });
    widget.state.read(Cmd.bundleOptions()).then((b) {
      if (mounted) setState(() => _bundles = b);
    });
    widget.state.read(Cmd.jointPartners()).then((p) {
      if (mounted) setState(() => _partners = p);
    });
  }

  AlbumBundle get _goBundle => _bundles.containsKey(_bundle) &&
          (_type == AlbumType.album || _type == AlbumType.ep)
      ? _bundle
      : AlbumBundle.none;

  bool get _goExclusive =>
      _exclusive && _exclusiveOffer != null && _type == AlbumType.album;

  bool get _windowFits =>
      _canWindow && (_type == AlbumType.album || _type == AlbumType.ep);

  int get _goWindow => _windowFits && !_goExclusive ? _window : 0;

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

  List<int> get _ordered => List.of(_picked);

  void _move(int i, int by) => setState(() {
        final id = _picked.removeAt(i);
        _picked.insert(i + by, id);
      });

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
          exclusive: _goExclusive,
          windowWeeks: _goWindow,
          bundle: _goBundle,
          partnerId: _type == AlbumType.mixtape ? -1 : _partner,
        ));
        _saveCovers(images, ImageStore.albumKey(album.id));
        if (!mounted) return;
        Navigator.pop(context);
        showInfo(context, l.albumReleased(album.title));
      } else if (_partner >= 0 && _type != AlbumType.mixtape) {
        // A joint album comes out now (docs K150).
        showInfo(context, l.jointNowOnly);
        return;
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
          exclusive: _goExclusive,
          windowWeeks: _goWindow,
          bundle: _goBundle,
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
          // A streaming exclusive (docs K135).
          if (_exclusiveOffer != null && _type == AlbumType.album) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _exclusive,
              onChanged: (v) => setState(() {
                _exclusive = v;
                if (v) _window = 0;
              }),
              title: Text(l.exclusiveTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(l.exclusiveHint(
                  fmt.money(_exclusiveOffer!), StreamingTools.exclusiveWeeks)),
            ),
          ],
          // Held off streaming at first (docs K174).
          if (_windowFits) ...[
            const SizedBox(height: 12),
            Text(l.windowTitle,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                l.windowHint(
                    ((StreamWindows.buyLift(year) - 1) * 100).round()),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final wk in [0, ...StreamWindows.weeks])
                ChoiceChip(
                  label: Text(wk == 0 ? l.windowNone : l.windowWeeks(wk)),
                  selected: _window == wk,
                  onSelected: (_) => setState(() {
                    _window = wk;
                    if (wk > 0) _exclusive = false;
                  }),
                ),
            ]),
          ],
          // A joint album with a rival (docs K150).
          if (_partners.isNotEmpty && _type != AlbumType.mixtape) ...[
            const SizedBox(height: 12),
            Text(l.jointTitle,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.jointHint,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text(l.jointNone),
                selected: _partner < 0,
                onSelected: (_) => setState(() => _partner = -1),
              ),
              for (final p in _partners.take(10))
                ChoiceChip(
                  label: Text('${p.name} · ${fmt.money(p.feeCents)}'),
                  selected: _partner == p.artistId,
                  onSelected: (_) => setState(() => _partner = p.artistId),
                ),
            ]),
          ],
          // Album bundles while the charts count them (docs K144).
          if (_bundles.isNotEmpty &&
              (_type == AlbumType.album || _type == AlbumType.ep)) ...[
            const SizedBox(height: 12),
            Text(l.bundleTitle,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.bundleHint,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text(l.bundleNone),
                selected: _bundle == AlbumBundle.none,
                onSelected: (_) => setState(() => _bundle = AlbumBundle.none),
              ),
              for (final e in _bundles.entries)
                ChoiceChip(
                  label: Text(l.bundleOption(
                      fmt.bundle(e.key), fmt.compact(e.value))),
                  selected: _bundle == e.key,
                  onSelected: (_) => setState(() => _bundle = e.key),
                ),
            ]),
          ],
          // The order the songs play in (docs K133).
          if (_picked.length > 1) ...[
            const SizedBox(height: 12),
            Section(
              title: l.tracklistTitle,
              icon: Icons.format_list_numbered_rounded,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.tracklistHint,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    for (final (i, id) in _picked.indexed)
                      Row(children: [
                        SizedBox(
                          width: 28,
                          child: Text('${i + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Expanded(
                          child: Text(
                              widget.songs.firstWhere((s) => s.id == id).title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                            '${(Simulator.trackPositionFactor(i, _picked.length) * 100).round()}%',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: l.moveUp,
                          onPressed: i == 0 ? null : () => _move(i, -1),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: l.moveDown,
                          onPressed: i == _picked.length - 1
                              ? null
                              : () => _move(i, 1),
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                      ]),
                  ]),
            ),
          ],
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
                    : storedImage(cover, fit: BoxFit.cover),
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
