import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

void main() {
  test('old songs are less steady: a slump 15% of quarters (docs K291)', () {
    var slumps = 0, rises = 0, minimum = 9.0;
    const n = 20000;
    for (var i = 0; i < n; i++) {
      final t = Lifecycle.catalogTrend(7, i ~/ 100, i);
      if (t < 1) slumps++;
      if (t > 1) rises++;
      if (t < minimum) minimum = t;
    }
    expect(slumps / n, closeTo(Lifecycle.slumpChance, 0.01));
    expect(rises / n, closeTo(Lifecycle.resurgenceChance, 0.01));
    expect(minimum, closeTo(0.4, 0.01));
    // Streaming grows less after the last keyframe.
    final era = EraTable.usDefault();
    final at2026 = era.forWeek(GameTime.firstWeekOf(2026)).streamsWeekly;
    final at2060 = era.forWeek(GameTime.firstWeekOf(2060)).streamsWeekly;
    expect(at2060 / at2026, lessThan(1.21));
  });
}
