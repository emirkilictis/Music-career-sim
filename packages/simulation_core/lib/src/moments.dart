import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'audience.dart';
import 'beefs.dart';
import 'model.dart';
import 'opportunities.dart';
import 'rng.dart';
import 'world.dart';

/// Moments the player plays through (docs K256): an interview's
/// questions, something that happens on stage, a crisis handled step by
/// step.
enum MomentKind { interview, concert, crisis }

/// One scene of a moment, with three answers. Index order is stored in
/// saves: only append.
enum MomentScene {
  // An interview's questions.
  qRelease,
  qRival,
  qPersonal,
  qIndustry,
  qFans,
  qDrama,
  qFuture,
  qInspiration,
  // On stage.
  fanOnStage,
  soundCut,
  starInCrowd,
  proposal,
  storm,
  // A crisis: the first statement, then the press's turn.
  crisisStatement,
  pressSpreading,
  pressFading,
  pressSplit;

  MomentKind get kind => index <= qInspiration.index
      ? MomentKind.interview
      : index <= storm.index
          ? MomentKind.concert
          : MomentKind.crisis;
}

/// What one answer can do (docs K256): shares of the artist's numbers,
/// and how risky it is ([risk] 0: safe). [stage]: the performance skill
/// decides, else charisma. [viral]: the chance a clip takes off.
class _Effect {
  const _Effect(
      {this.hype = 0,
      this.devotion = 0,
      this.popularity = 0,
      this.buzz = 0,
      this.fans = 0,
      this.energy = 0,
      this.money = 0,
      this.risk = 0,
      this.viral = 0,
      this.stage = false});
  final double hype, devotion, popularity, buzz, fans, energy;

  /// In 2020 dollars' cents, scaled by nothing (a fixed cost).
  final int money;
  final double risk, viral;
  final bool stage;
}

/// A moment waiting for the player (docs K256).
class Moment {
  Moment(
      {required this.kind,
      required this.week,
      required this.scenes,
      this.step = 0,
      this.rivalId = -1,
      this.songId = -1,
      this.crisis = -1});

  final MomentKind kind;
  final int week;

  /// Its scenes in order; a crisis gets its second once the first is
  /// answered.
  final List<MomentScene> scenes;
  int step;

  /// The rival a question is about, the song a stage moment is about.
  final int rivalId, songId;

  /// The [OpportunityKind] of a crisis (-1: none).
  final int crisis;

  MomentScene get scene => scenes[step];

  String encode() => jsonEncode({
        'k': kind.index,
        'w': week,
        's': [for (final s in scenes) s.index],
        't': step,
        'r': rivalId,
        'g': songId,
        'c': crisis,
      });

  static Moment? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final j = jsonDecode(s) as Map<String, Object?>;
    return Moment(
      kind: MomentKind.values[j['k'] as int],
      week: j['w'] as int,
      scenes: [
        for (final x in j['s'] as List) MomentScene.values[x as int]
      ],
      step: j['t'] as int,
      rivalId: j['r'] as int,
      songId: j['g'] as int,
      crisis: j['c'] as int,
    );
  }
}

/// How an answer went (docs K256).
class MomentOutcome {
  const MomentOutcome(
      {required this.scene,
      required this.answer,
      required this.good,
      this.hype = 0,
      this.devotion = 0,
      this.popularity = 0,
      this.fans = 0,
      this.energy = 0,
      this.moneyCents = 0,
      this.viralSongId = -1,
      this.crisis});
  final MomentScene scene;
  final int answer;

  /// It landed (false: it backfired).
  final bool good;
  final double hype, devotion, popularity, fans, energy;
  final int moneyCents;

  /// A song whose clip took off (-1: none).
  final int viralSongId;

  /// A crisis statement's result through the usual crisis answer.
  final OpportunityOutcome? crisis;
}

abstract final class Moments {
  /// Questions in an interview.
  static const questions = 3;

  /// The chance a show week brings a moment on stage.
  static const stageChance = 0.15;

  /// Weeks a moment waits before it passes.
  static const answerWeeks = 2;

