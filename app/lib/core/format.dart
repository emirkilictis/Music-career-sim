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
      weekOf(GameTime.weekOfYear(week), GameTime.yearOf(week));

  /// "January 2006, week 1": the game's 52 weeks fall into the 12 months.
  String weekOf(int weekOfYear, int year) {
    final (month, inMonth) = monthWeek(weekOfYear);
    return l.weekLabel(monthName(month), inMonth, year);
  }

  /// "January, week 2" (no year) for an absolute game week.
  String weekInMonth(int week) {
    final (month, inMonth) = monthWeek(GameTime.weekOfYear(week));
    return l.weekShort(monthName(month), inMonth);
  }

  /// Month (1–12) and week of that month for week [weekOfYear] (1–52).
  static (int, int) monthWeek(int weekOfYear) {
    final w = weekOfYear.clamp(1, GameTime.weeksPerYear);
    final month = (w - 1) * 12 ~/ GameTime.weeksPerYear + 1;
    final first = ((month - 1) * GameTime.weeksPerYear + 11) ~/ 12 + 1;
    return (month, w - first + 1);
  }

  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthsTr = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  String monthName(int month, {bool short = false}) {
    final name = (_locale.startsWith('tr') ? _monthsTr : _monthsEn)[month - 1];
    return short ? name.substring(0, 3) : name;
  }

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
  /// "2006 · 12" (year and week) for tables.
  String weekShort(int week) {
    final (month, inMonth) = monthWeek(GameTime.weekOfYear(week));
    return '${monthName(month, short: true)} ${GameTime.yearOf(week)} · $inMonth';
  }

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

  /// Pitchwork's one-liner for a review [score] (docs K55).
  String criticBlurb(double score) => score >= 9.5
      ? l.critic10
      : score >= 8.8
          ? l.critic9
          : score >= 8.0
              ? l.critic8
              : score >= 7.0
                  ? l.critic7
                  : score >= 5.5
                      ? l.critic6
                      : score >= 4.0
                          ? l.critic5
                          : l.critic4;

  String criticScore(double score) => score.toStringAsFixed(1);

  String milestoneName(Milestone m) => switch (m) {
        Milestone.firstRelease => l.msFirstRelease,
        Milestone.firstChart => l.msFirstChart,
        Milestone.top40Single => l.msTop40Single,
        Milestone.top10Single => l.msTop10Single,
        Milestone.numberOneSingle => l.msNumberOneSingle,
        Milestone.numberOneAlbum => l.msNumberOneAlbum,
        Milestone.gold => l.msGold,
        Milestone.platinum => l.msPlatinum,
        Milestone.diamond => l.msDiamond,
        Milestone.fans100k => l.msFans100k,
        Milestone.fans1m => l.msFans1m,
        Milestone.fans10m => l.msFans10m,
        Milestone.money1m => l.msMoney1m,
        Milestone.money100m => l.msMoney100m,
        Milestone.billionStreams => l.msBillionStreams,
        Milestone.firstFestival => l.msFirstFestival,
        Milestone.awardWin => l.msAwardWin,
        Milestone.firstTour => l.msFirstTour,
        Milestone.stadiumTour => l.msStadiumTour,
      };

  String platformTagline(MusicPlatform p) => switch (p) {
        MusicPlatform.fruitTunes => l.taglineFruitTunes,
        MusicPlatform.viewTube => l.taglineViewTube,
        MusicPlatform.noiseCloud => l.taglineNoiseCloud,
        MusicPlatform.streamify => l.taglineStreamify,
        MusicPlatform.fruitMusic => l.taglineFruitMusic,
        MusicPlatform.tikTak => l.taglineTikTak,
      };

  /// "12K downloads this week" etc. for the player's numbers on [p].
  String platformWeek(MusicPlatform p, double v) => switch (p.metric) {
        PlatformMetric.downloads => l.platformWeekDownloads(compact(v)),
        PlatformMetric.views => l.platformWeekViews(compact(v)),
        PlatformMetric.plays => l.platformWeekPlays(compact(v)),
        PlatformMetric.videos => l.platformWeekVideos(compact(v)),
      };

  String managerName(Manager m) => switch (m) {
        Manager.none => l.managerNone,
        Manager.local => l.managerLocal,
        Manager.pro => l.managerPro,
        Manager.star => l.managerStar,
      };

  String managerTerms(Manager m) => m == Manager.none
      ? l.managerNoneHint
      : l.managerTerms(
          (m.commission * 100).round(),
          m.offerBoost.toStringAsFixed(1),
          m.feeBoost.toStringAsFixed(1),
          (m.tourCut * 100).round());

  String tourKind(TourKind k) => switch (k) {
        TourKind.club => l.tourClub,
        TourKind.theater => l.tourTheater,
        TourKind.arena => l.tourArena,
        TourKind.stadium => l.tourStadium,
      };

  String tourMarket(TourMarket m) => switch (m) {
        TourMarket.usa => l.marketUsa,
        TourMarket.canada => l.marketCanada,
        TourMarket.ukIreland => l.marketUk,
        TourMarket.europe => l.marketEurope,
        TourMarket.latinAmerica => l.marketLatAm,
        TourMarket.asia => l.marketAsia,
        TourMarket.oceania => l.marketOceania,
      };

  String tourProduction(TourProduction p) => switch (p) {
        TourProduction.basic => l.tourProdBasic,
        TourProduction.standard => l.tourProdStandard,
        TourProduction.spectacle => l.tourProdSpectacle,
      };

  /// The player's name for a tour, else named after its biggest venues.
  String tourName(String name, TourKind kind) =>
      name.isEmpty ? tourKind(kind) : name;

  String offerTitle(OpportunityKind k) => switch (k) {
        OpportunityKind.interview => l.offerInterviewTitle,
        OpportunityKind.feature => l.offerFeatureTitle,
        OpportunityKind.festival => l.offerFestivalTitle,
        OpportunityKind.brandDeal => l.offerBrandTitle,
        OpportunityKind.scandal => l.offerScandalTitle,
        OpportunityKind.award => l.offerAwardTitle,
      };

  String offerBody(OpportunityView o) => switch (o.kind) {
        OpportunityKind.interview =>
          l.offerInterviewBody(Opportunities.interviewEnergy.round()),
        OpportunityKind.feature => l.offerFeatureBody(o.partnerName,
            money(o.feeCents), Opportunities.featureEnergy.round()),
        OpportunityKind.festival => l.offerFestivalBody(
            money(o.feeCents), Opportunities.festivalEnergy.round()),
        OpportunityKind.brandDeal => l.offerBrandBody(money(o.feeCents)),
        OpportunityKind.scandal => l.offerScandalBody,
        OpportunityKind.award =>
          l.offerAwardBody(Opportunities.performEnergy.round()),
      };

  String offerChoice(OpportunityKind k, OpportunityChoice c) => switch (c) {
        OpportunityChoice.accept =>
          k == OpportunityKind.award ? l.choiceAttend : l.choiceAccept,
        OpportunityChoice.decline =>
          k == OpportunityKind.award ? l.choiceStayHome : l.choiceDecline,
        OpportunityChoice.apologize => l.choiceApologize,
        OpportunityChoice.ignore => l.choiceIgnore,
        OpportunityChoice.leanIn => l.choiceLeanIn,
        OpportunityChoice.perform => l.choicePerform,
      };

  /// What an answer did (shown right after it, or in the news if it lapsed).
  String offerOutcome(OpportunityOutcome o) {
    final fans = compact(o.fans);
    return switch ((o.kind, o.choice)) {
      (OpportunityKind.scandal, OpportunityChoice.apologize) =>
        l.outcomeApologize,
      (OpportunityKind.scandal, OpportunityChoice.ignore) =>
        o.blewOver ? l.outcomeIgnoreOk : l.outcomeIgnoreBad,
      (OpportunityKind.scandal, _) => l.outcomeLeanIn(fans),
      (OpportunityKind.award, OpportunityChoice.decline) =>
        l.outcomeAwardSkipped,
      (OpportunityKind.award, _) =>
        o.won ? l.outcomeAwardWon : l.outcomeAwardLost(fans),
      (_, OpportunityChoice.decline) => l.outcomeDeclined,
      (OpportunityKind.interview, _) => l.outcomeInterview(fans),
      (OpportunityKind.feature, _) =>
        l.outcomeFeature(fans, money(o.moneyCents)),
      (OpportunityKind.festival, _) =>
        l.outcomeFestival(fans, money(o.moneyCents)),
      (OpportunityKind.brandDeal, _) => l.outcomeBrand(money(o.moneyCents)),
    };
  }

  String labelName(Label x) => switch (x) {
        Label.independent => l.labelIndependent,
        Label.small => l.labelSmall,
        Label.mid => l.labelMid,
        Label.major => l.labelMajor,
        Label.giant => l.labelGiant,
      };

  String labelKind(Label x) => switch (x) {
        Label.independent => l.labelKindIndependent,
        Label.small => l.labelKindSmall,
        Label.mid => l.labelKindMid,
        Label.major => l.labelKindMajor,
        Label.giant => l.labelKindGiant,
      };

  String videoBudget(VideoBudget b) => switch (b) {
        VideoBudget.low => l.videoLow,
        VideoBudget.medium => l.videoMedium,
        VideoBudget.high => l.videoHigh,
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
        AlbumType.mixtape => l.typeMixtape,
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
              : g >= 55
                  ? 'C'
                  : g >= 40
                      ? 'D'
                      : 'E';

  /// "B" or "C–A": the team's range while a song is in the vault (docs
  /// F36).
  String gradeRange(int lo, int hi) {
    final a = grade(lo), b = grade(hi);
    return a == b ? a : '$a–$b';
  }

  /// What the player sees: the real grade once out, the range before.
  String songGrade(SongView s) =>
      s.grade >= 0 ? grade(s.grade) : gradeRange(s.gradeLow, s.gradeHigh);

  String error(Object e) {
    if (e is! GameException) return l.errorGeneric;
    return switch (e.code) {
      'notEnoughMoney' => l.errorNotEnoughMoney,
      'resting' => l.errorResting,
      'noSkillPoints' => l.errorNoSkillPoints,
      'invalidDate' => l.errorInvalidDate,
      'songScheduled' => l.errorSongScheduled,
      'hasVideo' => l.errorHasVideo,
      'campaignLocked' => l.errorCampaignLocked,
      'underContract' => l.errorUnderContract,
      'labelRefused' => l.errorLabelRefused,
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
      StillNumberOne() =>
        l.eventStillNumberOne(t, chart(e.chartId), e.weeksAtNo1),
      ChartDebut() => l.eventDebut(t, chart(e.chartId), e.position),
      NewPeak() => l.eventNewPeak(t, chart(e.chartId), e.position),
      AlbumFirstWeek() => e.usPosition > 0
          ? l.eventAlbumFirstWeek(
              t, compact(e.usUnits), e.usPosition, compact(e.globalUnits))
          : l.eventAlbumFirstWeekNoChart(
              t, compact(e.usUnits), compact(e.globalUnits)),
      ViralTrend() => e.shortVideo ? l.eventViral(t) : l.eventViralVideo(t),
      PlaylistAdded() => e.size == PlaylistAdd.big
          ? l.eventPlaylistBig(t, platformName)
          : l.eventPlaylistMid(t, platformName),
      EraClosed() => l.eventEraClosed(eraResult(e.result)),
      BurnoutOver() => l.eventBurnoutOver,
      ReleaseOut() => l.eventReleaseOut(t),
      LabelOffer() => l.eventLabelOffer(labelName(e.label)),
      CriticReview() =>
        l.eventCriticReview(t, criticScore(e.score), criticBlurb(e.score)),
      LabelDropped() => l.eventLabelDropped(labelName(e.label)),
      OpportunityCame() => l.eventOfferCame(offerTitle(e.kind)),
      PlatformOpened(:final platform) =>
        l.eventPlatformOpened(platform.displayName, platformTagline(platform)),
      ChartBattle() => () {
          String pos(int p) => p > 0 ? '#$p' : l.offChart;
          return e.won
              ? l.battleWon(t, pos(e.playerPosition), line.artistName,
                  pos(e.rivalPosition))
              : l.battleLost(t, pos(e.playerPosition), line.artistName,
                  pos(e.rivalPosition));
        }(),
      TourFinished() => l.eventTourFinished(tourName(e.name, e.kind), e.shows,
          e.soldOut, compact(e.tickets), money(e.netCents), compact(e.fans)),
      MilestoneReached(:final milestone) =>
        l.eventMilestone(milestoneName(milestone), milestone.skillPoints),
      OpportunityLapsed() => e.outcome.kind == OpportunityKind.scandal
          ? offerOutcome(e.outcome)
          : l.eventOfferLapsed(offerTitle(e.outcome.kind)),
      ReleaseAnnounced() => l.eventReleaseAnnounced(t, week(e.releaseWeek)),
      PlatformLaunched() => e.chartId == Charts.platformGlobal
          ? l.eventPlatformLaunched(platformName)
          : l.eventPlatformArrived(platformName, l.regionNorthAmerica),
      RivalNumberOne() =>
        l.eventRivalNumberOne(line.artistName, t, chart(e.chartId)),
    };
  }
}
