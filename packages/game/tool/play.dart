// Playtest from the terminal on a real save slot (docs/feedback.md):
//
//   dart run tool/play.dart <saveDir> new "<name>" <genre> [year] [legend|normal|hard]
//   dart run tool/play.dart <saveDir> status | collabs | vault | releases
//   dart run tool/play.dart <saveDir> write <low|medium|high> [producerId] [cowriterId] [genres,..]
//   dart run tool/play.dart <saveDir> single <songId> [none|standard|intensive|global]
//   dart run tool/play.dart <saveDir> album "<title>" <ep|album> <campaign> <songId>...
//   dart run tool/play.dart <saveDir> week [n] | job <none|cafe|...> | ad | rest
//   dart run tool/play.dart <saveDir> chart <chartId> [rows]
//   dart run tool/play.dart <saveDir> -     (one command per line from stdin)
import 'dart:io';

import 'package:game/game.dart';

const _slot = 'playtest';

void main(List<String> args) {
  final slots = SaveSlots(Directory(args[0]));
  final cmd = args[1];
  final rest = args.sublist(2);
  if (cmd == 'new') {
    final s = GameSession.start(
      slots,
      CareerSetup(
        name: rest[0],
        genre: int.parse(rest[1]),
        startYear: rest.length > 2 ? int.parse(rest[2]) : 2025,
        difficulty: rest.length > 3
            ? Difficulty.values.byName(rest[3])
            : Difficulty.normal,
      ),
      slotId: _slot,
    );
    _status(s);
    s.close();
    return;
  }
  final s = GameSession.resume(slots, _slot);
  try {
    if (cmd != '-') return _run(s, cmd, rest);
    String? line;
    while ((line = stdin.readLineSync()) != null) {
      final words = [
        for (final m in RegExp(r'"([^"]*)"|(\S+)').allMatches(line!))
          m.group(1) ?? m.group(2)!
      ];
      if (words.isEmpty || words.first.startsWith('#')) continue;
      print('> $line');
      try {
        _run(s, words.first, words.sublist(1));
      } on GameException catch (e) {
        print('REFUSED: $e');
      }
    }
  } on GameException catch (e) {
    print('REFUSED: $e');
  } finally {
    s.close();
  }
}

