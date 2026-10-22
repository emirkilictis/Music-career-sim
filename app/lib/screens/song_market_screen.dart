import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';

/// The song market (docs K205): the month's demos from songwriters, each
/// with its likely grade with the player's voice, its writer and price.
class SongMarketScreen extends StatefulWidget {
  const SongMarketScreen({super.key});

  @override
  State<SongMarketScreen> createState() => _SongMarketScreenState();
}

class _SongMarketScreenState extends State<SongMarketScreen> {
  SongMarketView? _market;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await context.careerRead.read(Cmd.songMarket());
    if (mounted) setState(() => _market = m);
  }

  Future<void> _buy(SongPitchView x) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final s = await context.careerRead.act(Cmd.buySong(x.index));
      messenger
          .showSnackBar(SnackBar(content: Text(l.songMarketDone(s.title))));
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final m = _market;
    return Scaffold(
      appBar: AppBar(title: Text(l.songMarket)),
      body: m == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(l.songMarketHint(m.cutPct),
                    style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Text(l.songMarketNext(m.weeksToNext),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (m.pitches.isEmpty) EmptyNote(l.songMarketEmpty),
                for (final x in m.pitches) ...[
                  Section(
                    title: x.title,
                    icon: Icons.music_note_rounded,
                    trailing: GradeTag(fmt.gradeRange(x.gradeLow, x.gradeHigh)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${x.writerName} · ${l.skillValue(x.writerSkill)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(fmt.genre(x.genre),
                            style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 10),
                        if (x.bought)
                          Tag(l.songMarketBought,
                              icon: Icons.check_rounded, color: AppColors.mint)
                        else if (x.taken)
                          Tag(l.songMarketTaken,
                              icon: Icons.block_rounded,
                              color: AppColors.textMuted)
                        else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              onPressed: career.busy ||
                                      x.priceCents > career.player.moneyCents
                                  ? null
                                  : () => _buy(x),
                              icon: const Icon(Icons.shopping_cart_rounded),
                              label: Text(
                                  l.songMarketBuy(fmt.money(x.priceCents))),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}
