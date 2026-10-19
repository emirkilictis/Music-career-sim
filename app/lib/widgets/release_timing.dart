import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// When a release comes out and when it is announced (docs K45).
typedef ReleaseTiming = ({int releaseWeek, int announceWeek});

/// Release in this many weeks (0 = this week, right away).
const _releaseOffsets = [0, 1, 2, 4, 6, 8, 12, 16, 26];

/// Announce this many weeks before the release; -1 = right now, 0 = never
/// (a surprise drop).
const _announceOffsets = [-1, 1, 2, 4, 6, 8, 0];

/// Asks when a release should come out and when to announce it. [week] is
/// the current week. With [editing], the release week 0 is not offered and
/// an announcement already made cannot be taken back.
Future<ReleaseTiming?> pickReleaseTiming(
    BuildContext context, CareerState career,
    {ScheduledView? editing}) async {
  // Big rival albums near the dates on offer (docs K69).
  final rivals = await career.read(Cmd.upcomingRivalAlbums());
  if (!context.mounted) return null;
  return showModalBottomSheet<ReleaseTiming>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _TimingSheet(week: career.week, editing: editing, rivals: rivals),
  );
}

class _TimingSheet extends StatefulWidget {
  const _TimingSheet(
      {required this.week, this.editing, this.rivals = const []});
  final int week;
  final ScheduledView? editing;
  final List<UpcomingRelease> rivals;

  @override
  State<_TimingSheet> createState() => _TimingSheetState();
}

class _TimingSheetState extends State<_TimingSheet> {
  late int _in; // weeks until release
  late int _announce; // see _announceOffsets
  late final List<int> _releaseChoices;
  List<int> _announceChoices = _announceOffsets;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) {
      _releaseChoices = _releaseOffsets;
      _in = 0;
      _announce = -1;
      return;
    }
    _in = e.releaseWeek - widget.week;
    _releaseChoices = {..._releaseOffsets.where((x) => x > 0), _in}.toList()
      ..sort();
    if (e.isSurprise) {
      _announce = 0;
    } else if (e.announceWeek <= widget.week) {
      _announce = -1;
    } else {
      _announce = e.releaseWeek - e.announceWeek;
      _announceChoices = [
        -1,
        ...({..._announceOffsets.where((x) => x > 0), _announce}.toList()
          ..sort()),
        0,
      ];
    }
  }

  bool get _locked => widget.editing?.announced ?? false;

  /// Big rival albums out the week chosen (docs K69).
  List<UpcomingRelease> get _clash => [
        for (final r in widget.rivals)
          if (r.week == _releaseWeek) r
      ];

  int get _releaseWeek => widget.week + _in;

  int get _announceWeek => switch (_announce) {
        -1 => widget.week,
        0 => _releaseWeek,
        final k => _releaseWeek - k,
      };

  bool _announceOk(int a) => a <= 0 || a < _in;

  void _setRelease(int x) => setState(() {
        _in = x;
        // A lead time longer than the wait is not possible: announce now.
        if (!_announceOk(_announce)) _announce = -1;
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final t = Theme.of(context).textTheme;
    Widget chips<T>(List<T> values, T selected, String Function(T) label,
            void Function(T) onTap,
            {bool Function(T)? enabled}) =>
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in values)
            ChoiceChip(
              label: Text(label(v)),
              selected: v == selected,
              onSelected: (enabled?.call(v) ?? true) ? (_) => onTap(v) : null,
            ),
        ]);
    final later = _in > 0;
    final editing = widget.editing != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.whenTitle, style: t.titleLarge),
          const SizedBox(height: 12),
          chips<int>(
              _releaseChoices,
              _in,
              (x) => switch (x) {
                    0 => l.releaseNow,
                    1 => l.inOneWeek,
                    _ => l.inWeeks(x),
                  },
              _setRelease),
          if (_clash.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.rivalSameWeek(_clash.map((r) => r.artistName).join(', ')),
                style: TextStyle(
                    color: AppColors.peach, fontWeight: FontWeight.w700)),
          ],
          if (!later) ...[
            const SizedBox(height: 10),
            Text(l.surpriseHint, style: t.bodySmall),
          ],
          if (later) ...[
            const SizedBox(height: 8),
            Text(l.releaseDate(fmt.week(_releaseWeek)),
                style: TextStyle(
                    color: AppColors.lilac, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Text(l.announceTitle, style: t.titleMedium),
            const SizedBox(height: 8),
            if (_locked)
              Text(l.announceLocked,
                  style: TextStyle(color: AppColors.textMuted))
            else ...[
              chips<int>(
                  _announceChoices,
                  _announce,
                  (a) => switch (a) {
                        -1 => l.announceNow,
                        0 => l.announceSurprise,
                        1 => l.announceOneWeek,
                        _ => l.announceBefore(a),
                      },
                  (a) => setState(() => _announce = a),
                  enabled: _announceOk),
              const SizedBox(height: 8),
              if (_announce != 0)
                Text(l.announceDate(fmt.week(_announceWeek)),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_announce == 0 ? l.surpriseHint : l.announceHint,
                  style: t.bodySmall),
            ],
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, (
                releaseWeek: _releaseWeek,
                announceWeek: _locked
                    ? widget.editing!.announceWeek
                    : later
                        ? _announceWeek
                        : widget.week,
              )),
              child: Text(editing ? l.save : l.continueAction),
            ),
          ),
        ]),
      ),
    );
  }
}