void _run(GameSession s, String cmd, List<String> rest) {
  {
    switch (cmd) {
      case 'status':
        _status(s);
      case 'collabs':
        for (final role in CollaboratorRole.values) {
          print('-- ${role.name}');
          for (final c in s.collaborators(role)) {
            print('  #${c.id} ${c.name.padRight(22)} skill ${c.skill.round()}'
                '  ${genreNames[c.genre].padRight(10)} fee \$${c.feeCents ~/ 100}'
                '${c.available ? '' : '  (locked)'}');
          }
        }
      case 'write':
        final song = s.writeSong(
          budget: BudgetTier.values.byName(rest[0]),
          producerId:
              rest.length > 1 && rest[1] != '-' ? int.parse(rest[1]) : null,
          cowriterId:
              rest.length > 2 && rest[2] != '-' ? int.parse(rest[2]) : null,
          genres: rest.length > 3
              ? rest[3].split(',').map(int.parse).toList()
              : null,
        );
        print(
            'Wrote #${song.id} "${song.title}" grade ${_grade(song.estimatedGrade)}'
            ' (${song.estimatedGrade})');
        _status(s);
      case 'vault':
        for (final song in s.songs) {
          print('#${song.id} "${song.title}" ${_grade(song.estimatedGrade)}'
              ' ${song.status.name}${song.isSingle ? ' single' : ''}'
              ' streams ${_c(song.lifetimeStreams.total)}'
              ' wk ${_c(song.weekStreams)}'
              ' ${song.charts.map((c) => '${Charts.all[c.chartId].key}:${c.lastPos}/pk${c.peak}').join(' ')}');
        }
      case 'releases':
        for (final al in s.albums) {
          print(
              '#${al.id} "${al.title}" ${al.type.name} fw US ${_c(al.firstWeekUsUnits)}'
              ' global ${_c(al.firstWeekUnits)} wk ${_c(al.weekUnits)}'
              ' ${al.charts.map((c) => '${Charts.all[c.chartId].key}:${c.lastPos}/pk${c.peak}').join(' ')}');
        }
      case 'single':
        s.releaseSingle(int.parse(rest[0]),
            campaign: rest.length > 1
                ? Campaign.values.byName(rest[1])
                : Campaign.none);
        print('Released.');
        _status(s);
      case 'album':
        final al = s.releaseAlbum(
          rest[0],
          rest.sublist(3).map(int.parse).toList(),
          type: AlbumType.values.byName(rest[1]),
          campaign: Campaign.values.byName(rest[2]),
        );
        print('Released album #${al.id}.');
        _status(s);
      case 'job':
        s.setJob(Job.values.byName(rest[0]));
        _status(s);
      case 'rest':
        s.rest();
        _status(s);
      case 'ad':
        s.rewardAd();
        _status(s);
      case 'week':
        final n = rest.isEmpty ? 1 : int.parse(rest[0]);
        for (var i = 0; i < n; i++) {
          final r = s.advanceWeek();
          final ev = r.events.map((e) => _event(s, e)).join('; ');
          print('${_week(r.week)}  money ${r.moneyDeltaCents >= 0 ? '+' : ''}'
              '\$${r.moneyDeltaCents ~/ 100}  $ev');
        }
        for (final song in s.songs.where((x) => !x.inVault).take(5)) {
          print('  #${song.id} "${song.title}" wk ${_c(song.weekStreams)}'
              ' total ${_c(song.lifetimeStreams.total)}');
        }
        _status(s);
      case 'chart':
        final c = s.chart(int.parse(rest[0]));
        final n = rest.length > 1 ? int.parse(rest[1]) : 10;
        print('${c.def.key} ${_week(c.week)}');
        for (final r in c.rows.take(n)) {
          print('${r.position.toString().padLeft(3)} ${r.isPlayer ? '*' : ' '}'
              ' ${r.title} — ${r.artistName}  ${_c(r.weekValue)}'
              '  lw ${r.lastPos} pk ${r.peak} wks ${r.weeksOn}');
        }
        final mine = c.rows.where((r) => r.isPlayer && r.position > n);
        for (final r in mine) {
          print(
              '${r.position.toString().padLeft(3)} * ${r.title}  ${_c(r.weekValue)}');
        }
      default:
        print('Unknown command $cmd');
    }
  }
}

void _status(GameSession s) {
  final p = s.player;
  print('[${_week(s.week)}] ${p.name}  \$${p.moneyCents ~/ 100}'
      '  fame ${(p.fame * 100).toStringAsFixed(1)}%'
      '  pop ${(p.popularity * 100).toStringAsFixed(1)}%'
      '  dev ${(p.devotion * 100).round()}%'
      '  fans ${_c(p.coreFans)} listeners ${_c(p.casualListeners)}'
      '  energy ${p.creativeEnergy.round()} written ${p.songsWrittenThisWeek}'
      '  ads ${p.adsLeftThisWeek} job ${p.job.name}'
      '  hype ${(p.hype * 100).round()}% antic ${(p.anticipation * 100).round()}%');
}

String _week(int w) => 'W${GameTime.weekOfYear(w)} ${GameTime.yearOf(w)}';

String _c(num v) => v >= 1e6
    ? '${(v / 1e6).toStringAsFixed(2)}M'
    : v >= 1e3
        ? '${(v / 1e3).toStringAsFixed(1)}K'
        : v.round().toString();

String _grade(int g) => g >= 90
    ? 'A+'
    : g >= 80
        ? 'A'
        : g >= 70
            ? 'B'
            : g >= 58
                ? 'C'
                : g >= 45
                    ? 'D'
                    : 'E';