  static const _effects = <MomentScene, List<_Effect>>{
    MomentScene.qRelease: [
      _Effect(devotion: 0.01, hype: 0.01),
      _Effect(hype: 0.06, buzz: 0.2, risk: 0.35),
      _Effect(hype: 0.03, fans: 0.002),
    ],
    MomentScene.qRival: [
      _Effect(popularity: 0.01),
      _Effect(buzz: 0.5, hype: 0.04, risk: 0.45),
      _Effect(),
    ],
    MomentScene.qPersonal: [
      _Effect(fans: 0.002),
      _Effect(devotion: 0.03, risk: 0.2),
      _Effect(popularity: -0.005),
    ],
    MomentScene.qIndustry: [
      _Effect(buzz: 0.4, devotion: 0.01, risk: 0.3),
      _Effect(popularity: 0.005),
      _Effect(fans: 0.002, hype: 0.01),
    ],
    MomentScene.qFans: [
      _Effect(devotion: 0.03),
      _Effect(hype: 0.04),
      _Effect(buzz: 0.3, fans: 0.003),
    ],
    MomentScene.qDrama: [
      _Effect(popularity: 0.03),
      _Effect(),
      _Effect(buzz: 0.6, hype: 0.05, risk: 0.5),
    ],
    MomentScene.qFuture: [
      _Effect(hype: 0.03),
      _Effect(hype: 0.05, risk: 0.2),
      _Effect(devotion: 0.01),
    ],
    MomentScene.qInspiration: [
      _Effect(popularity: 0.005),
      _Effect(buzz: 0.3, risk: 0.25),
      _Effect(fans: 0.002),
    ],
    MomentScene.fanOnStage: [
      _Effect(devotion: 0.03, viral: 0.25, stage: true, risk: 0.15),
      _Effect(devotion: -0.01),
      _Effect(popularity: 0.005),
    ],
    MomentScene.soundCut: [
      _Effect(fans: 0.004, viral: 0.3, stage: true, risk: 0.35),
      _Effect(devotion: -0.01, hype: -0.01),
      _Effect(devotion: 0.03, stage: true),
    ],
    MomentScene.starInCrowd: [
      _Effect(buzz: 0.6, hype: 0.05, viral: 0.3, stage: true, risk: 0.2),
      _Effect(fans: 0.002),
      _Effect(),
    ],
    MomentScene.proposal: [
      _Effect(devotion: 0.03, viral: 0.35, stage: true),
      _Effect(devotion: 0.01),
      _Effect(),
    ],
    MomentScene.storm: [
      _Effect(devotion: 0.04, viral: 0.3, energy: 10, stage: true, risk: 0.2),
      _Effect(),
      _Effect(devotion: -0.02, money: -5000000),
    ],
    // The statement's own effects are the crisis answer's (apologize,
    // ignore, lean in); these add nothing.
    MomentScene.crisisStatement: [_Effect(), _Effect(), _Effect()],
    MomentScene.pressSpreading: [
      _Effect(popularity: 0.04, energy: 10, risk: 0.4),
      _Effect(popularity: 0.03, devotion: 0.01, money: -10000000),
      _Effect(popularity: -0.02),
    ],
    MomentScene.pressFading: [
      _Effect(),
      _Effect(buzz: 0.3, hype: 0.02, risk: 0.3),
      _Effect(devotion: 0.02),
    ],
    MomentScene.pressSplit: [
      _Effect(devotion: 0.03),
      _Effect(popularity: 0.03, energy: 10, risk: 0.35),
      _Effect(popularity: -0.01),
    ],
  };

  static const _interviewPool = [
    MomentScene.qRelease,
    MomentScene.qRival,
    MomentScene.qPersonal,
    MomentScene.qIndustry,
    MomentScene.qFans,
    MomentScene.qFuture,
    MomentScene.qInspiration,
  ];

  static const _stagePool = [
    MomentScene.fanOnStage,
    MomentScene.soundCut,
    MomentScene.starInCrowd,
    MomentScene.proposal,
    MomentScene.storm,
  ];

  /// The answer a crisis statement maps to.
  static const statementChoices = [
    OpportunityChoice.apologize,
    OpportunityChoice.ignore,
    OpportunityChoice.leanIn,
  ];

  static RandomStream _r(World w, Artist a, int salt) =>
      RandomStream.keyed(w.seed, w.week, a.id * 16 + salt, RngPurpose.moments);

  /// An interview after the player said yes to one: three questions,
  /// about a rival, and about the beef when there is one.
  static Moment interview(World w, Artist a) {
    final r = _r(w, a, 1);
    final pool = List.of(_interviewPool);
    final rival = _rival(w, a);
    if (rival < 0) pool.remove(MomentScene.qRival);
    final picked = <MomentScene>[];
    // A beef on: they ask about it first.
    if (Beefs.active(w) != null) picked.add(MomentScene.qDrama);
    while (picked.length < questions && pool.isNotEmpty) {
      picked.add(pool.removeAt(r.nextInt(pool.length)));
    }
    final m = Moment(
        kind: MomentKind.interview,
        week: w.week,
        scenes: picked,
        rivalId: rival);
    w.moment = m;
    return m;
  }

  /// A crisis handled step by step: the opportunity [a] is facing.
  static Moment crisis(World w, Artist a) {
    final o = a.opportunity;
    if (o == null || !o.kind.isCrisis || o.kind == OpportunityKind.dissed) {
      throw ActionException('No crisis');
    }
    final m = Moment(
        kind: MomentKind.crisis,
        week: w.week,
        scenes: [MomentScene.crisisStatement],
        crisis: o.kind.index);
    w.moment = m;
    return m;
  }

