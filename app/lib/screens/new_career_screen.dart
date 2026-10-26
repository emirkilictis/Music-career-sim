import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import 'slots_screen.dart';

/// One screen with smart defaults (docs/game-design.md §2): name, kind,
/// genre, start year and go. Everything else can be left as it is.
class NewCareerScreen extends StatefulWidget {
  const NewCareerScreen({super.key});

  @override
  State<NewCareerScreen> createState() => _NewCareerScreenState();
}

class _NewCareerScreenState extends State<NewCareerScreen> {
  final _name = TextEditingController();
  final List<TextEditingController> _members = [];
  ArtistKind _kind = ArtistKind.solo;
  int _genre = 0;
  HomeCountry _home = HomeCountry.us;
  int _startYear = 2024;
  Difficulty _difficulty = Difficulty.normal;
  bool _realNames = true;
  CareerPath _path = CareerPath.independent;
  StartTier _tier = StartTier.unknown;
  StartMoney _money = StartMoney.basic;
  late List<int>
      _stats; // songwriting, vocals, production, performance, charisma
  bool _creating = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _autoStats(false);
  }

  @override
  void dispose() {
    _name.dispose();
    for (final m in _members) {
      m.dispose();
    }
    super.dispose();
  }

  void _autoStats(bool premium) {
    final s = StartingStats.auto(premium: premium, kind: _kind);
    _stats = [s.songwriting, s.vocals, s.production, s.performance, s.charisma]
        .map((x) => x.round())
        .toList();
  }

  int _pointsLeft(bool premium) =>
      StartingStats.points(premium: premium) -
      _stats.fold(0, (a, x) => a + x - StartingStats.base.round());

  void _setKind(ArtistKind k, bool premium) {
    setState(() {
      _kind = k;
      final want = k.isGroup ? (k == ArtistKind.band ? 4 : 5) : 0;
      while (_members.length < want) {
        _members.add(TextEditingController());
      }
      while (_members.length > want) {
        _members.removeLast().dispose();
      }
      _autoStats(premium);
    });
  }

  Future<void> _create(bool premium) async {
    final setup = CareerSetup(
      name: _name.text,
      genre: _genre,
      kind: _kind,
      members: [for (final m in _members) m.text],
      home: _home,
      startYear: _startYear,
      difficulty: _difficulty,
      tier: _tier,
      money: _money,
      path: _path,
      skills: Skills(
        songwriting: _stats[0].toDouble(),
        vocals: _stats[1].toDouble(),
        production: _stats[2].toDouble(),
        performance: _stats[3].toDouble(),
        charisma: _stats[4].toDouble(),
      ),
      premium: premium,
      realNames: _realNames,
    );
    try {
      setup.validate();
    } catch (e) {
      showError(context, e);
      return;
    }
    setState(() {
      _creating = true;
      _progress = 0;
    });
    final controller = context.controller;
    final progress = controller.progressChannel((p) {
      if (mounted) setState(() => _progress = (p as num).toDouble());
    });
    try {
      await controller.exec(Cmd.start(setup, progress.sink));
      if (!mounted) return;
      final nav = Navigator.of(context);
      final state = CareerState(controller);
      // Replace this screen with the game.
      nav.pop();
      await openCareer(nav.context, state);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showError(context, e);
      }
    } finally {
      progress.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final premium = context.settings.premium;
    final t = Theme.of(context).textTheme;

    if (_creating) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l.buildingWorld, style: t.titleMedium),
              const SizedBox(height: 8),
              Text(l.buildingWorldBody, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              LinearProgressIndicator(value: _progress),
            ]),
          ),
        ),
      );
    }

    final cap = StartingStats.cap(premium: premium).round();
    final left = _pointsLeft(premium);
    final statNames = [
      l.statSongwriting,
      l.statVocals,
      l.statProduction,
      l.statPerformance,
      l.statCharisma
    ];

    Widget lockedChip<T>(
        {required String label,
        required bool selected,
        required bool locked,
        required VoidCallback onSelected}) {
      return ChoiceChip(
        label: Text(label),
        avatar: locked ? const Icon(Icons.lock_outline, size: 16) : null,
        selected: selected,
        onSelected: locked
            ? (_) => showInfo(context, l.premiumOnly)
            : (_) => onSelected(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.newCareer)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Section(
            title: l.sectionArtist,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    maxLength: CareerSetup.maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                        labelText: _kind.isGroup ? l.groupName : l.artistName,
                        border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ArtistKind>(
                    showSelectedIcon: false,
                    segments: [
                      for (final k in ArtistKind.values)
                        ButtonSegment(value: k, label: Text(fmt.kind(k))),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => _setKind(s.first, premium),
                  ),
                  const SizedBox(height: 6),
                  // What each kind is good at (docs K87).
                  Text(
                      switch (_kind) {
                        ArtistKind.solo => l.kindSoloHint,
                        ArtistKind.band => l.kindBandHint,
                        ArtistKind.vocalGroup => l.kindVocalGroupHint,
                      },
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  if (_kind.isGroup) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Text(l.members(_members.length))),
                      IconButton(
                        onPressed: _members.length > ArtistKind.minMembers
                            ? () =>
                                setState(() => _members.removeLast().dispose())
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        onPressed: _members.length < ArtistKind.maxMembers
                            ? () => setState(
                                () => _members.add(TextEditingController()))
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ]),
                    for (var i = 0; i < _members.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _members[i],
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                              isDense: true,
                              labelText: l.memberN(i + 1),
                              border: const OutlineInputBorder()),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _genre,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: l.genre,
                            border: const OutlineInputBorder()),
                        items: [
                          for (var g = 0; g < genreNames.length; g++)
                            DropdownMenuItem(
                                value: g, child: Text(fmt.genre(g))),
                        ],
                        onChanged: (g) => setState(() => _genre = g!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<HomeCountry>(
                        initialValue: _home,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: l.homeCountry,
                            border: const OutlineInputBorder()),
                        items: [
                          for (final h in HomeCountry.values)
                            DropdownMenuItem(
                                value: h, child: Text(fmt.home(h))),
                        ],
                        onChanged: (h) => setState(() => _home = h!),
                      ),
                    ),
                  ]),
                ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.sectionWorld,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _startYear,
                    decoration: InputDecoration(
                        labelText: l.startYear,
                        border: const OutlineInputBorder()),
                    items: [
                      for (var y = CareerSetup.maxStartYear;
                          y >= CareerSetup.minStartYear;
                          y--)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (y) => setState(() => _startYear = y!),
                  ),
                  const SizedBox(height: 12),
                  Text(l.difficulty, style: t.labelLarge),
                  const SizedBox(height: 6),
                  SegmentedButton<Difficulty>(
                    showSelectedIcon: false,
                    segments: [
                      for (final d in Difficulty.values)
                        ButtonSegment(value: d, label: Text(fmt.difficulty(d))),
                    ],
                    selected: {_difficulty},
                    onSelectionChanged: (s) =>
                        setState(() => _difficulty = s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      switch (_difficulty) {
                        Difficulty.legend => l.difficultyLegendHint,
                        Difficulty.normal => l.difficultyNormalHint,
                        Difficulty.hard => l.difficultyHardHint,
                      },
                      style: t.bodySmall),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.realNames),
                    subtitle: Text(l.realNamesHint),
                    value: _realNames,
                    onChanged: (v) => setState(() => _realNames = v),
                  ),
                ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.sectionStart,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.careerPath, style: t.labelLarge),
                  const SizedBox(height: 6),
                  SegmentedButton<CareerPath>(
                    showSelectedIcon: false,
                    segments: [
                      for (final p in CareerPath.values)
                        ButtonSegment(value: p, label: Text(fmt.path(p))),
                    ],
                    selected: {_path},
                    onSelectionChanged: (s) => setState(() => _path = s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      _path == CareerPath.independent
                          ? l.pathIndependentHint
                          : l.pathSmallLabelHint,
                      style: t.bodySmall),
                  const SizedBox(height: 14),
                  Text(l.startLevel, style: t.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final tier in StartTier.values)
                      lockedChip(
                        label: fmt.tier(tier),
                        selected: _tier == tier,
                        locked: !premium && CareerSetup.isPremiumTier(tier),
                        onSelected: () => setState(() => _tier = tier),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Text(l.startMoney, style: t.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final m in StartMoney.values)
                      lockedChip(
                        label: fmt.startMoney(m),
                        selected: _money == m,
                        locked: !premium && CareerSetup.isPremiumMoney(m),
                        onSelected: () => setState(() => _money = m),
                      ),
                  ]),
                ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.sectionStats,
            trailing: TextButton(
                onPressed: () => setState(() => _autoStats(premium)),
                child: Text(l.autoDistribute)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.pointsLeft(left, cap),
                      style: t.bodyMedium?.copyWith(
                          color: left < 0
                              ? Theme.of(context).colorScheme.error
                              : null)),
                  for (var i = 0; i < 5; i++)
                    Row(children: [
                      SizedBox(width: 110, child: Text(statNames[i])),
                      Expanded(
                        child: Slider(
                          value: _stats[i]
                              .toDouble()
                              .clamp(StartingStats.base, cap.toDouble()),
                          min: StartingStats.base,
                          max: cap.toDouble(),
                          divisions: cap - StartingStats.base.round(),
                          label: '${_stats[i]}',
                          onChanged: (v) {
                            final nv = v.round();
                            final extra = nv - _stats[i];
                            if (extra > 0 && extra > left) return;
                            setState(() => _stats[i] = nv);
                          },
                        ),
                      ),
                      SizedBox(
                          width: 28,
                          child:
                              Text('${_stats[i]}', textAlign: TextAlign.right)),
                    ]),
                ]),
          ),
          if (!premium) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(l.premiumPitchTitle),
                subtitle: Text(l.premiumPitchBody),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: GradientButton(
            icon: Icons.play_arrow_rounded,
            label: l.startCareer,
            onPressed: () => _create(premium),
          ),
        ),
      ),
    );
  }
}
