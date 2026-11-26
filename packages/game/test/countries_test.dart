import 'package:game/game.dart';
import 'package:test/test.dart';

/// docs K313: listeners country by country.
void main() {
  test('a US pop act is biggest at home, a K-pop act in Korea', () {
    final us = Countries.top([0.6, 0.25, 0.15], HomeCountry.us, 0, 1e6);
    expect(us.first.code, 'us');
    expect(us.first.listeners, closeTo(1e6 * 0.6 * 0.92, 1));
    final shares = us.fold(0.0, (t, c) => t + c.share);
    expect(shares, lessThanOrEqualTo(1.0 + 1e-9));
    expect(us.length, 10);
    final kpop = Countries.top([0.15, 0.15, 0.7], HomeCountry.other, 18, 1e6);
    expect(kpop.take(3).map((c) => c.code), contains('kr'));
    // Ordered, and nothing for nobody.
    for (var i = 1; i < kpop.length; i++) {
      expect(kpop[i].listeners, lessThanOrEqualTo(kpop[i - 1].listeners));
    }
    expect(Countries.top([0.5, 0.3, 0.2], HomeCountry.uk, 0, 0), isEmpty);
  });
}