  /// The biggest rival near the player in fame, or -1.
  static int _rival(World w, Artist a) {
    Artist? best;
    for (final id in w.activeArtistIds) {
      final x = w.artists[id];
      if (x.tier == ArtistTier.player || x.isRetired) continue;
      if (best == null ||
          (x.fame - a.fame).abs() < (best.fame - a.fame).abs()) {
        best = x;
      }
    }
    return best?.id ?? -1;
  }

  /// Before the week: a moment left too long passes; a show week may
  /// bring one on stage.
  static void weekly(World w) {
    final a = w.player;
    if (a == null) return;
    final m = w.moment;
    if (m != null && w.week - m.week >= answerWeeks) w.moment = null;
    if (w.moment != null) return;
    final t = a.tour;
    if (t == null || t.showsIn(w.week).isEmpty) return;
    final r = _r(w, a, 2);
    if (!r.chance(stageChance)) return;
    final scene = _stagePool[r.nextInt(_stagePool.length)];
    final song = t.setlist.isNotEmpty
        ? t.setlist[r.nextInt(t.setlist.length)]
        : _latestSong(w, a);
    w.moment = Moment(
        kind: MomentKind.concert,
        week: w.week,
        scenes: [scene],
        songId: song);
  }

  static int _latestSong(World w, Artist a) {
    for (final id in w.playerSongIds.reversed) {
      final s = w.songs[id];
      if (s.releasedWeek >= 0 && s.status != SongStatus.scrapped) return id;
    }
    return -1;
  }

  /// The player answers the moment's scene with [answer] (0–2).
  static MomentOutcome answer(World w, Artist a, int answer) {
    final m = w.moment;
    if (m == null) throw ActionException('No moment');
    if (answer < 0 || answer > 2) throw ActionException('No such answer');
    final scene = m.scene;
    final r = _r(w, a, 3 + m.step * 4 + answer);
    OpportunityOutcome? crisis;
    if (scene == MomentScene.crisisStatement) {
      if (a.opportunity?.kind.index != m.crisis) {
        w.moment = null;
        throw ActionException('The crisis has passed');
      }
      crisis = Opportunities.answer(w, a, statementChoices[answer]);
      // The press answers: the story spreads, fades or splits people.
      final went = crisis.backfired
          ? MomentScene.pressSpreading
          : crisis.blewOver
              ? MomentScene.pressFading
              : [
                  MomentScene.pressSpreading,
                  MomentScene.pressFading,
                  MomentScene.pressSplit
                ][r.nextInt(3)];
      m.scenes.add(went);
    }
    final e = _effects[scene]![answer];
    final skill =
        (e.stage ? a.skills.performance : a.skills.charisma) / 100;
    final good = e.risk <= 0 || r.chance(1 - e.risk * (1.3 - skill));
    var hype = 0.0, devotion = 0.0, popularity = 0.0, fans = 0.0;
    var energy = 0.0, money = 0;
    var viral = -1;
    if (good) {
      hype = e.hype;
      devotion = e.devotion;
      popularity = e.popularity;
      a.buzz += e.buzz;
      fans = e.fans > 0 ? Audience.addFans(w, a, a.casual * e.fans) : 0;
      if (e.viral > 0 &&
          m.songId >= 0 &&
          r.chance(e.viral * (0.5 + skill))) {
        final s = w.songs[m.songId];
        s.viralBoost = math.max(s.viralBoost, 0.03 + 0.05 * r.nextDouble());
        s.viralRamp = 3;
        w.dirtySongs.add(s.id);
        viral = s.id;
        a.buzz += 0.3;
      }
    } else {
      // It backfired: it looks bad.
      hype = -0.02;
      devotion = -0.01;
      popularity = -0.02 - e.popularity.abs();
    }
    if (e.energy > 0) {
      energy = -math.min(e.energy, a.creativeEnergy);
      a.creativeEnergy += energy;
    }
    if (e.money != 0) {
      money = e.money;
      a.moneyCents += money;
    }
    a.hype = math.max(0.0, a.hype + hype);
    a.devotion = (a.devotion + devotion).clamp(0.0, 1.0);
    a.popularity = math.max(0.0, a.popularity + popularity);
    w.dirtyArtists.add(a.id);
    m.step++;
    if (m.step >= m.scenes.length) w.moment = null;
    return MomentOutcome(
        scene: scene,
        answer: answer,
        good: good,
        hype: hype,
        devotion: devotion,
        popularity: popularity,
        fans: fans,
        energy: energy,
        moneyCents: money,
        viralSongId: viral,
        crisis: crisis);
  }
}
