import 'package:game/game.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import 'event_lines.dart';

/// Fictional streaming platform name (docs K15). One place to rename it.
const platformName = 'Streamify';

/// Number and text formatting shared by all screens.
class Fmt {
  Fmt(this.l);
  final AppLocalizations l;

  String get _locale => l.localeName;

  /// 1.2M, 34K, 950.
  String compact(num v) =>
      NumberFormat.compact(locale: _locale).format(v.round());

  String number(num v) =>
      NumberFormat.decimalPattern(_locale).format(v.round());

  /// Whole dollars; compact above $100K.
  String money(int cents) {
    final dollars = cents / 100;
    if (dollars.abs() >= 100000) {
      return '\$${NumberFormat.compact(locale: _locale).format(dollars)}';
    }
    return NumberFormat.currency(
            locale: _locale, symbol: '\$', decimalDigits: 0)
        .format(dollars);
  }

  String signedMoney(int cents) =>
      cents >= 0 ? '+${money(cents)}' : '−${money(-cents)}';

  String percent(double v) => '${(v * 100).round()}%';

  String week(int week) =>
      l.weekLabel(GameTime.weekOfYear(week), GameTime.yearOf(week));

  String genre(int g) => switch (g) {
        0 => l.genrePop,
        1 => l.genreHipHop,
        2 => l.genreRnb,
        3 => l.genreRock,
        4 => l.genreCountry,
        5 => l.genreDance,
        6 => l.genreLatin,
        7 => l.genreIndie,
        8 => l.genreMetal,
        9 => l.genrePunk,
        10 => l.genreSoul,
        11 => l.genreFunk,
        12 => l.genreDisco,
        13 => l.genreJazz,
        14 => l.genreBlues,
        15 => l.genreFolk,
        16 => l.genreReggae,
        17 => l.genreAfrobeats,
        18 => l.genreKpop,
        19 => l.genreGospel,
        20 => l.genreClassical,
        _ => genreNames[g],
      };

  String genres(List<int> gs) => gs.map(genre).join(' · ');

  String chart(int id) => switch (id) {
        Charts.usSongs => l.chartUsSongs,
        Charts.ukSongs => l.chartUkSongs,
        Charts.globalSongs => l.chartGlobalSongs,
        Charts.usAlbums => l.chartUsAlbums,
        Charts.ukAlbums => l.chartUkAlbums,
        Charts.globalAlbums => l.chartGlobalAlbums,
        Charts.platformGlobal => l.chartPlatform(platformName, l.regionGlobal),
        Charts.platformNorthAmerica =>
          l.chartPlatform(platformName, l.regionNorthAmerica),
        Charts.platformEurope => l.chartPlatform(platformName, l.regionEurope),
        _ => '?',
      };

  /// Short chart name for compact lists.
  String chartShort(int id) => switch (id) {
        Charts.usSongs => l.chartShortUs,
        Charts.ukSongs => l.chartShortUk,
        Charts.globalSongs => l.chartShortGlobal,
        Charts.usAlbums => l.chartShortUsAlbums,
        Charts.ukAlbums => l.chartShortUkAlbums,
        Charts.globalAlbums => l.chartShortGlobalAlbums,
        _ => chart(id),
      };

  String region(Region r) => switch (r) {
        Region.northAmerica => l.regionNorthAmerica,
        Region.europe => l.regionEurope,
        Region.other => l.regionOther,
      };

  String home(HomeCountry h) => switch (h) {
        HomeCountry.us => l.homeUs,
        HomeCountry.canada => l.homeCanada,
        HomeCountry.uk => l.homeUk,
        HomeCountry.europe => l.homeEurope,
        HomeCountry.other => l.homeOther,
      };

  String kind(ArtistKind k) => switch (k) {
        ArtistKind.solo => l.kindSolo,
        ArtistKind.band => l.kindBand,
        ArtistKind.vocalGroup => l.kindVocalGroup,
      };

  String tier(StartTier t) => switch (t) {
        StartTier.unknown => l.tierUnknown,
        StartTier.localBuzz => l.tierLocalBuzz,
        StartTier.risingStar => l.tierRisingStar,
        StartTier.superstar => l.tierSuperstar,
      };

  String startMoney(StartMoney m) => switch (m) {
        StartMoney.basic => l.moneyBasic,
        StartMoney.comfortable => l.moneyComfortable,
        StartMoney.millionaire => l.moneyMillionaire,
      };

  String path(CareerPath p) => switch (p) {
        CareerPath.independent => l.pathIndependent,
        CareerPath.smallLabel => l.pathSmallLabel,
      };

  String difficulty(Difficulty d) => switch (d) {
        Difficulty.legend => l.difficultyLegend,
        Difficulty.normal => l.difficultyNormal,
        Difficulty.hard => l.difficultyHard,
      };

  String budget(BudgetTier b) => switch (b) {
        BudgetTier.low => l.budgetLow,
        BudgetTier.medium => l.budgetMedium,
        BudgetTier.high => l.budgetHigh,
      };

  String job(Job j) => switch (j) {
        Job.none => l.jobNone,
        Job.cafe => l.jobCafe,
        Job.musicTeacher => l.jobMusicTeacher,
        Job.studioAssistant => l.jobStudioAssistant,
        Job.barGigs => l.jobBarGigs,
        Job.nightShift => l.jobNightShift,
      };

  String jobPerk(Job j) => switch (j) {
        Job.none => l.jobPerkNone,
        Job.cafe => l.jobPerkCafe,
        Job.musicTeacher => l.jobPerkMusicTeacher,
        Job.studioAssistant => l.jobPerkStudioAssistant,
        Job.barGigs => l.jobPerkBarGigs,
        Job.nightShift => l.jobPerkNightShift,
      };

