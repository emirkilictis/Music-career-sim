import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

/// docs K302: old songs leave the US song chart as Billboard's recurrent
/// rule says, as it changed over the years.
void main() {
  final us = Charts.all.firstWhere((d) => d.id == Charts.usSongs);
  final uk = Charts.all.firstWhere((d) => d.id == Charts.ukSongs);
  final global = Charts.all.firstWhere((d) => d.id == Charts.globalSongs);

  test('the rule by year', () {
    GameTime.baseYear = GameTime.defaultBaseYear;
    int at(int year, int weekOfYear) =>
        GameTime.firstWeekOf(year) + weekOfYear - 1;
    expect(Charts.recurrentRules(us, at(1985, 1)), [(20, 50)]);
    expect(Charts.recurrentRules(us, at(2015, 48)), [(20, 50)]);
    expect(Charts.recurrentRules(us, at(2015, 49)), [(20, 50), (52, 25)]);
    expect(Charts.recurrentRules(us, at(2025, 42)), [(20, 50), (52, 25)]);
    expect(Charts.recurrentRules(us, at(2025, 43)),
        [(20, 50), (26, 25), (52, 10), (78, 5)]);
    expect(Charts.recurrentRules(uk, at(2030, 1)), [(20, 50)]);
    expect(Charts.recurrentRules(global, at(2030, 1)), isEmpty);
    final now = Charts.recurrentRules(us, at(2030, 1));
    expect(Charts.isRecurrent(now, 19, 80), isFalse);
    expect(Charts.isRecurrent(now, 20, 51), isTrue);
    expect(Charts.isRecurrent(now, 30, 25), isFalse);
    expect(Charts.isRecurrent(now, 30, 26), isTrue);
    expect(Charts.isRecurrent(now, 60, 11), isTrue);
    expect(Charts.isRecurrent(now, 80, 5), isFalse);
    expect(Charts.isRecurrent(now, 80, 6), isTrue);
  });

  test('no old song stays low on the US chart unless it climbs', () {
    final w = WorldGen.create(seed: 302, startYear: 2025);
    final sim = Simulator(w);
    var last = <int, int>{};
    var longest = 0, longestAt = '', lastLong = 0;
    final end = GameTime.firstWeekOf(2028);
    while (w.week < end) {
      final rules = Charts.recurrentRules(us, w.week);
      final chart = sim.step().charts[Charts.usSongs];
      final now = <int, int>{};
      for (final e in chart) {
        now[e.entityId] = e.position;
        // weeksOn already counts this week.
        final before = last[e.entityId] ?? 0;
        final climbed = before > 0 && e.position < before;
        if (!climbed) {
          expect(Charts.isRecurrent(rules, e.weeksOn - 1, e.position), isFalse,
              reason: '${w.songs[e.entityId].title} at #${e.position} '
                  'after ${e.weeksOn} weeks, ${GameTime.label(w.week)}');
        }
        if (GameTime.yearOf(w.week) == 2027 && e.weeksOn > longest) {
          longest = e.weeksOn;
          longestAt = '${w.songs[e.entityId].title} #${e.position} ${GameTime.label(w.week)}';
        }
      }
      last = now;
      lastLong = chart.where((e) => e.weeksOn > 78).length;
      // The rule never leaves the chart short.
      if (w.week > GameTime.firstWeekOf(2025) + 12) expect(chart.length, 100);
    }
    // Under the four steps only a song in the top five lasts past 78
    // weeks: at most five of them on the chart (in 2027, with the rule
    // in place for over a year).
    printOnFailure(longestAt);
    print('longest run $longest weeks: $longestAt');
    expect(lastLong, lessThanOrEqualTo(5));
  });
}
