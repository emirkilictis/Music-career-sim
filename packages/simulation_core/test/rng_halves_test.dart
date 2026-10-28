import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

/// The JavaScript fallback's 64-bit words give the VM's numbers (docs K236).
void main() {
  test('64-bit words on halves match native ints', () {
    final r = RandomStream.keyed(7, 1, 2, 3);
    int any() {
      final x = (r.nextDouble() * 9007199254740992).floor();
      return r.chance(0.5) ? x : -x;
    }

    for (var i = 0; i < 20000; i++) {
      final a = any(), b = any(), n = 1 + r.nextInt(31);
      expect(Word64.of(a).toInt(), a);
      expect((Word64.of(a)..mul(Word64.of(b))).toInt(), a * b);
      expect((Word64.of(a)..add(Word64.of(b))).toInt(), a + b);
      expect((Word64.of(a)..xorShr(n)).toInt(), a ^ (a >>> n));
      expect((Word64.of(a)..xorSar(n)).toInt(), a ^ (a >> n));
      expect((Word64.of(a)..mix()).toInt(), mix64(a));
    }
  });

  test('keyed draws on halves match native ints', () {
    final keys = RandomStream.keyed(11, 5, 6, 7);
    for (var i = 0; i < 3000; i++) {
      final seed = keys.nextInt(1 << 47);
      final week = keys.nextInt(4000) - 100;
      final entity = keys.nextInt(200000) - 200;
      final purpose = keys.nextInt(60);
      expect(Word64.keyedUnit(seed, week, entity, purpose),
          keyedUnit(seed, week, entity, purpose));
      final a = RandomStream.keyed(seed, week, entity, purpose);
      final b = RandomStream.onHalves(seed, week, entity, purpose);
      for (var j = 0; j < 8; j++) {
        expect(b.nextDouble(), a.nextDouble());
      }
      expect(b.nextNormal(), a.nextNormal());
    }
  });
}
