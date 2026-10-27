import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/images.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/image_pickers.dart';

/// A new version of an album after it came out (docs K225): its name, its
/// own cover, a format and bonus tracks from the vault. An [anniversary]
/// edition (docs K226) is remastered too and named for the anniversary.
/// Pops with true when the version came out.
class AlbumVersionScreen extends StatefulWidget {
  const AlbumVersionScreen(
      {super.key,
      required this.state,
      required this.album,
      this.anniversary = false});
  final CareerState state;
  final AlbumView album;
  final bool anniversary;

  /// Opens the screen; true when a version came out.
  static Future<bool> open(
      BuildContext context, CareerState state, AlbumView album,
      {bool anniversary = false}) async {
    final out = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => AlbumVersionScreen(
            state: state, album: album, anniversary: anniversary)));
    return out ?? false;
  }

  @override
  State<AlbumVersionScreen> createState() => _AlbumVersionScreenState();
}

class _AlbumVersionScreenState extends State<AlbumVersionScreen> {
  /// Names real versions go by.
  static const _suggestions = [
    'Deluxe',
    'Platinum Edition',
    '3am Edition',
    'Til Dawn Edition',
    'Complete Edition',
    'The Anthology',
    'Extended',
  ];

  late final TextEditingController _name;
  late bool _anniversary = widget.anniversary;
  EditionFormat _format = EditionFormat.digital;
  final _picked = <int>[];
  List<SongView>? _vault;
  bool _busy = false;
  bool _released = false;

  AlbumView get _a => widget.album;

  /// The edition (and cover) index the version will have.
  int get _edition => _a.variantWeeks.length;
  String get _coverKey =>
      ImageStore.editionKey(ImageStore.albumKey(_a.id), _edition);
  bool get _canAnniversary => _a.anniversaryDue > 0;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    widget.state.read(Cmd.vault()).then((v) {
      if (mounted) setState(() => _vault = v);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty && _anniversary) {
      _name.text = context.l10n.versionAnniversaryName(_a.anniversaryDue);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  int get _cost => AlbumVersions.costCents(_format, anniversary: _anniversary);

  /// Leaving without releasing drops a cover picked for it.
  void _dropCover() {
    if (!_released) context.imagesRead.remove(_coverKey);
  }

  Future<void> _release() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showInfo(context, l.versionNameNeeded, icon: Icons.edit_outlined);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.state.act(Cmd.releaseAlbumVersion(_a.id,
          name: name,
          songIds: List.of(_picked),
          format: _format,
          anniversary: _anniversary && _canAnniversary));
      _released = true;
      if (!mounted) return;
      showInfo(context, l.versionOut(name),
          icon: Icons.library_add_check_rounded);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final year = GameTime.yearOf(widget.state.week);
    final ownCover = context.images.path(_coverKey) != null;
    final vault = _vault;
    return PopScope(
      onPopInvokedWithResult: (_, __) => _dropCover(),
      child: Scaffold(
        appBar: AppBar(
            title: Text(_anniversary
                ? l.versionAnniversary(_a.anniversaryDue)
                : l.versionTitle)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(l.versionIntro(_a.title),
                style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            // Its cover: tapped to choose one.
            InkWell(
              onTap: () => editImage(context, _coverKey),
              borderRadius: BorderRadius.circular(AppShape.r(12)),
              child: Row(children: [
                CoverArt(
                    seed: albumCoverSeed(_a.id) + _edition,
                    albumId: _a.id,
                    imageKey: _coverKey,
                    size: 96),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.versionCover,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(ownCover ? l.versionCoverSet : l.versionCoverHint,
                            style: TextStyle(color: AppColors.textMuted)),
                      ]),
                ),
                const Icon(Icons.add_photo_alternate_outlined),
              ]),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              maxLength: GameSession.maxVersionName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l.versionName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (_canAnniversary)
                ActionChip(
                  label: Text(l.versionAnniversaryName(_a.anniversaryDue)),
                  onPressed: () => setState(() =>
                      _name.text = l.versionAnniversaryName(_a.anniversaryDue)),
                ),
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _name.text = s),
                ),
            ]),
            if (_canAnniversary) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _anniversary,
                onChanged: (v) => setState(() => _anniversary = v),
                title: Text(l.versionAnniversary(_a.anniversaryDue),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(l.versionAnniversaryHint(
                    fmt.money(Anniversaries.remasterCents))),
              ),
            ],
            const SizedBox(height: 12),
            Section(
              title: l.versionFormat,
              icon: Icons.album_outlined,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.versionFormatHint,
                        style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final f in const [
                        EditionFormat.digital,
                        EditionFormat.deluxe,
                        EditionFormat.cd,
                        EditionFormat.vinyl,
                        EditionFormat.cassette,
                        EditionFormat.signed,
                      ])
                        ChoiceChip(
                          label: Text('${fmt.editionFormat(f)} · '
                              '${fmt.money(f.costCents)}'),
                          tooltip: fmt.formatAppeal(f, year),
                          selected: f == _format,
                          onSelected: (_) => setState(() => _format = f),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(fmt.formatAppeal(_format, year),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ]),
            ),
            const SizedBox(height: 12),
            Section(
              title: l.versionTracks(_picked.length, AlbumVersions.maxTracks),
              icon: Icons.queue_music_rounded,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.versionTracksHint,
                        style: TextStyle(color: AppColors.textMuted)),
                    if (vault == null)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (vault.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l.versionTracksEmpty),
                      )
                    else
                      for (final s in vault)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _picked.contains(s.id),
                          onChanged: !_picked.contains(s.id) &&
                                  _picked.length >= AlbumVersions.maxTracks
                              ? null
                              : (v) => setState(() => v == true
                                  ? _picked.add(s.id)
                                  : _picked.remove(s.id)),
                          title: Text(s.title),
                          subtitle: Text(fmt.songGrade(s)),
                        ),
                  ]),
            ),
            if (_a.versionsRecent > 0) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: _a.versionsRecent >= 2
                        ? AppColors.coral
                        : AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_a.versionsRecent >= 2
                      ? l.versionTired
                      : l.versionRecent),
                ),
              ]),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy || _name.text.trim().isEmpty ? null : _release,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(l.versionRelease(fmt.money(_cost))),
            ),
          ],
        ),
      ),
    );
  }
}
