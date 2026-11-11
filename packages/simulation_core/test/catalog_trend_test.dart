import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

void main() {
  test('old songs ride waves that last (docs K291, K295)', () {
    var slumps = 0, rises = 0, kept = 0, touched = 0;
    var minimum = 9.0, maximum = 0.0;
    const songs = 400, quarters = 50;
    for (var id = 0; id < songs; id++) {
      for (var q = 0; q < quarters; q++) {
        final t = Lifecycle.catalogTrend(7, q, id);
        if (t < 1) slumps++;
        if (t > 1) rises++;
        if (t < minimum) minimum = t;
        if (t > maximum) maximum = t;
        // A wave carries on into the next quarter more often than not.
        if (t != 1) {
          touched++;
          if (Lifecycle.catalogTrend(7, q + 1, id) != 1) kept++;
        }
      }
    }
    const n = songs * quarters;
    expect(slumps / n, inInclusiveRange(0.12, 0.28));
    expect(rises / n, inInclusiveRange(0.05, 0.14));
    expect(kept / touched, greaterThan(0.5));
    expect(minimum, greaterThan(0.1));
    expect(maximum, lessThan(10));
    // Streaming grows less after the last keyframe.
    final era = EraTable.usDefault();
    final at2026 = era.forWeek(GameTime.firstWeekOf(2026)).streamsWeekly;
    final at2060 = era.forWeek(GameTime.firstWeekOf(2060)).streamsWeekly;
    expect(at2060 / at2026, lessThan(1.21));
  });
}
