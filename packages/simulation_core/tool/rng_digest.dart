// Prints random draws; the VM and the JavaScript build must agree (docs K236).
import 'package:simulation_core/simulation_core.dart';

void main() {
  final out = StringBuffer('js=$jsNumbers\n');
  final keys = RandomStream.keyed(11, 5, 6, 7);
  for (var i = 0; i < 2000; i++) {
    final seed = keys.nextInt(1 << 30) * 131072 + keys.nextInt(131072);
    final week = keys.nextInt(4000) - 100;
    final entity = keys.nextInt(200000) - 200;
    final purpose = keys.nextInt(60);
    out.write(keyedUnit(seed, week, entity, purpose));
    final r = RandomStream.keyed(seed, week, entity, purpose);
    for (var j = 0; j < 4; j++) {
      out.write(' ${r.nextDouble()}');
    }
    out.writeln(' ${r.nextNormal()}');
  }
  print(out);
  final sw = Stopwatch()..start();
  var t = 0.0;
  for (var i = 0; i < 1000000; i++) {
    t += keyedUnit(123456789, i, i * 7, 3);
  }
  final r = RandomStream.keyed(1, 2, 3, 4);
  for (var i = 0; i < 3000000; i++) {
    t += r.nextDouble();
  }
  print('# ${sw.elapsedMilliseconds} ms ($t)');
}
