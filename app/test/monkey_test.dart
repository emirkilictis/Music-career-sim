import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart' hide Actions;
import 'package:music_career_sim/core/commands.dart';

import 'support.dart';

/// Taps at random through the app on a career with a bit of everything,
/// collecting every error the screens throw (docs K188).
/// Run with: MONKEY=1 [MONKEY_STEPS=400] [MONKEY_SEED=1] flutter test
/// test/monkey_test.dart
void main() {
  final enabled = Platform.environment['MONKEY'] == '1';
  final steps = int.parse(Platform.environment['MONKEY_STEPS'] ?? '400');
  final seed = int.parse(Platform.environment['MONKEY_SEED'] ?? '1');
  final env = Platform.environment;
  final year = int.parse(env['MONKEY_YEAR'] ?? '2018');
  final kind = ArtistKind.values.byName(env['MONKEY_KIND'] ?? 'vocalGroup');
  final tier = StartTier.values.byName(env['MONKEY_TIER'] ?? 'superstar');

  testWidgets('monkey', skip: !enabled, (tester) async {
    // Real fonts: overflows depend on text widths.
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await c.exec(Cmd.start(
        CareerSetup(
          name: 'Monkey',
          genre: 0,
          kind: kind,
          members: kind.isGroup ? const ['A', 'B', 'C', 'D'] : const [],
          startYear: year,
          tier: tier,
          money: StartMoney.millionaire,
          premium: true,
          seed: seed,
        ),
        port.sendPort));
    port.close();
    final songs = <int>[];
    while (songs.length < 14) {
      final (p, _, _) = await c.run(Cmd.snapshot());
      if (!p.canWrite || p.creativeEnergy < 30) {
        await c.run(Cmd.nextWeek());
        continue;
      }
      songs.add((await c.run(
              Cmd.writeSong(budget: BudgetTier.high, genres: const [0])))
          .id);
    }
    // A label that runs every campaign, when it will have the artist.
    try {
      await c.run(Cmd.signLabel(Label.major));
    } catch (_) {}
    await c.run(Cmd.releaseSingle(songs.first, Campaign.standard));
    for (var i = 0; i < 3; i++) {
      await c.run(Cmd.nextWeek());
    }
    await c.run(Cmd.releaseAlbum(
        title: 'Album',
        songIds: songs.sublist(0, 10),
        type: AlbumType.album,
        variantWeeks: const [0],
        campaign: Campaign.standard));
    for (var i = 0; i < 3; i++) {
      await c.run(Cmd.nextWeek());
    }
    await c.exec(Cmd.closeCareer());

    final errors = <String, int>{};
    final where = <String, String>{};
    String screen() {
      final bars = find.byType(AppBar).evaluate();
      if (bars.isEmpty) return '(no app bar)';
      final title = (bars.last.widget as AppBar).title;
      return title is Text ? title.data ?? '?' : '?';
    }

    void record(Object e, [String? origin]) {
      final first = e.toString().split('\n').first;
      final key = origin == null ? first : '$first @ $origin';
      // Platform plugins the test host does not have.
      if (key.contains('MissingPluginException')) return;
      errors[key] = (errors[key] ?? 0) + 1;
      where.putIfAbsent(key, screen);
    }

    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      // Where in the app it happened: the first app frame or the widget.
      final text = d.toString();
      final m = RegExp(r'package:music_career_sim/[^\s)]+').firstMatch(text) ??
          RegExp(r'file:///[^\s)]*/app/lib/[^\s)]+').firstMatch(text);
      record(d.exception, m?.group(0));
    };
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monkey').first);
    await tester.pumpAndSettle();

    Future<void> settle() async {
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
      } catch (_) {
        // Endless animations (spinners): just move on.
      }
    }

    final r = math.Random(seed);
    final visited = <String>{};
    final tapped = <String>[];
    final tappable = find.byWidgetPredicate((w) =>
        (w is InkWell && w.onTap != null) ||
        (w is ButtonStyleButton && w.onPressed != null) ||
        (w is IconButton && w.onPressed != null) ||
        (w is ListTile && w.onTap != null) ||
        (w is ChoiceChip && w.onSelected != null) ||
        (w is FilterChip && w.onSelected != null) ||
        (w is ActionChip && w.onPressed != null));
    // Things that would end the run.
    bool risky(Element e) {
      final text = <String>[];
      e.visitChildElements(_collect(text));
      final s = text.join(' ').toLowerCase();
      return s.contains('delete') ||
          s.contains('close career') ||
          s.contains('main menu') ||
          s.contains('retire') ||
          // Long skips: a year of weeks makes a run crawl.
          s.contains('whole year') ||
          s.contains('until something') ||
          s.contains('4 weeks') ||
          s.contains('26 weeks') ||
          s.contains('26 hafta') ||
          s.contains('bütün bir yıl') ||
          s.contains('skip year') ||
          s.contains('yıl atla') ||
          s.contains('bir şey olana') ||
          // The ad's countdown waits on a real clock.
          s.contains('watch an ad') ||
          s.contains('reklam izle');
    }

    for (var i = 0; i < steps; i++) {
      try {
        final roll = r.nextDouble();
        if (Platform.environment['MONKEY_TRACE'] == '2') {
          // ignore: avoid_print
          print('STEP $i roll ${roll.toStringAsFixed(2)} on ${screen()}');
        }
        final title = screen();
        if (title == 'New career' || title == 'Yeni kariyer') {
          // Not starting another career: back to the list.
          await tester.tap(find.byType(BackButton).last);
        } else if ((title == 'Music Career Simulator' ||
                title == 'Müzik Kariyeri Simülatörü') &&
            find.text('Monkey').hitTestable().evaluate().isNotEmpty) {
          // The career list: back into the career.
          await tester.tap(find.text('Monkey').hitTestable().first);
        } else if (roll < 0.10 &&
            find.byType(NavigationDestination).hitTestable().evaluate().isNotEmpty) {
          // Another tab of the game.
          final tabs =
              find.byType(NavigationDestination).hitTestable().evaluate().toList();
          final t = tabs[r.nextInt(tabs.length)];
          await tester.tapAt(tester.getCenter(
              find.byElementPredicate((x) => identical(x, t))));
        } else if (roll < 0.22 &&
            find.byType(Scrollable).hitTestable().evaluate().isNotEmpty) {
          // Scroll to see more of the page.
          await tester.drag(find.byType(Scrollable).hitTestable().first,
              Offset(0, r.nextBool() ? -500 : 300));
        } else if (roll < 0.30) {
          // The phone's back key.
          // Not awaited, and outside the tester's guard: a page may answer
          // with a dialog that waits.
          final navs = find.byType(Navigator).evaluate();
          if (navs.isNotEmpty) {
            final nav = (navs.last as StatefulElement).state as NavigatorState;
            unawaited(nav.maybePop());
          }
        } else if (roll < 0.34) {
          // Close a sheet or dialog by its barrier.
          await tester.tapAt(const Offset(20, 60));
        } else {
          final found = tappable.hitTestable().evaluate().toList()
            ..removeWhere(risky);
          if (found.isEmpty) {
            await tester.tapAt(const Offset(20, 60));
          } else {
            final e = found[r.nextInt(found.length)];
            final label = <String>[];
            e.visitChildElements(_collect(label));
            tapped.add('${e.widget.runtimeType}:${label.take(2).join('/')}');
            if (Platform.environment['MONKEY_TRACE'] == '2') {
              // ignore: avoid_print
              print('TAP $i ${tapped.last}');
            }
            await tester.tapAt(tester.getCenter(find.byElementPredicate(
                (x) => identical(x, e),
                skipOffstage: false)));
          }
        }
      } catch (e) {
        record(e);
      }
      await settle();
      visited.add(screen());
      if (Platform.environment['MONKEY_TRACE'] == '1' && i % 50 == 0) {
        final texts = find
            .byType(Text)
            .hitTestable()
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .where((t) => t.isNotEmpty)
            .take(12)
            .join(' / ');
        // ignore: avoid_print
        print('STEP $i: $texts');
      }
      final ex = tester.takeException();
      if (ex != null) record(ex);
    }
    // ignore: avoid_print
    print('MONKEY ${errors.length} kinds of errors after $steps steps, '
        '${visited.length} screens: ${visited.join(' | ')}');
    // ignore: avoid_print
    print('TAPPED ${tapped.toSet().length} distinct: '
        '${tapped.toSet().take(150).join(' | ')}');
    for (final e in errors.entries) {
      // ignore: avoid_print
      print('${e.value}x [${where[e.key]}] ${e.key}');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

ElementVisitor _collect(List<String> out) => (Element e) {
      final w = e.widget;
      if (w is Text && w.data != null) out.add(w.data!);
      e.visitChildElements(_collect(out));
    };
