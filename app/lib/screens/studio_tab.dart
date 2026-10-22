import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/media_tile.dart';
import 'game_shell.dart' show pushInCareer;
import 'song_detail_screen.dart';
import 'song_market_screen.dart';

/// Studio: write a song (one screen, smart defaults) and see the vault.
class StudioTab extends StatefulWidget {
  const StudioTab({super.key});

  @override
  State<StudioTab> createState() => _StudioTabState();
}

class _StudioTabState extends State<StudioTab> {
  final _title = TextEditingController();
  List<int>? _genres;

  /// Writing a holiday song (docs K136).
  bool _holiday = false;
  BudgetTier _budget = BudgetTier.low;
  int? _producer;
  int? _cowriter;
  List<CollaboratorView> _producers = const [];
  List<CollaboratorView> _writers = const [];
  List<SongView> _vault = const [];
  int _loadedRevision = -1;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

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
    final producers =
        await career.read(Cmd.collaborators(CollaboratorRole.producer));
    final writers =
        await career.read(Cmd.collaborators(CollaboratorRole.songwriter));
    final vault = await career.read(Cmd.vault());
    if (!mounted) return;
    setState(() {
      _producers = producers;
      _writers = writers;
      _vault = vault;
    });
  }

  /// Genres in a sheet (feedback E2): 21 chips stay out of the way.
  Future<void> _pickGenres(List<int> current) async {
    final l = context.l10n;
    final fmt = context.fmt;
    var picked = [...current];
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.genresUpTo(maxSongGenres),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  for (var g = 0; g < genreNames.length; g++)
                    FilterChip(
                      label: Text(picked.contains(g)
                          ? '${picked.indexOf(g) + 1}. ${fmt.genre(g)}'
                          : fmt.genre(g)),
                      selected: picked.contains(g),
                      onSelected: (on) => set(() {
                        if (on && picked.length < maxSongGenres) picked.add(g);
                        if (!on && picked.length > 1) picked.remove(g);
                        picked = [...picked];
                      }),
                    ),
                ]),
                const SizedBox(height: 14),
                FilledButton(
                    onPressed: () => Navigator.pop(c, picked),
                    child: Text(l.done)),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _genres = result);
  }

  /// Producer / co-writer list in a sheet, best first; locked ones say how
  /// many fans they want.
  Future<void> _pickCollaborator(String title, List<CollaboratorView> list,
      int? current, void Function(int?) set) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final picked = await showModalBottomSheet<(int?,)>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (c, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              selected: current == null,
              title: Text(l.nobody),
              onTap: () => Navigator.pop(c, (null,)),
            ),
            for (final x in list)
              ListTile(
                enabled: x.available,
                selected: current == x.id,
                title: Text(x.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(x.available
                    ? '${fmt.genre(x.genre)} · ${fmt.money(x.feeCents)}'
                    : l.needsFans(fmt.compact(x.requiredFans))),
                trailing: SizedBox(
                  width: 92,
                  child: Row(children: [
                    Expanded(child: PillBar(value: x.skill / 100, height: 6)),
                    const SizedBox(width: 8),
                    Text('${x.skill.round()}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
                onTap: () => Navigator.pop(c, (x.id,)),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => set(picked.$1));
  }

  int _cost() {
    int fee(List<CollaboratorView> list, int? id) =>
        id == null ? 0 : list.firstWhere((c) => c.id == id).feeCents;
    return Actions.budgetCostCents(_budget) +
        fee(_producers, _producer) +
        fee(_writers, _cowriter);
  }

  Future<void> _write() async {
    final career = context.careerRead;
    final l = context.l10n;
    final fmt = context.fmt;
    final title = _title.text.trim();
    // Warn before the song that ends in burnout (playtest finding A3).
    if (career.player.creativeEnergy <= Actions.energyCostPerSong) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.burnoutConfirmTitle),
          content: Text(l.burnoutConfirmBody(Actions.burnoutWeeks)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l.writeAnyway)),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    try {
      final song = await career.act(Cmd.writeSong(
        producerId: _producer,
        cowriterId: _cowriter,
        budget: _budget,
        genres: _genres ?? [career.player.genre],
        title: title.isEmpty ? null : title,
        holiday: _holiday,
      ));
      _title.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.songRecorded),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('“${song.title}”',
                style: Theme.of(c).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(fmt.songGrade(song),
                style: Theme.of(c)
                    .textTheme
                    .displayMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(l.teamEstimate, textAlign: TextAlign.center),
            Text(l.gradeRevealHint,
                textAlign: TextAlign.center,
                style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(fmt.genres(song.genres)),
          ]),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.ok)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    final genres = _genres ?? [p.genre];
    final canWrite = p.canWrite;

    CollaboratorView? find(List<CollaboratorView> list, int? id) =>
        id == null ? null : list.where((c) => c.id == id).firstOrNull;
    String teamValue(CollaboratorView? c) =>
        c == null ? l.nobody : '${c.name} · ${l.skillValue(c.skill.round())}';
    String? teamDetail(CollaboratorView? c) =>
        c == null ? null : '${fmt.genre(c.genre)} · ${fmt.money(c.feeCents)}';
    final producer = find(_producers, _producer);
    final cowriter = find(_writers, _cowriter);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section(
          title: l.writeSong,
          icon: Icons.edit_note_rounded,
          trailing: Text(
              p.burnoutWeeksLeft > 0
                  ? l.burnoutWeeks(p.burnoutWeeksLeft)
                  : p.restingThisWeek
                      ? l.restingThisWeek
                      : l.songsWrittenThisWeek(p.songsWrittenThisWeek),
              style: TextStyle(color: AppColors.textMuted)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Creativity: the only limit on writing (docs K46).
              MeterRow(
                  label: l.energy,
                  value: p.creativeEnergy / 100,
                  text: '${p.creativeEnergy.round()}',
                  colors: p.creativityPenalty > 0
                      ? [AppColors.coral, AppColors.peach]
                      : [AppColors.mint, AppColors.sky]),
              Text(
                  p.creativityPenalty > 0
                      ? l.creativityPenalty((p.creativityPenalty * 100).round())
                      : l.creativityFull,
                  style: TextStyle(
                      color: p.creativityPenalty > 0
                          ? AppColors.coral
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(l.creativityHint(Actions.energyCostPerSong.round()),
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              const SizedBox(height: 6),
              _ChoiceRow(
                label: l.genre,
                value: fmt.genres(genres),
                onTap: () => _pickGenres(genres),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _holiday,
                onChanged: (v) => setState(() => _holiday = v),
                title: Text(l.holidaySong,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(l.holidaySongHint),
              ),
              _ChoiceRow(
                label: l.producer,
                value: teamValue(producer),
                detail: teamDetail(producer),
                onTap: () => _pickCollaborator(
                    l.producer, _producers, _producer, (v) => _producer = v),
              ),
              _ChoiceRow(
                label: l.cowriter,
                value: teamValue(cowriter),
                detail: teamDetail(cowriter),
                onTap: () => _pickCollaborator(
                    l.cowriter, _writers, _cowriter, (v) => _cowriter = v),
              ),
              const SizedBox(height: 14),
              Text(caps(context, l.studioBudget),
                  style: capsStyle(TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13))),
              const SizedBox(height: 8),
              SegmentedButton<BudgetTier>(
                showSelectedIcon: false,
                segments: [
                  for (final b in BudgetTier.values)
                    ButtonSegment(
                        value: b,
                        label: Text(
                            '${fmt.budget(b)}\n${fmt.money(Actions.budgetCostCents(b))}',
                            textAlign: TextAlign.center)),
                ],
                selected: {_budget},
                onSelectionChanged: (s) => setState(() => _budget = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                maxLength: 60,
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: l.songTitleHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                onPressed: canWrite && !career.busy ? _write : null,
                icon: Icons.mic_rounded,
                label: l.writeAndRecord(fmt.money(_cost())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Finished songs from songwriters (docs K205).
        Section(
          title: l.songMarket,
          icon: Icons.storefront_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.songMarketCard,
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => pushInCareer(context, const SongMarketScreen()),
                  icon: const Icon(Icons.storefront_rounded),
                  label: Text(l.songMarketOpen),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Section(
          title: l.vaultCount(_vault.length),
          icon: Icons.lock_outline_rounded,
          child: _vault.isEmpty
              ? EmptyNote(l.vaultEmpty)
              : Column(children: [
                  for (final s in _vault)
                    MediaTile(
                      coverSeed: songCoverSeed(s.id, s.coverAlbumId),
                      songId: s.id,
                      albumId: s.coverAlbumId,
                      title: s.title,
                      subtitle: s.boughtFrom == null
                          ? fmt.genres(s.genres)
                          : '${fmt.genres(s.genres)} · ${l.songBoughtFrom(s.boughtFrom!)}',
                      badge: GradeTag(fmt.songGrade(s)),
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

/// "Label / value ›" row that opens a picker.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow(
      {required this.label, required this.value, this.detail, this.onTap});
  final String label;
  final String value;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppShape.r(12)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caps(context, label),
                        style: capsStyle(TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                    const SizedBox(height: 2),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    if (detail != null)
                      Text(detail!,
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 13)),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ]),
        ),
      );
}