String _event(GameSession s, GameEvent e) => switch (e) {
      NumberOne() => '#1 on ${Charts.all[e.chartId].key} (${e.weeksAtNo1} wk)',
      CriticReview() => 'review ${e.score}',
      LabelOffer() => 'label offer: ${e.label.name}',
      LabelDropped() => 'dropped by ${e.label.name}',
      StillNumberOne() =>
        'still #1 on ${Charts.all[e.chartId].key} (${e.weeksAtNo1} wk)',
      ChartDebut() =>
        'debut #${e.position} ${Charts.all[e.chartId].key} (${e.kind.name} ${e.entityId})',
      NewPeak() => 'new peak #${e.position} ${Charts.all[e.chartId].key}',
      AlbumFirstWeek() =>
        'album first week US ${_c(e.usUnits)} (#${e.usPosition}) global ${_c(e.globalUnits)}',
      ViralTrend() => 'VIRAL song ${e.songId}',
      PlaylistAdded() => 'playlist ${e.size.name} song ${e.songId}',
      CatchingOn() => 'word of mouth: song ${e.songId}',
      TopArtist() => 'top artists #${e.rank}',
      DiscoverPick() => 'discover mix: song ${e.songId}',
      AdvanceRecouped() => 'advance recouped (${e.label.name})',
      VideoMilestone() => 'video ${e.songId} passed ${e.views} views',
      StreamMilestone() => 'song ${e.songId} passed ${e.plays} plays',
      MusicShowResult() => e.won
          ? 'music show win #${e.wins} song ${e.songId}'
          : 'music show 2nd song ${e.songId}',
      RecordBroken() => 'record ${e.kind.name}: ${e.entityId} ${e.value}',
      SurpriseDrop() => 'surprise drop: album ${e.albumId}',
      WrappedOut() =>
        'wrapped ${e.year}: ${e.plays.round()} plays, ${e.story.name}',
      YearEndCharts() =>
        'year-end ${e.year}: songs ${e.songs} albums ${e.albums}',
      RivalAlbumClash() => e.clash.moved
          ? 'rival ${e.clash.artistId} moved album to week ${e.clash.toWeek}'
          : 'rival ${e.clash.artistId} stays: same week as your album',
      EraClosed() =>
        'era closed: ${e.result.name} (${_c(e.units)} vs exp ${_c(e.expected)})',
      BurnoutOver() => 'burnout over',
      RivalNumberOne() => 'rival #1 ${Charts.all[e.chartId].key}',
      PlatformLaunched() => 'platform launched ${Charts.all[e.chartId].key}',
      HolidaySeason() => 'holiday season: gift buying until Christmas',
      ReleaseOut() => 'scheduled ${e.kind.name} ${e.entityId} out',
      ReleaseAnnounced() => 'announced "${e.title}" for week ${e.releaseWeek}',
      OpportunityCame() => 'offer: ${e.kind.name}',
      OpportunityLapsed() => 'offer lapsed: ${e.outcome.kind.name}',
      MilestoneReached() => 'milestone ${e.milestone.name}',
      TourFinished() => 'tour ${e.kind.name} done: net ${e.netCents ~/ 100}',
      PlatformOpened() => 'platform opened ${e.platform.displayName}',
      AwardNominated() =>
        'nominated at the ${e.year} awards: ${e.categories.map((c) => c.name).join(', ')}',
      AwardResults() =>
        'awards ${e.year}: won ${e.won.length} of ${e.nominations}',
      AwardWinners() => 'awards ${e.year} winners',
      BotsCaught() => 'bots caught: ${e.removed.round()} removed',
      RivalBotsCaught() => 'rival bots caught',
      PitchDeclined() => 'pitch declined',
      CreatorsFlopped() => 'creator campaign flopped ${e.songId}',
      HolidayReturn() => 'holiday song ${e.songId} is back',
      SongLeaked() => 'song ${e.songId} leaked',
      SalesMilestone() => 'sold ${e.copies} records',
      AllTimeBestSeller() => 'all-time best seller #${e.rank}',
      WrittenSongHit() => 'your song ${e.songId} for ${e.artistId} at #${e.position}',
      ClubMilestone() => 'fan club passed ${e.members} members',
      CuratorsAnswered() => 'curators: ${e.adds}/${e.sent} added ${e.songId}',
      PlaylistMilestone() => 'playlist passed ${e.followers} followers',
      CreditSongHit() => '${e.credit.name} song ${e.songId} by ${e.artistId} at #${e.position}',
      ListenersMilestone() => 'monthly listeners passed ${e.listeners}',
      AlbumStreamMilestone() => 'album ${e.albumId} passed ${e.streams} streams',
      SongOfSummer() => 'summer ${e.year}: #1 ${e.topSongId}, you #${e.playerRank}',
      BrandDealBroken() => 'brand deal broken: ${e.brand.name}',
      FestivalPlayed() =>
        'festival ${e.festival} (${e.slot.name}): ${_c(e.watched)} watched',
      ChartBattle() =>
        'battle ${e.won ? 'won' : 'lost'} #${e.playerPosition} vs #${e.rivalPosition}',
    };
