import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/media_tile.dart';
import 'song_detail_screen.dart';

/// Studio: write a song (one screen, smart defaults) and see the vault.
class StudioTab extends StatefulWidget {
  const StudioTab({super.key});

  @override
  State<StudioTab> createState() => _StudioTabState();
}

class _StudioTabState extends State<StudioTab> {
  final _title = TextEditingController();
  List<int>? _genres;
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
    try {
      final song = await career.act(Cmd.writeSong(
        producerId: _producer,
        cowriterId: _cowriter,
        budget: _budget,
        genres: _genres ?? [career.player.genre],
        title: title.isEmpty ? null : title,
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
            Text(fmt.grade(song.estimatedGrade),
                style: Theme.of(c)
                    .textTheme
                    .displayMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(l.teamEstimate, textAlign: TextAlign.center),
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
    final canWrite = p.songsLeftThisWeek > 0 && p.burnoutWeeksLeft == 0;

    DropdownButtonFormField<int?> collaboratorField(String label,
            List<CollaboratorView> list, int? value, void Function(int?) set) =>
        DropdownButtonFormField<int?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: null, child: Text(l.nobody)),
            for (final c in list)
              DropdownMenuItem(
                value: c.id,
                enabled: c.available,
                child: Text(
                  '${c.name} · ${c.skill.round()} · ${fmt.genre(c.genre)} · ${fmt.money(c.feeCents)}',
                  overflow: TextOverflow.ellipsis,
                  style: c.available
                      ? null
                      : TextStyle(color: Theme.of(context).disabledColor),
                ),
              ),
          ],
          onChanged: (v) => setState(() => set(v)),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section(
          title: l.writeSong,
          icon: Icons.edit_note_rounded,
          trailing: Text(p.burnoutWeeksLeft > 0
              ? l.burnoutWeeks(p.burnoutWeeksLeft)
              : l.songsLeftThisWeek(p.songsLeftThisWeek)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                maxLength: 60,
                decoration: InputDecoration(
                    labelText: l.songTitleOptional,
                    border: const OutlineInputBorder()),
              ),
              Text(l.genresUpTo(maxSongGenres),
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 2, children: [
                for (var g = 0; g < genreNames.length; g++)
                  FilterChip(
                    label: Text(genres.contains(g)
                        ? '${genres.indexOf(g) + 1}. ${fmt.genre(g)}'
                        : fmt.genre(g)),
                    selected: genres.contains(g),
                    onSelected: (on) => setState(() {
                      final next = [...genres];
                      if (on && next.length < maxSongGenres) next.add(g);
                      if (!on && next.length > 1) next.remove(g);
                      _genres = next;
                    }),
                  ),
              ]),
              const SizedBox(height: 14),
              collaboratorField(
                  l.producer, _producers, _producer, (v) => _producer = v),
              const SizedBox(height: 12),
              collaboratorField(
                  l.cowriter, _writers, _cowriter, (v) => _cowriter = v),
              const SizedBox(height: 12),
              Text(l.studioBudget,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
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
        Section(
          title: l.vaultCount(_vault.length),
          icon: Icons.lock_outline_rounded,
          child: _vault.isEmpty
              ? EmptyNote(l.vaultEmpty)
              : Column(children: [
                  for (final s in _vault)
                    MediaTile(
                      coverSeed: songCoverSeed(s.id, s.albumId),
                      title: s.title,
                      subtitle: fmt.genres(s.genres),
                      badge: GradeTag(fmt.grade(s.estimatedGrade)),
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