  String campaign(Campaign c) => switch (c) {
        Campaign.none => l.campaignNone,
        Campaign.standard => l.campaignStandard,
        Campaign.intensive => l.campaignIntensive,
        Campaign.global => l.campaignGlobal,
      };

  String editionFormat(EditionFormat? f) => switch (f) {
        null => l.editionStandard,
        EditionFormat.cd => l.formatCd,
        EditionFormat.vinyl => l.formatVinyl,
        EditionFormat.cassette => l.formatCassette,
        EditionFormat.deluxe => l.formatDeluxe,
        EditionFormat.signed => l.formatSigned,
      };

  /// How collectors take a format in [year] (docs K46).
  String formatAppeal(EditionFormat f, int year) {
    final a = f.appeal(year);
    return a >= 1.0
        ? l.formatAppealHigh
        : a >= 0.7
            ? l.formatAppealMid
            : l.formatAppealLow;
  }

  String albumType(AlbumType t) => switch (t) {
        AlbumType.single => l.typeSingle,
        AlbumType.ep => l.typeEp,
        AlbumType.album => l.typeAlbum,
      };

  String eraResult(EraResult r) => switch (r) {
        EraResult.flop => l.eraFlop,
        EraResult.disappointing => l.eraDisappointing,
        EraResult.normal => l.eraNormal,
        EraResult.success => l.eraSuccess,
        EraResult.smash => l.eraSmash,
      };

  /// A song's headline number for the year being played (docs K38):
  /// single sales until 2011, streams after. E.g. "1.2M sold".
  String songMain(SongView s, int week) =>
      SalesEra.of(GameTime.yearOf(week)) == SalesEra.streaming
          ? l.streamsValue(compact(s.lifetimeStreams.total))
          : l.singleSalesValue(compact(s.singleSales));

  /// Sort key that matches [songMain].
  double songMainValue(SongView s, int week) =>
      SalesEra.of(GameTime.yearOf(week)) == SalesEra.streaming
          ? s.lifetimeStreams.total
          : s.singleSales;

  /// The second number worth showing: radio in the CD era, streams in the
  /// download era, sales in the streaming era. Empty when it is zero.
  String songSecondary(SongView s, int week) {
    final (v, text) = switch (SalesEra.of(GameTime.yearOf(week))) {
      SalesEra.physical => (s.lifetimeRadio, l.radioValue),
      SalesEra.downloads => (s.lifetimeStreams.total, l.streamsValue),
      SalesEra.streaming => (s.singleSales, l.singleSalesValue),
    };
    return v < 1 ? '' : text(compact(v));
  }

  String songStatus(SongView s) => s.inVault
      ? l.statusVault
      : s.isSingle
          ? l.typeSingle
          : l.statusAlbumTrack;

  /// Letter grade for the team's estimate (hidden quality is never shown).
  String grade(int g) => g >= 90
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

  String error(Object e) {
    if (e is! GameException) return l.errorGeneric;
    return switch (e.code) {
      'notEnoughMoney' => l.errorNotEnoughMoney,
      'resting' => l.errorResting,
      'noSkillPoints' => l.errorNoSkillPoints,
      'invalidDate' => l.errorInvalidDate,
      'alreadyScheduled' => l.errorAlreadyScheduled,
      'skillMaxed' => l.errorSkillMaxed,
      'burnout' => l.errorBurnout,
      'collaboratorRefused' => l.errorCollaboratorRefused,
      'alreadyWrote' => l.errorAlreadyWrote,
      'invalidGenres' => l.errorInvalidGenres,
      'invalidTitle' => l.errorInvalidTitle,
      'alreadySingle' => l.errorAlreadySingle,
      'trackCount' => l.errorTrackCount,
      'trackOnOtherRelease' => l.errorTrackTaken,
      'adLimit' => l.errorAdLimit,
      'premiumRequired' => l.errorPremiumRequired,
      'invalidName' => l.errorInvalidName,
      'invalidMembers' => l.errorInvalidMembers,
      'invalidSkills' => l.errorInvalidSkills,
      _ => l.errorGeneric,
    };
  }

  /// The sentence for one piece of news.
  String event(EventLine line) {
    final e = line.event;
    final t = line.title;
    return switch (e) {
      NumberOne() => e.isFirstTime
          ? l.eventNumberOne(t, chart(e.chartId))
          : l.eventNumberOneAgain(t, chart(e.chartId), e.weeksAtNo1),
      ChartDebut() => l.eventDebut(t, chart(e.chartId), e.position),
      NewPeak() => l.eventNewPeak(t, chart(e.chartId), e.position),
      AlbumFirstWeek() => e.usPosition > 0
          ? l.eventAlbumFirstWeek(
              t, compact(e.usUnits), e.usPosition, compact(e.globalUnits))
          : l.eventAlbumFirstWeekNoChart(
              t, compact(e.usUnits), compact(e.globalUnits)),
      ViralTrend() => l.eventViral(t),
      PlaylistAdded() => e.size == PlaylistAdd.big
          ? l.eventPlaylistBig(t, platformName)
          : l.eventPlaylistMid(t, platformName),
      EraClosed() => l.eventEraClosed(eraResult(e.result)),
      BurnoutOver() => l.eventBurnoutOver,
      ReleaseOut() => l.eventReleaseOut(t),
      ReleaseAnnounced() => l.eventReleaseAnnounced(t, week(e.releaseWeek)),
      PlatformLaunched() => e.chartId == Charts.platformGlobal
          ? l.eventPlatformLaunched(platformName)
          : l.eventPlatformArrived(platformName, l.regionNorthAmerica),
      RivalNumberOne() =>
        l.eventRivalNumberOne(line.artistName, t, chart(e.chartId)),
    };
  }
}
