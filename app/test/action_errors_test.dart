import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/core/action_errors.dart';

/// Every reason a rule gives has a Turkish text (docs K281): none falls
/// back to the English one, and none shows "Something went wrong".
void main() {
  test('every rule reason has a Turkish text', () {
    // Codes with a message of their own on the screen.
    final format = File('lib/core/format.dart').readAsStringSync();
    final start = format.indexOf('String error(Object e)');
    final mapped = {
      for (final m in RegExp(r"'(\w+)' => l\.")
          .allMatches(format.substring(start, format.indexOf('};', start))))
        m.group(1)!
    };
    final found = <String>{};
    final pattern = RegExp(
        r"""(?:ActionException\(\s*|GameException\(\s*'(\w+)',\s*)'((?:[^'\\]|\\.)+)'""");
    for (final dir in ['../packages/simulation_core/lib', '../packages/game/lib']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in pattern.allMatches(f.readAsStringSync())) {
          if (mapped.contains(m.group(1))) continue;
          found.add(m.group(2)!.replaceAll(r"\'", "'"));
        }
      }
    }
    expect(found.length, greaterThan(100));
    final missing = [
      for (final m in found)
        if (!m.contains(r'$') && actionError(m, turkish: true) == m) m
    ];
    expect(missing, isEmpty);
    expect(actionError('Not enough creativity', turkish: true),
        'Yeterli yaratıcılık yok. Her hafta dolar.');
    expect(actionError('Cannot go solo: tooSoon', turkish: false),
        'You cannot go solo right now.');
  });
}
