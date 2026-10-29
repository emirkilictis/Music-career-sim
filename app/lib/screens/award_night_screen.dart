import 'dart:math' as math;

import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../l10n/gen/app_localizations.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';

/// The night of the Golden Record Awards (docs K243): every category the
/// player is up for, the nominees read out, the envelope, the winner, a
/// speech when it is them, and the night's tally at the end.
Future<void> showAwardNight(
    BuildContext context, CareerState state, int year) async {
  final (_, show) = await state.read(Cmd.awards(year));
  if (show == null || !show.held || show.playerNominations == 0) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AwardNightScreen(show: show, state: state)));
}

class AwardNightScreen extends StatefulWidget {
  const AwardNightScreen({super.key, required this.show, required this.state});
  final AwardShowView show;
  final CareerState state;

  @override
  State<AwardNightScreen> createState() => _AwardNightScreenState();
}

enum _Phase { nominees, envelope, winner }

class _AwardNightScreenState extends State<AwardNightScreen>
    with SingleTickerProviderStateMixin {
  /// 0: the opening, 1..races: a category, then the tally.
  int _page = 0;
  _Phase _phase = _Phase.nominees;
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  /// The player's categories, the genre award first and Album of the Year
  /// last, as the show builds to it.
  late final List<AwardRaceView> _races = [
    for (final c in const [
      AwardCategory.genreAlbum,
      AwardCategory.newArtist,
      AwardCategory.song,
      AwardCategory.record,
      AwardCategory.album,
    ])
      for (final r in widget.show.races)
        if (r.category == c && r.nominees.any((n) => n.isPlayer)) r
  ];

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _next() => setState(() {
        _page++;
        _phase = _Phase.nominees;
      });

  Future<void> _open() async {
    setState(() => _phase = _Phase.envelope);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _phase = _Phase.winner);
    final race = _races[_page - 1];
    if (race.nominees.any((n) => n.isPlayer && n.isWinner)) {
      _confetti.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = _page > _races.length;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A08),
      body: Stack(children: [
        // A spotlight from above.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1.1),
                radius: 1.2,
                colors: [Color(0x55F2C14E), Color(0x00000000)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Row(children: [
              const SizedBox(width: 16),
              Text(l.awardNightTitle(widget.show.year).toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppFonts.condensed,
                      letterSpacing: 1.4,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold)),
              const Spacer(),
              if (!last)
                TextButton(
                  onPressed: () => setState(() => _page = _races.length + 1),
                  child: Text(l.awardNightSkip,
                      style: const TextStyle(color: Colors.white60)),
                ),
            ]),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: _page == 0
                      ? _Opening(show: widget.show, count: _races.length)
                      : last
                          ? _Tally(show: widget.show, races: _races)
                          : _RaceStage(
                              race: _races[_page - 1],
                              phase: _phase,
                              state: widget.state),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: PaperColors.ink),
                  onPressed: _phase == _Phase.envelope
                      ? null
                      : last
                          ? () => Navigator.pop(context)
                          : _page == 0 || _phase == _Phase.winner
                              ? _next
                              : _open,
                  child: Text(
                      last
                          ? l.awardNightDone
                          : _page == 0
                              ? l.awardNightStart
                              : _phase == _Phase.winner
                                  ? l.awardNightNext
                                  : l.awardNightOpen,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ),
          ]),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (_, __) => _confetti.value == 0
                  ? const SizedBox.shrink()
                  : CustomPaint(painter: ConfettiPainter(_confetti.value)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The curtain: the show, the year and how many categories are the
/// player's.
class _Opening extends StatelessWidget {
  const _Opening({required this.show, required this.count});
  final AwardShowView show;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppColors.gold, size: 88),
          const SizedBox(height: 16),
          Text(l.awardsTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: AppFonts.condensed,
                  letterSpacing: 2,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text('${show.year}',
              style: const TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontSize: 72,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold)),
          const SizedBox(height: 18),
          Text(l.awardNightIntro(count),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 16, height: 1.4)),
        ]),
      ),
    );
  }
}

