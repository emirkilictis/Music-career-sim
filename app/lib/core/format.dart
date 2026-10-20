import 'package:game/game.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import 'social_text.dart';
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

  /// "October 2014" for an absolute game week.
  String monthYear(int week) {
    final (month, _) = monthWeek(GameTime.weekOfYear(week));
    return '${monthName(month)} ${GameTime.yearOf(week)}';
  }

  String brandCategory(BrandCategory c) => switch (c) {
        BrandCategory.fashion => l.brandFashion,
        BrandCategory.beverage => l.brandBeverage,
        BrandCategory.tech => l.brandTech,
        BrandCategory.beauty => l.brandBeauty,
        BrandCategory.luxury => l.brandLuxury,
        BrandCategory.sportswear => l.brandSportswear,
        BrandCategory.fastFood => l.brandFastFood,
        BrandCategory.gaming => l.brandGaming,
        BrandCategory.auto => l.brandAuto,
      };

  String dealTask(DealTask t) => switch (t) {
        DealTask.sponsoredPost => l.taskSponsoredPost,
        DealTask.adShoot => l.taskAdShoot,
        DealTask.launchEvent => l.taskLaunchEvent,
      };

  /// How fans will take a brand that fits this well (docs K102).
  String brandFit(double fit) => fit >= 0.75
      ? l.fitGreat
      : fit >= 0.5
          ? l.fitOk
          : l.fitPoor;

  String network(SocialNetwork n) => switch (n) {
        SocialNetwork.forum => l.networkForum,
        SocialNetwork.myPlace => l.networkMyPlace,
        SocialNetwork.chirper => l.networkChirper,
      };

  String postKind(PostKind k) => switch (k) {
        PostKind.teaser => l.postTeaser,
        PostKind.studio => l.postStudio,
        PostKind.fans => l.postFans,
        PostKind.hotTake => l.postHotTake,
        PostKind.promote => l.postPromote,
      };

  String postKindHint(PostKind k) => switch (k) {
        PostKind.teaser => l.postTeaserHint,
        PostKind.studio => l.postStudioHint,
        PostKind.fans => l.postFansHint,
        PostKind.hotTake => l.postHotTakeHint,
        PostKind.promote => l.postPromoteHint,
      };

  /// The words of a feed item (docs K93).
  String social(SocialItemView i, String playerName) => socialText(
        l,
        i.topic,
        i.variant,
        title: i.title,
        name: playerName,
        n: switch (i.topic) {
          FanTopic.bigWeek => compact(i.number.toDouble()),
          FanTopic.criticHigh ||
          FanTopic.criticLow =>
            (i.number / 10).toStringAsFixed(1),
          _ => '${i.number}',
        },
      );

  /// "this week", "3 wk ago".
  String feedAge(int week, int now) =>
      week >= now ? l.feedThisWeek : l.feedWeeksAgo(now - week);

  String songVersion(SongVersion v) => switch (v) {
        SongVersion.remix => l.versionRemix,
        SongVersion.spedUp => l.versionSpedUp,
        SongVersion.slowed => l.versionSlowed,
        SongVersion.acapella => l.versionAcapella,
        SongVersion.instrumental => l.versionInstrumental,
      };

  String singleFormat(SingleFormat f) => switch (f) {
        SingleFormat.cd => l.formatCdSingle,
        SingleFormat.vinyl => l.formatVinylSingle,
        SingleFormat.cassette => l.formatCassetteSingle,
        SingleFormat.signed => l.formatSignedSingle,
      };

  /// A Golden Record Awards category (docs K91).
  String awardCategory(AwardCategory c, [int genre = -1]) => switch (c) {
        AwardCategory.record => l.awardRecord,
        AwardCategory.song => l.awardSong,
        AwardCategory.album => l.awardAlbum,
        AwardCategory.newArtist => l.awardNewArtist,
        AwardCategory.genreAlbum =>
          l.awardGenreAlbum(genre >= 0 ? this.genre(genre) : ''),
      };

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
        Charts.usRadio => l.chartUsRadio,
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
        Charts.usRadio => l.chartShortUsRadio,
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

  String radioPush(RadioPush r) => switch (r) {
        RadioPush.none => l.radioNone,
        RadioPush.standard => l.radioStandard,
        RadioPush.heavy => l.radioHeavy,
        RadioPush.light => l.radioLight,
        RadioPush.blitz => l.radioBlitz,
      };

  String radioPushHint(RadioPush r) => switch (r) {
        RadioPush.none => l.radioNoneHint,
        RadioPush.light => l.radioLightHint,
        RadioPush.standard => l.radioStandardHint,
        RadioPush.heavy => l.radioHeavyHint,
        RadioPush.blitz => l.radioBlitzHint,
      };

  /// A radio format's name (docs K134).
  /// A per-play payout in dollars (cents in): \$0.0035.
  String perStream(double cents) =>
      '\$${(cents / 100).toStringAsFixed(4)}';

  /// Where record money comes from (docs K145).
  String incomeSource(IncomeSource s) => switch (s) {
        IncomeSource.streamify => MusicPlatform.streamify.displayName,
        IncomeSource.fruitMusic => MusicPlatform.fruitMusic.displayName,
        IncomeSource.viewTube => MusicPlatform.viewTube.displayName,
        IncomeSource.noiseCloud => MusicPlatform.noiseCloud.displayName,
        IncomeSource.downloads => l.incomeDownloads,
        IncomeSource.physical => l.incomePhysical,
        IncomeSource.albumSales => l.incomeAlbums,
      };

  /// An album bundle (docs K144).
  String bundle(AlbumBundle b) => switch (b) {
        AlbumBundle.none => l.bundleNone,
        AlbumBundle.merch => l.bundleMerch,
        AlbumBundle.tickets => l.bundleTickets,
      };

  /// A channel video kind (docs K142) and what it does.
  String videoKind(VideoKind k) => switch (k) {
        VideoKind.lyric => l.videoLyric,
        VideoKind.visualizer => l.videoVisualizer,
        VideoKind.live => l.videoLive,
        VideoKind.acoustic => l.videoAcoustic,
        VideoKind.dance => l.videoDance,
        VideoKind.behindScenes => l.videoBehindScenes,
        VideoKind.vlog => l.videoVlog,
      };
  String videoKindHint(VideoKind k) => switch (k) {
        VideoKind.lyric => l.videoLyricHint,
        VideoKind.visualizer => l.videoVisualizerHint,
        VideoKind.live => l.videoLiveHint,
        VideoKind.acoustic => l.videoAcousticHint,
        VideoKind.dance => l.videoDanceHint,
        VideoKind.behindScenes => l.videoBehindScenesHint,
        VideoKind.vlog => l.videoVlogHint,
      };

  String radioFormat(RadioFormat f) => switch (f) {
        RadioFormat.top40 => l.formatTop40,
        RadioFormat.rhythmic => l.formatRhythmic,
        RadioFormat.urban => l.formatUrban,
        RadioFormat.hotAc => l.formatHotAc,
        RadioFormat.country => l.formatCountry,
        RadioFormat.alternative => l.formatAlternative,
        RadioFormat.latin => l.formatLatin,
      };

  /// An autoplay level's name (docs K128).
  String autoplayLevel(AutoplayLevel a) => switch (a) {
        AutoplayLevel.off => l.autoplayOff,
        AutoplayLevel.light => l.autoplayLight,
        AutoplayLevel.standard => l.autoplayStandard,
        AutoplayLevel.max => l.autoplayMax,
      };

  /// What a level gives and takes.
  String autoplayTerms(AutoplayLevel a) => a.on
      ? l.autoplayTerms((a.lift * 30).round(), ((1 - a.royalty) * 100).round())
      : l.autoplayOffHint;

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

  /// The year in one phrase (docs K123).
  String wrappedStory(WrappedStory s) => switch (s) {
        WrappedStory.newcomer => l.wrappedStoryNewcomer,
        WrappedStory.breakout => l.wrappedStoryBreakout,
        WrappedStory.oneSong => l.wrappedStoryOneSong,
        WrappedStory.catalog => l.wrappedStoryCatalog,
        WrappedStory.quiet => l.wrappedStoryQuiet,
        WrappedStory.steady => l.wrappedStorySteady,
      };

  /// A record's name (docs K111).
  String recordName(RecordKind k) => switch (k) {
        RecordKind.weeksAtNo1Song => l.recordWeeksAtNo1Song,
        RecordKind.weeksAtNo1Album => l.recordWeeksAtNo1Album,
        RecordKind.weeksOnChart => l.recordWeeksOnChart,
        RecordKind.albumDebut => l.recordAlbumDebut,
        RecordKind.streamWeek => l.recordStreamWeek,
        RecordKind.mostNo1s => l.recordMostNo1s,
      };

  String outlet(Outlet o) => switch (o) {
        Outlet.pitchwork => l.outletPitchwork,
        Outlet.rollingPage => l.outletRollingPage,
        Outlet.needle => l.outletNeedle,
        Outlet.hypeBureau => l.outletHypeBureau,
        Outlet.popMatter => l.outletPopMatter,
      };

  /// Rolling Page's stars for a [score] out of 10, in halves (3.5).
  double stars(double score) => score.round().clamp(1, 10) / 2;

  /// A review [score] out of 10 the way [o] prints it (docs K112): a
  /// tenth, stars, out of 10, a letter grade or out of 100.
  String outletScore(Outlet o, double score) => switch (o) {
        Outlet.pitchwork => score.toStringAsFixed(1),
        Outlet.rollingPage => '${stars(score)}/5',
        Outlet.needle => '${score.round()}/10',
        Outlet.hypeBureau => switch (score) {
            >= 9.5 => 'A+',
            >= 9.0 => 'A',
            >= 8.5 => 'A−',
            >= 8.0 => 'B+',
            >= 7.0 => 'B',
            >= 6.5 => 'B−',
            >= 6.0 => 'C+',
            >= 5.0 => 'C',
            >= 4.0 => 'D',
            _ => 'F',
          },
        Outlet.popMatter => '${(score * 10).round()}/100',
      };

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

  String festivalSlot(FestivalSlot s) => switch (s) {
        FestivalSlot.headliner => l.slotHeadliner,
        FestivalSlot.subHeadliner => l.slotSubHeadliner,
        FestivalSlot.mainStage => l.slotMainStage,
        FestivalSlot.smallStage => l.slotSmallStage,
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
        OpportunityKind.memberSolo => l.offerMemberSoloTitle,
        OpportunityKind.memberRift => l.offerMemberRiftTitle,
      };

  String offerBody(OpportunityView o) => switch (o.kind) {
        OpportunityKind.interview =>
          l.offerInterviewBody(Opportunities.interviewEnergy.round()),
        OpportunityKind.feature => l.offerFeatureBody(o.partnerName,
            money(o.feeCents), Opportunities.featureEnergy.round()),
        OpportunityKind.festival => l.offerFestivalBody(
            money(o.feeCents), Opportunities.festivalEnergy.round()),
        OpportunityKind.brandDeal => o.brand == null
            ? l.offerBrandBody(money(o.feeCents))
            : l.offerBrandDealBody(
                o.brand!.name,
                brandCategory(o.brand!.category),
                money(o.feeCents),
                brandFit(o.brandFit),
                o.brandTasks.map(dealTask).join(', ')),
        OpportunityKind.scandal => l.offerScandalBody,
        OpportunityKind.award =>
          l.offerAwardBody(Opportunities.performEnergy.round(), o.nominations),
        OpportunityKind.memberSolo => l.offerMemberSoloBody(
            o.memberName, Opportunities.memberSoloEnergy.round()),
        OpportunityKind.memberRift => l.offerMemberRiftBody(
            o.memberName, Opportunities.memberTalkEnergy.round()),
      };

  String offerChoice(OpportunityKind k, OpportunityChoice c) => switch (c) {
        OpportunityChoice.accept when k == OpportunityKind.memberSolo =>
          l.choiceSupport,
        OpportunityChoice.decline when k == OpportunityKind.memberSolo =>
          l.choiceAskToWait,
        OpportunityChoice.apologize when k == OpportunityKind.memberRift =>
          l.choiceTalkItOut,
        OpportunityChoice.ignore when k == OpportunityKind.memberRift =>
          l.choiceLetItPass,
        OpportunityChoice.leanIn when k == OpportunityKind.memberRift =>
          l.choiceAirItOut,
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
      (OpportunityKind.award, OpportunityChoice.perform) =>
        l.outcomeAwardPerform,
      (OpportunityKind.award, _) => l.outcomeAwardAttend,
      (OpportunityKind.memberSolo, OpportunityChoice.accept) =>
        l.outcomeMemberSolo(fans),
      (OpportunityKind.memberSolo, _) => l.outcomeMemberWaits,
      (OpportunityKind.memberRift, OpportunityChoice.apologize) =>
        l.outcomeRiftTalked,
      (OpportunityKind.memberRift, OpportunityChoice.ignore) =>
        o.blewOver ? l.outcomeRiftPassed : l.outcomeRiftBad(compact(-o.fans)),
      (OpportunityKind.memberRift, _) => l.outcomeRiftAired(compact(-o.fans)),
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
      'buyoutMoney' => l.errorBuyoutMoney,
      'radioLocked' => l.errorRadioLocked,
      'versionOut' => l.errorVersionOut,
      'socialLocked' => l.errorSocialLocked,
      'noStreaming' => l.errorNoStreaming,
      'noEnergy' => l.errorNoEnergy,
      'dealOver' => l.errorDealOver,
      'botsBusy' => l.errorBotsBusy,
      'cannotPitch' => l.errorCannotPitch,
      'postLimit' => l.errorPostLimit,
      'nothingToTease' => l.errorNothingToTease,
      'variantOut' => l.errorEditionOut,
      'deluxeOut' => l.errorDeluxeOut,
      'featureRefused' => l.errorFeatureRefused,
      'featuresFull' => l.errorFeaturesFull,
      'cannotRerecord' => l.errorCannotRerecord,
      'cannotUpload' => l.errorCannotUpload,
      'songRefused' => l.errorSongRefused,
      'cannotBundle' => l.errorCannotBundle,
      'noMarquee' => l.errorNoMarquee,
      'cannotCloud' => l.errorCannotCloud,
      'noAnniversary' => l.errorNoAnniversary,
      'noShowcase' => l.errorNoShowcase,
      'deluxeTracks' => l.errorDeluxeTracks,
      'notSingle' => l.errorNotSingle,
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
      CatchingOn() => l.eventCatchingOn(t),
      MusicShowResult(:final won, :final wins, :final tripleCrown) => !won
          ? l.eventMusicShowSecond(t, line.title2)
          : tripleCrown
              ? l.eventMusicShowCrown(t)
              : wins == 1
                  ? l.eventMusicShowFirstWin(t, line.title2)
                  : l.eventMusicShowWin(t, wins),
      StreamMilestone(:final plays) => plays == Platforms.billionsClub
          ? l.eventBillionsClub(t)
          : l.eventStreamPlays(t, compact(plays)),
      VideoMilestone(:final views) => views >= Platforms.billionViews * 2
          ? l.eventVideoViews(t, compact(views))
          : views >= Platforms.billionViews
              ? l.eventVideoBillion(t)
              : l.eventVideoCertified(t),
      DiscoverPick() => l.eventDiscoverPick(t),
      AdvanceRecouped(:final label) => l.eventAdvanceRecouped(labelName(label)),
      TopArtist(:final rank) =>
        rank == 1 ? l.eventTopArtistNo1 : l.eventTopArtist(rank),
      RecordBroken(:final kind, :final value) => switch (kind) {
          RecordKind.weeksAtNo1Song ||
          RecordKind.weeksAtNo1Album =>
            l.eventRecordWeeksAtNo1(
                t,
                value.round(),
                kind == RecordKind.weeksAtNo1Song
                    ? l.recordKindSong
                    : l.recordKindAlbum),
          RecordKind.streamWeek => l.eventRecordStreamWeek(t, compact(value)),
          _ => l.eventRecordAlbumDebut(t, compact(value)),
        },
      SurpriseDrop() => l.eventSurpriseDrop(t),
      WrappedOut() =>
        l.eventWrapped(e.year, compact(e.plays), t, wrappedStory(e.story)),
      YearEndCharts() => e.hasPlayer
          ? [
              if (e.songs.isNotEmpty) l.eventYearEndSongs(e.year, t),
              if (e.albums.isNotEmpty)
                l.eventYearEndAlbums(e.year, line.title2),
            ].join(' ')
          : l.eventYearEndTop(e.year, t, line.artistName),
      RivalAlbumClash() => e.clash.moved
          ? l.eventRivalMoved(line.artistName, t, week(e.clash.toWeek))
          : l.eventRivalStays(line.artistName, t, week(e.clash.playerWeek)),
      EraClosed() => l.eventEraClosed(eraResult(e.result)),
      BurnoutOver() => l.eventBurnoutOver,
      ReleaseOut() => l.eventReleaseOut(t),
      LabelOffer() => l.eventLabelOffer(labelName(e.label)),
      CriticReview() => e.metascore >= 0
          ? l.eventCriticReviews(
              t, e.metascore, criticScore(e.score), criticBlurb(e.score))
          : l.eventCriticReview(t, criticScore(e.score), criticBlurb(e.score)),
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
      FestivalPlayed() => l.eventFestivalPlayed(
          e.festival,
          festivalSlot(e.slot),
          compact(e.watched),
          money(e.feeCents),
          compact(e.fans)),
      MilestoneReached(:final milestone) =>
        l.eventMilestone(milestoneName(milestone), milestone.skillPoints),
      OpportunityLapsed() => e.outcome.kind == OpportunityKind.scandal ||
              e.outcome.kind == OpportunityKind.memberRift
          ? offerOutcome(e.outcome)
          : l.eventOfferLapsed(offerTitle(e.outcome.kind)),
      ReleaseAnnounced() => l.eventReleaseAnnounced(t, week(e.releaseWeek)),
      PlatformLaunched() => e.chartId == Charts.platformGlobal
          ? l.eventPlatformLaunched(platformName)
          : l.eventPlatformArrived(platformName, l.regionNorthAmerica),
      HolidaySeason() => l.eventHolidaySeason,
      RivalNumberOne() =>
        l.eventRivalNumberOne(line.artistName, t, chart(e.chartId)),
      AwardNominated() => l.eventAwardNominated(e.year,
          e.categories.map((c) => awardCategory(c, line.genre)).join(', ')),
      AwardResults() => [
          e.won.isEmpty
              ? l.eventAwardNoWins(e.year, e.nominations)
              : l.eventAwardWon(e.year,
                  e.won.map((c) => awardCategory(c, line.genre)).join(', ')),
          if (e.fans > 0) l.eventAwardPerformed(compact(e.fans)),
        ].join(' '),
      BotsCaught() => l.eventBotsCaught(t, compact(e.removed)),
      RivalBotsCaught() =>
        l.eventRivalBotsCaught(line.artistName, t, compact(e.removed)),
      PitchDeclined() => l.eventPitchDeclined(t),
      CreatorsFlopped() => l.eventCreatorsFlopped(t),
      HolidayReturn() => l.eventHolidayReturn(t),
      SongLeaked() => l.eventSongLeaked(t, Leaks.answerWeeks),
      SalesMilestone(:final copies) => l.eventSalesMilestone(compact(copies)),
      WrittenSongHit(:final position) => position == 1
          ? l.eventWrittenNo1(t, line.artistName)
          : l.eventWrittenTop10(t, line.artistName, position),
      AllTimeBestSeller(:final rank) => rank == 1
          ? l.eventAllTimeTop
          : l.eventAllTimeTop10(rank),
      SongOfSummer(:final playerRank, :final year) => playerRank == 1
          ? l.eventSummerMine(year, t)
          : playerRank > 0
              ? l.eventSummerRank(year, t, playerRank)
              : l.eventSummerTop(year, t, line.artistName),
      BrandDealBroken() =>
        l.eventBrandDealBroken(e.brand.name, money(e.lostCents)),
      AwardWinners() => l.eventAwardWinners(
          e.year, t, line.artistName, line.title2, line.artistName2),
    };
  }
}
