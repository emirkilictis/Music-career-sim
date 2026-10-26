import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game/game.dart' show GameException;
import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../core/images.dart';
import '../widgets/art.dart';
import '../widgets/brand.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import 'game_shell.dart';
import 'new_career_screen.dart';
import 'settings_screen.dart';

/// Start screen: the list of careers (save slots).
class SlotsScreen extends StatefulWidget {
  const SlotsScreen({super.key});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  List<Map<String, Object?>>? _slots;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots = await context.controller.exec(Cmd.listSlots());
    if (mounted) setState(() => _slots = slots);
  }

  Future<void> _open(String slotId) async {
    final controller = context.controller;
    try {
      await controller.exec(Cmd.resume(slotId));
      if (!mounted) return;
      await openCareer(context, CareerState(controller));
    } catch (e, st) {
      // A rule the game enforces reads as usual; anything else is a save
      // that does not load, shown in full so it can be reported.
      if (!mounted) return;
      if (e is GameException) {
        showError(context, e);
      } else {
        final where = st.toString().split('\n').take(6).join('\n');
        await _loadFailed('$e\n$where');
      }
    }
    _load();
  }

  Future<void> _loadFailed(String detail) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.loadFailedTitle),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.loadFailedBody),
                const SizedBox(height: 12),
                SelectableText(detail,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: detail));
              showInfo(context, l.copied);
            },
            child: Text(l.copy),
          ),
          FilledButton(onPressed: () => Navigator.pop(d), child: Text(l.ok)),
        ],
      ),
    );
  }

  Future<void> _delete(String slotId, String name) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteCareerTitle),
        content: Text(l.deleteCareerBody(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.controller.exec(Cmd.deleteSlot(slotId));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final slots = _slots;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        titleSpacing: 16,
        // The game's own mark and name (docs K214).
        title: Row(children: [
          const BrandMark(size: 48),
          const SizedBox(width: 12),
          Flexible(
              child: Semantics(
                  label: l.appTitle, child: const BrandWordmark(size: 25))),
        ]),
        actions: [
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.newCareer),
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NewCareerScreen()));
          _load();
        },
      ),
      body: slots == null
          ? const Center(child: CircularProgressIndicator())
          : slots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const BrandMark(size: 96),
                      const SizedBox(height: 20),
                      Text(l.noCareersTitle,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(l.noCareersBody, textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: slots.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(l.brandTagline,
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 14)),
                      );
                    }
                    final s = slots[i - 1];
                    final id = s['slotId'] as String;
                    final name = s['artistName'] as String? ?? '?';
                    final fame = (s['fame'] as num?)?.toDouble() ?? 0;
                    final fans = (s['coreFans'] as num?)?.toDouble() ?? 0;
                    final album = s['lastAlbumId'] as int? ?? -1;
                    final hit = s['hitTitle'] as String?;
                    final albumTitle = s['lastAlbumTitle'] as String?;
                    final cover = album < 0
                        ? null
                        : context.imagesRead
                            .pathIn(id, ImageStore.albumKey(album));
                    // The biggest hit, else the latest album (E9).
                    final story = hit != null
                        ? l.biggestHit(hit, s['hitPeak'] as int? ?? 0)
                        : albumTitle != null
                            ? l.latestAlbum(albumTitle)
                            : null;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _open(id),
                        onLongPress: () => _delete(id, name),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                          child: Row(children: [
                            album < 0
                                ? ArtistAvatar(
                                    name: name, seed: id.hashCode, size: 64)
                                : ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppShape.r(10)),
                                    child: cover != null
                                        ? Image.file(File(cover),
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            cacheWidth: 192)
                                        : CoverArt(
                                            seed: albumCoverSeed(album),
                                            size: 64),
                                  ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${fmt.weekOf(s['weekOfYear'] as int? ?? 1, s['year'] as int? ?? 0)}'
                                        ' · ${l.fameValue(fmt.percent(fame))}'
                                        ' · ${l.fansValue(fmt.compact(fans))}',
                                        style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 13)),
                                    if (story != null) ...[
                                      const SizedBox(height: 4),
                                      Text(story,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ]),
                            ),
                            PopupMenuButton<int>(
                              tooltip: l.careerMenu,
                              icon: Icon(Icons.more_vert_rounded,
                                  color: AppColors.textMuted),
                              onSelected: (_) => _delete(id, name),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 0,
                                  child: Row(children: [
                                    Icon(Icons.delete_outline_rounded,
                                        color: AppColors.coral),
                                    const SizedBox(width: 12),
                                    Text(l.delete),
                                  ]),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Pushes the game for an opened career; closes the save when leaving.
Future<void> openCareer(BuildContext context, CareerState state) async {
  await state.refresh();
  if (!context.mounted) return;
  final images = context.imagesRead..open(state.slotId!);
  await _relinkScheduledCovers(state, images);
  if (!context.mounted) return;
  state.onScheduledAlbumOut = (scheduleId, albumId) => images.adoptWithEditions(
      ImageStore.scheduledKey(scheduleId), ImageStore.albumKey(albumId));
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GameShell(state: state)),
  );
  images.close();
  await state.controller.exec(Cmd.closeCareer());
}

/// Covers chosen for scheduled albums that older versions left under the
/// schedule's name: link each to the album that came out of it (by its
/// schedule id, or for older saves the first album released after it was
/// scheduled that has no cover yet).
Future<void> _relinkScheduledCovers(
    CareerState state, ImageStore images) async {
  final orphans = images.scheduledCoverIds;
  if (orphans.isEmpty) return;
  final pending = {for (final s in await state.read(Cmd.scheduled())) s.id};
  final albums = [...await state.read(Cmd.albums())]
    ..sort((a, b) => a.releaseWeek.compareTo(b.releaseWeek));
  for (final sid in orphans..sort()) {
    if (pending.contains(sid)) continue;
    final album = albums.where((a) => a.scheduleId == sid).firstOrNull ??
        albums
            .where((a) =>
                a.scheduleId < 0 &&
                a.releaseWeek >= sid ~/ 64 &&
                images.albumCover(a.id) == null)
            .firstOrNull;
    if (album == null) continue;
    images.adoptWithEditions(
        ImageStore.scheduledKey(sid), ImageStore.albumKey(album.id));
  }
}