/// One category on stage: the nominees, the envelope, the winner.
class _RaceStage extends StatelessWidget {
  const _RaceStage(
      {required this.race, required this.phase, required this.state});
  final AwardRaceView race;
  final _Phase phase;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final revealed = phase == _Phase.winner;
    final winner = race.nominees.where((n) => n.isWinner).firstOrNull;
    final mine = winner?.isPlayer ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        Text(l.awardNightCategory.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white54,
                letterSpacing: 1.4,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(fmt.awardCategory(race.category, race.genre).toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: AppFonts.condensed,
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 18),
        for (final n in race.nominees) _Nominee(n: n, revealed: revealed),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (phase) {
            _Phase.nominees => const SizedBox(height: 60),
            _Phase.envelope => _Envelope(key: const ValueKey('env')),
            _Phase.winner => Column(key: const ValueKey('win'), children: [
                Text(
                    mine
                        ? l.awardNightYouWon.toUpperCase()
                        : l
                            .awardNightGoesTo(winner?.artistName ?? '')
                            .toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppFonts.condensed,
                        fontSize: mine ? 40 : 22,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: mine ? AppColors.gold : Colors.white)),
                const SizedBox(height: 10),
                Text(
                    mine
                        ? '“${_speech(l, race.category.index + (winner?.id ?? 0))}”'
                        : l.awardNightNextTime,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: mine ? Colors.white : Colors.white60,
                        fontStyle: mine ? FontStyle.italic : FontStyle.normal,
                        fontSize: 15,
                        height: 1.4)),
              ]),
          },
        ),
      ],
    );
  }

  static String _speech(AppLocalizations l, int seed) => switch (seed % 6) {
        0 => l.awardSpeech0,
        1 => l.awardSpeech1,
        2 => l.awardSpeech2,
        3 => l.awardSpeech3,
        4 => l.awardSpeech4,
        _ => l.awardSpeech5,
      };
}

class _Nominee extends StatelessWidget {
  const _Nominee({required this.n, required this.revealed});
  final AwardNomineeView n;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final win = revealed && n.isWinner;
    final art = switch (n.entry) {
      AwardEntry.song => CoverArt(
          seed: songCoverSeed(n.id, n.coverAlbumId),
          songId: n.id,
          albumId: n.coverAlbumId,
          size: 48,
          radius: 2),
      AwardEntry.album => CoverArt(
          seed: albumCoverSeed(n.id), albumId: n.id, size: 48, radius: 2),
      AwardEntry.artist =>
        ArtistAvatar(name: n.title, seed: n.id, size: 48, artistId: n.id),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: revealed && !n.isWinner ? 0.35 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: win
              ? AppColors.gold.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
              color: win
                  ? AppColors.gold
                  : n.isPlayer
                      ? Colors.white38
                      : Colors.transparent,
              width: win ? 2 : 1),
          borderRadius: BorderRadius.circular(AppShape.r(10)),
        ),
        child: Row(children: [
          art,
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              if (n.entry != AwardEntry.artist)
                Text(n.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13)),
            ]),
          ),
          if (win)
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.gold, size: 26),
        ]),
      ),
    );
  }
}

/// The envelope being opened: a pulsing gold card.
class _Envelope extends StatefulWidget {
  const _Envelope({super.key});

  @override
  State<_Envelope> createState() => _EnvelopeState();
}

class _EnvelopeState extends State<_Envelope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.scale(
        scale: 1 + 0.06 * _c.value,
        child: Column(children: [
          Transform.rotate(
            angle: (math.sin(_c.value * math.pi) - 0.5) * 0.08,
            child: Container(
              width: 120,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.5),
                      blurRadius: 24 * _c.value)
                ],
              ),
              child: const Icon(Icons.mail_rounded,
                  color: PaperColors.ink, size: 40),
            ),
          ),
          const SizedBox(height: 10),
          Text(l.awardNightEnvelope,
              style: const TextStyle(
                  color: Colors.white70, fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }
}

/// The end of the night: wins out of nominations, a trophy for each win.
class _Tally extends StatelessWidget {
  const _Tally({required this.show, required this.races});
  final AwardShowView show;
  final List<AwardRaceView> races;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final won = [
      for (final r in races)
        if (r.nominees.any((n) => n.isPlayer && n.isWinner)) r
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 6, children: [
            for (var i = 0; i < math.max(1, won.length); i++)
              Icon(Icons.emoji_events_rounded,
                  size: 56,
                  color: won.isEmpty ? Colors.white24 : AppColors.gold),
          ]),
          const SizedBox(height: 14),
          Text(
              l
                  .awardsYou(show.playerWins, show.playerNominations)
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: won.isEmpty ? Colors.white : AppColors.gold)),
          const SizedBox(height: 10),
          for (final r in won)
            Text(fmt.awardCategory(r.category, r.genre),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 10),
          Text(won.isEmpty ? l.awardNightEmpty : l.awardNightProud,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.4)),
        ]),
      ),
    );
  }
}
