import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game/game.dart' show GameException;
import 'package:file_selector/file_selector.dart' show openFile;

import '../boot/boot.dart'
    show dismissHomeScreenTip, homeScreenTipDue, inAppBrowser;
import '../core/backup.dart';
import '../core/platform_files.dart';
import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../core/images.dart';
import '../widgets/art.dart';
import '../widgets/brand.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import '../widgets/stored_image.dart';
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
  bool _homeTip = homeScreenTipDue();

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

  /// Runs [work] behind a small "please wait" dialog.
  Future<T> _busy<T>(String text, Future<T> Function() work) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const SizedBox.square(
                dimension: 28, child: CircularProgressIndicator()),
            const SizedBox(width: 20),
            Expanded(child: Text(text)),
          ]),
        ),
      ),
    );
    try {
      return await work();
    } finally {
      nav.pop();
    }
  }

  /// A career as a backup file (docs K219).
  Future<void> _backup(String slotId, String name) async {
    final l = context.l10n;
    final controller = context.controller;
    final images = context.imagesRead;
    final Uint8List file;
    try {
      file = await _busy(l.backingUp, () async {
        final db = await controller.exec(Cmd.backupSlot(slotId));
        return CareerBackup(db, images.imagesOf(slotId)).encode();
      });
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    // Saving waits for a tap: a browser only downloads on one.
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.backupCareer),
        content: Text(l.backupReady),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l.cancel)),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: Text(l.backupSave),
            onPressed: () {
              saveFileAs(file, CareerBackup.fileName(name));
              Navigator.pop(d);
            },
          ),
        ],
      ),
    );
  }

  /// Adds the career in a backup file the player picks (docs K219).
  Future<void> _restore() async {
    final l = context.l10n;
    final controller = context.controller;
    final images = context.imagesRead;
    // Which file, and where: phones offer photos first (F109).
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.settings_backup_restore_rounded),
        title: Text(l.restoreBackup),
        content: Text(l.restoreHow),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.restoreChoose)),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final picked = await openFile();
    if (picked == null || !mounted) return;
    try {
      final raw = await picked.readAsBytes();
      final slotId = await _busy(l.restoring, () async {
        final CareerBackup backup;
        try {
          backup = await CareerBackup.decode(raw);
        } on FormatException catch (e) {
          throw GameException('badBackup', e.message);
        }
        final id = await controller.exec(Cmd.restoreSlot(backup.database));
        images.addImages(id, backup.images);
        return id;
      });
      await _load();
      final name = _slots?.firstWhere((s) => s['slotId'] == slotId,
          orElse: () => const {})['artistName'] as String?;
      if (mounted) showInfo(context, l.restoredCareer(name ?? ''));
    } catch (e) {
      if (mounted) showError(context, e);
    }
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
            tooltip: l.restoreBackup,
            icon: const Icon(Icons.settings_backup_restore_rounded),
            onPressed: _restore,
          ),
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
      body: _withNotice(
        slots == null
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
                        const SizedBox(height: 16),
                        // A backup from another browser or device (K219).
                        TextButton.icon(
                          icon:
                              const Icon(Icons.settings_backup_restore_rounded),
                          label: Text(l.restoreBackup),
                          onPressed: _restore,
                        ),
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
                                      name: name,
                                      // The same face as in the game.
                                      seed: s['artistId'] as int? ?? 0,
                                      size: 64)
                                  : ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(AppShape.r(10)),
                                      child: cover != null
                                          ? storedImage(cover,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                onSelected: (v) => v == 1
                                    ? _backup(id, name)
                                    : _delete(id, name),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 1,
                                    child: Row(children: [
                                      const Icon(Icons.save_alt_rounded),
                                      const SizedBox(width: 12),
                                      Text(l.backupCareer),
                                    ]),
                                  ),
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
      ),
    );
  }

  /// Notes on top of the list (docs K218, K219): in an app's own browser
  /// (X, Instagram…), which may wipe the saves when closed; on an iPhone
  /// browser, the Home Screen tip.
  Widget _withNotice(Widget body) {
    final l = context.l10n;
    final inApp = inAppBrowser();
    if (!inApp && !_homeTip) return body;
    Widget note(IconData icon, Color color, String text,
            {VoidCallback? close}) =>
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: EdgeInsets.fromLTRB(12, 12, close == null ? 12 : 0, 12),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
            if (close != null)
              IconButton(
                tooltip: l.close,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: close,
              ),
          ]),
        );
    return Column(children: [
      if (inApp)
        note(Icons.warning_amber_rounded, AppColors.coral, l.inAppBrowserNotice)
      else
        note(Icons.add_to_home_screen_rounded, AppColors.lilac, l.homeScreenTip,
            close: () {
          dismissHomeScreenTip();
          setState(() => _homeTip = false);
        }),
      Expanded(child: body),
    ]);
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
