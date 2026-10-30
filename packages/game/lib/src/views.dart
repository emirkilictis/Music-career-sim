import 'dart:math' as math;

import 'package:simulation_core/simulation_core.dart';

import 'events.dart';
import 'milestones.dart';

/// Read-only screen data built from the world on demand. Views never expose
/// hidden values (a song's true quality stays hidden; the team's estimate is
/// shown instead).

/// Numbers per region (North America, Europe, Other) plus their total.
class RegionalNumbers {
  RegionalNumbers(this.byRegion) : total = byRegion.fold(0.0, (a, x) => a + x);
  final List<double> byRegion;
  final double total;
  double operator [](Region r) => byRegion[r.index];
}

/// Chart record of a song or album on one chart.
class ChartRecord {
  ChartRecord(this.chartId, ChartStats s)
      : lastPos = s.lastPos,
        peak = s.peak,
        weeksOn = s.weeksOn,
        weeksAtNo1 = s.weeksAtNo1,
        debutPos = s.debutPos;
  final int chartId;
  final int lastPos;
  final int peak;
  final int weeksOn;
  final int weeksAtNo1;
  final int debutPos;
}

List<ChartRecord> _records(Charted e) => [
      for (var c = 0; c < Charts.count; c++)
        if (e.statsOrNull(c) case final s?
            when s.weeksOn > 0 && !Charts.all[c].retired)
          ChartRecord(c, s),
    ];

RegionalNumbers _regional(double Function(int r) f) =>
    RegionalNumbers([for (var r = 0; r < regionCount; r++) f(r)]);

class ArtistView {
  ArtistView._(World w, Artist a)
      :
        regionShare = List.unmodifiable(a.regionShare), id = a.id,
        name = a.name,
        kind = a.kind,
        members = List.unmodifiable(a.members),
        genre = a.genre,
        home = a.homeCountry,
        isPlayer = a.tier == ArtistTier.player,
        fame = a.fame,
        popularity = a.popularity,
        coreFans = a.coreFans,
        casualListeners = a.casual,
        devotion = a.devotion,
        hype = a.hype,
        anticipation = a.anticipation,
        moneyCents = a.moneyCents,
        lifetimeStreams = _regional((r) => w.artistLifetimeStreams(a, r)),
        lifetimePure =
            _regional((r) => a.reg[ArtistReg.lifePure + r].toDouble()),
        lifetimeUnits = _regional((r) => w.artistLifetimeUnits(a, r)),
        lifetimeTotalUnits = _regional((r) =>
            w.artistLifetimeUnits(a, r) + _singleUnitsOffAlbums(w, a, r)),
        lifetimeSingleSales = a.tier == ArtistTier.player
            ? w.playerSongIds.fold(
                0.0,
                (t, id) =>
                    t +
                    w.songLifetimeDownloads(w.songs[id]) +
                    w.songs[id].lifetimePhysical)
            : a.lifetimeDownloads,
        lifetimeRadio = a.tier == ArtistTier.player
            ? w.playerSongIds
                .fold(0.0, (t, id) => t + w.songs[id].lifetimeRadio)
            : 0,
        numberOneSingles = List.unmodifiable(a.no1Singles),
        numberOneAlbums = List.unmodifiable(a.no1Albums),
        eraOpen = a.eraOpen,
        eraAlbumId = a.eraOpen ? a.eraAlbumId : -1,
        eraAlbumSinglesLeft = a.eraOpen && a.eraAlbumId >= 0
            ? w.albums[a.eraAlbumId].songIds
                .where((id) =>
                    !w.songs[id].isSingle &&
                    !a.scheduled.any((sr) => sr.songIds.contains(id)))
                .length
            : 0,
        lastEraResult = a.lastEraResult,
        comebackSupport = a.flopSupport,
        creativeEnergy = a.creativeEnergy,
        burnoutWeeksLeft =
            a.burnoutUntilWeek > w.week ? a.burnoutUntilWeek - w.week : 0,
        canWrite = Actions.canWrite(w, a),
        songsWrittenThisWeek =
            a.lastWriteWeek == w.week ? a.songsWrittenThisWeek : 0,
        creativityPenalty = Actions.creativityPenalty(a.creativeEnergy),
        adsLeftThisWeek = Actions.adsLeftThisWeek(w, a),
        job = a.job,
        skillPoints = a.skillPoints,
        label = a.label,
        distributor = a.distributor,
        maxCampaign = Distribution.maxCampaign(a),
        contractAlbumsLeft = a.contractAlbumsLeft,
        unrecoupedCents = a.unrecoupedCents,
        contractAdvanceCents = a.contractAdvanceCents,
        artistShare = a.artistShare,
        campaignCosts = [
          for (final k in Campaign.values) Actions.campaignCostFor(a, k)
        ],
        radioPushCosts = [
          for (final r in RadioPush.values) Actions.radioPushCostFor(a, r)
        ],
        maxRadioPush = Actions.maxRadioPush(a.label),
        moment = w.moment == null ? null : MomentView.of(w, w.moment!),
        opportunity = a.opportunity == null
            ? null
            : OpportunityView.of(w, a.opportunity!),
        tour = a.tour == null ? null : TourView.of(w, a.tour!),
        manager = a.manager,
        skills = {for (final k in SkillKind.values) k: a.skills[k]},
        lastReleaseWeek = a.lastReleaseWeek,
        everCharted = a.tier == ArtistTier.player &&
            (w.playerSongIds.any((id) => _charted(w.songs[id])) ||
                w.albums.any((al) => al.artistId == a.id && _charted(al))),
        vaultCount = a.tier == ArtistTier.player
            ? w.playerSongIds
                .where((id) =>
                    w.songs[id].status == SongStatus.vault &&
                    !a.scheduled.any((sr) => sr.songIds.contains(id)))
                .length
            : 0,
        awardWins = w.awardShows.fold(0, (n, s) => n + s.winsOf(a.id).length),
        awardNominations =
            w.awardShows.fold(0, (n, s) => n + s.racesOf(a.id).length),
        restingThisWeek = a.restWeek == w.week,
        energyNextWeek = Actions.weeklyEnergy(w, a),
        isRetired = a.isRetired;

  factory ArtistView.of(World w, Artist a) => ArtistView._(w, a);

  /// Where the audience is, by [Region] (docs K130).
  final List<double> regionShare;

  final int id;
  final String name;
  final ArtistKind kind;
  final List<String> members;
  final int genre;
  final HomeCountry home;
  final bool isPlayer;
  final double fame;
  final double popularity;
  final double coreFans;
  final double casualListeners;
  final double devotion;
  final double hype;
  final double anticipation;
  final int moneyCents;
  final RegionalNumbers lifetimeStreams;
  final RegionalNumbers lifetimePure;
  final RegionalNumbers lifetimeUnits;

  /// Album units plus the units of songs on no album (docs K99): their
  /// streams (1,500 = 1 unit, once streams count as units) and their
  /// downloads and CD singles (10 = 1 unit).
  final RegionalNumbers lifetimeTotalUnits;

  /// Downloads + CD singles (CD singles counted for the player only).
  final double lifetimeSingleSales;

  /// Radio audience of the player's songs (0 for rivals).
  final double lifetimeRadio;

  /// #1 counts per chart id.
  final List<int> numberOneSingles;
  final List<int> numberOneAlbums;
  final bool eraOpen;

  /// The album of the open era, and how many of its tracks could still be
  /// singles (not singles yet, not scheduled).
  final int eraAlbumId;
  final int eraAlbumSinglesLeft;
  final EraResult? lastEraResult;

  /// Comeback support after a flop (0..1), docs/game-design.md §6.
  final double comebackSupport;
  final double creativeEnergy;
  final int burnoutWeeksLeft;

  /// Not burnt out and not resting: no weekly limit (docs K46).
  final bool canWrite;
  final int songsWrittenThisWeek;

  /// Share of quality the next song loses to low creativity (0 = full
  /// strength, 0.5 at creativity 0).
  final double creativityPenalty;
  final int adsLeftThisWeek;
  final Job job;
  bool get hasJob => job != Job.none;

  /// The player's record label and albums still owed to it (docs K54).
  final Label label;
  final int contractAlbumsLeft;

  /// How an independent's music gets out, and the biggest campaign the
  /// player can run (docs K157).
  final Distributor distributor;
  final Campaign maxCampaign;

  /// The advance of the deal signed and what of it royalties have not
  /// paid back yet (docs K107); the player's split of the money.
  final int unrecoupedCents;
  final int contractAdvanceCents;
  final double artistShare;

  /// What each campaign costs the artist now (by [Campaign.index]): the
  /// price grows with the audience, the label pays part (docs K57).
  final List<int> campaignCosts;

  /// What each radio push costs now (by [RadioPush.index]; docs K84), and
  /// the biggest one the label can arrange.
  final List<int> radioPushCosts;
  final RadioPush maxRadioPush;

  /// An offer waiting for the player's answer (docs K59).
  final OpportunityView? opportunity;

  /// A moment waiting for the player's answers (docs K256).
  final MomentView? moment;

  /// The tour on the road (docs K63).
  final TourView? tour;

  /// The player's manager (docs K68).
  final Manager manager;

  /// Unspent skill points and the current skills (0–100).
  final int skillPoints;
  final Map<SkillKind, double> skills;

  /// Week of the last single or album (-1 = never released anything).
  final int lastReleaseWeek;

  /// The player's unreleased songs.
  final int vaultCount;

  /// Any of the player's releases has been on a chart.
  final bool everCharted;

  /// Golden Record Awards won and nominations, all shows (docs K91).
  final int awardWins;
  final int awardNominations;

  /// The player took this week off.
  final bool restingThisWeek;

  /// Energy change at the end of this week if nothing else changes.
  final double energyNextWeek;
  final bool isRetired;
}

/// The album whose cover a song shows when it has none of its own: its
/// album's, unless it came out as a single before that album (a lead
/// single keeps its own look), else -1.
int coverAlbumOf(World w, Song s) {
  if (s.albumId < 0) return -1;
  if (s.isSingle && s.singleWeek < w.albums[s.albumId].releaseWeek) return -1;
  return s.albumId;
}

class SongView {
  SongView._(World w, Song s)
      : id = s.id,
        title = s.title,
        artistId = s.primaryArtistId,
        artistName = w.artists[s.primaryArtistId].name,
        featuredArtistIds = List.unmodifiable(s.featuredArtistIds),
        genres = s.genres,
        status = s.status,
        isSingle = s.isSingle,
        writtenWeek = s.writtenWeek,
        releasedWeek = s.releasedWeek,
        singleWeek = s.singleWeek,
        albumId = s.albumId,
        coverAlbumId = coverAlbumOf(w, s),
        estimatedGrade = s.estimatedGrade,
        gradeLow = math.max(1, s.estimatedGrade - s.gradeSpread),
        gradeHigh = math.min(100, s.estimatedGrade + s.gradeSpread),
        grade = s.status == SongStatus.vault ? -1 : s.quality.round(),
        campaign = s.campaign,
        radioPush = s.radioPush,
        playlistAdd = s.playlistAdd,
        charts = _records(s),
        weekStreamsUs =
            s.releasedWeek < 0 ? 0 : w.songWeekStreamsIn(s, ChartMarket.us),
        weekStreams =
            s.releasedWeek < 0 ? 0 : w.songWeekStreamsIn(s, ChartMarket.global),
        lifetimeStreams = _regional((r) => w.songLifetimeStreams(s, r)),
        lifetimeDownloads = w.songLifetimeDownloads(s),
        lifetimePhysical = s.lifetimePhysical,
        lifetimeRingtones = s.lifetimeRingtones,
        mood = s.mood < 0 ? null : Mood.values[s.mood],
        moodIn = s.moodIn,
        canMood = w.player != null && MoodPlaylists.can(w, w.player!, s),
        canvas = s.canvasWeek >= 0,
        canvasOpen = SongCanvas.open(w),
        canCanvas = w.player != null && SongCanvas.can(w, w.player!, s),
        lifetimeRadio = s.lifetimeRadio,
        isPlayer = s.primaryArtistId == w.playerArtistId,
        video = s.videoBudget < 0 ? null : VideoBudget.values[s.videoBudget],
        versions = List.unmodifiable(s.versions),
        botStatus = s.botStatus,
        botWeeksLeft = s.botWeeksLeft,
        botRemoved = s.botStatus == BotStatus.caught ? s.botDelivered : 0,
        chartFiltered = w.week < s.chartFilterUntil,
        autoplay = s.autoplay.on,
        autoplayLevel = s.autoplay,
        radioSpins = Radio.spins(s.weekRadio),
        radioStations = Radio.stations(s.weekRadio),
        radioFormat = s.onFormat,
        radioFormatOptions = s.primaryArtistId != w.playerArtistId ||
                !s.isSingle ||
                s.status != SongStatus.active ||
                w.week - s.singleWeek >= Actions.radioUpgradeWeeks
            ? const {}
            : {
                for (final f in RadioFormat.values)
                  f: (
                    RadioFormat.factor(f, s.genre, s.genres),
                    RadioFormat.lifeFactor(f, s.genre)
                  ),
              },
        radioUpgradeCosts = s.primaryArtistId != w.playerArtistId ||
                !Actions.canUpgradeRadio(w, w.player!, s)
            ? const {}
            : {
                for (final r in RadioPush.ladder)
                  if (r.rank > s.radioPush.rank &&
                      r.rank <= Actions.maxRadioPush(w.player!.label).rank)
                    r: Actions.radioUpgradeCost(w.player!, s, r),
              },
        canPullRadio = s.primaryArtistId == w.playerArtistId &&
            Actions.canPullRadio(w, w.player!, s),
        radioEdit = s.radioEditWeek >= 0,
        radioEditCost = s.primaryArtistId == w.playerArtistId &&
                RadioTools.canEdit(w, w.player!, s)
            ? RadioTools.editCostFor(w.player!)
            : null,
        ukRadioPush = RadioTools.ukPush(s),
        ukRadioOptions = s.primaryArtistId == w.playerArtistId
            ? RadioTools.ukOptions(w, w.player!, s)
            : const {},
        holiday = s.holiday,
        dissTarget = s.dissTarget,
        dissTargetName = s.dissTarget >= 0
            ? w.artists[s.dissTarget].name
            : '',
        rerecordOf = s.rerecordOf,
        liveOf = s.liveOf,
        leakedWeek = s.leakedWeek,
        writerName = s.writerId >= 0 ? w.artists[s.writerId].name : '',
        writtenByPlayer = s.writerId >= 0 && s.writerId == w.playerArtistId,
        boughtFrom =
            s.boughtFrom < 0 ? null : w.collaborators[s.boughtFrom].name,
        writerCents = s.writerCents,
        credit = ChartCredit.of(w, s.primaryArtistId, s.featuredArtistIds),
        guestCents = s.guestCents,
        onOwnPlaylist = w.ownPlaylist?.songIds.contains(s.id) ?? false,
        canCurators =
            s.primaryArtistId == w.playerArtistId && Curators.can(w, s),
        curatorWeek = s.curatorWeek,
        curatorSent = s.curatorWeek < 0 ? 0 : s.curatorPack.curators,
        curatorAdds = s.curatorAdds,
        curatorReach = s.curatorReach,
        curatorAnswered = s.curatorWeek >= 0 && w.week > Curators.answerWeek(s),
        curatorStreams = Curators.streams(s, w.week - 1),
        canOwnPlaylist = w.ownPlaylist != null && OwnPlaylists.canAdd(w, s),
        canAnswerLeak = Leaks.canAnswer(s, w.week),
        leakHurts = s.releasedWeek >= 0 && Leaks.hurts(s),
        replacedWeek = s.replacedWeek,
        masterShare = Rerecords.songShare(w.artists[s.primaryArtistId], s),
        masterBuyCents = w.player != null &&
                MasterBuyback.canSong(w, w.player!, s)
            ? MasterBuyback.songPriceCents(w, w.player!, s)
            : null,
        languageVersions = [
          for (final v in LanguageVersion.values)
            if (s.languages & (1 << v.index) != 0) v
        ],
        languageOptions = [
          if (w.player != null)
            for (final v in LanguageVersion.values)
              if (Languages.can(w, w.player!, s, v)) v
        ],
        snippetWeek = s.snippetWeek,
        snippetReaction = s.snippetWeek < 0
            ? null
            : Snippets.reaction(s.snippetScore),
        snippetScore = s.snippetWeek < 0 ? 0 : s.snippetScore.round(),
        canSnippet = w.player != null && Snippets.can(w, w.player!, s),
        cloudWeek = s.cloudWeek,
        cloudOnly = s.cloudOnly,
        cloudPlays = s.cloudOnly ? w.songLifetimeStreams(s) : s.cloudPlays,
        canCloud = w.player != null && Cloud.canUpload(w, w.player!, s),
        marqueeWeek = s.marqueeWeek,
        marqueeCostCents = StreamingTools.canMarquee(w, s)
            ? StreamingTools.marqueeCostCents(w.player!)
            : null,
        showcaseWeek = s.showcaseWeek,
        showcaseCostCents = StreamingTools.canShowcase(w, s)
            ? StreamingTools.showcaseCostCents(w.player!)
            : null,
        creatorWeek = s.creatorWeek,
        creatorTier = s.creatorTier,
        creatorResult = s.creatorResult,
        creatorCosts = s.primaryArtistId != w.playerArtistId ||
                !StreamingTools.canRunCreators(w, s)
            ? const {}
            : {
                for (final c in CreatorCampaign.values)
                  c: StreamingTools.creatorCostCents(w.player!, c),
              },
        canPitch = StreamingTools.canPitch(w, s),
        pitchWeek = s.pitchWeek,
        pitchAnswerWeek = StreamingTools.pitchAnswerWeek(s),
        pitchLanded = StreamingTools.pitchAnswerWeek(s) >= 0 &&
            s.playlistWeek == StreamingTools.pitchAnswerWeek(s),
        streamingOpen = StreamingTools.streamingOpen(w),
        autoplayOpen = StreamingTools.autoplayOpen(w),
        skipRate = StreamingTools.skipRate(s),
        streamSources = _sources(s),
        preSaves = s.preSaves,
        autoplayLift = StreamingTools.autoplayLift(
            w.config,
            s,
            s.releasedWeek < 0
                ? 0
                : w.week - (s.isSingle ? s.singleWeek : s.releasedWeek)),
        inDiscover = s.releasedWeek >= 0 &&
            StreamingTools.discoverLift(w, s, w.week - 1) > 0.05,
        inReleaseRadar = s.releasedWeek >= 0 &&
            StreamingTools.releaseRadarLift(GameTime.yearOf(w.week - 1),
                    w.week - 1 - (s.isSingle ? s.singleWeek : s.releasedWeek)) >
                0,
        catchingOn = s.releasedWeek >= 0 &&
            WordOfMouth.lift(w, s,
                    w.week - (s.isSingle ? s.singleWeek : s.releasedWeek)) >=
                0.1,
        variants = List.unmodifiable(s.variants),
        campaignCostCents = s.campaignCostCents,
        campaignReturnCents = s.campaignReturnCents.round(),
        revenueCents = s.revenueCents.round(),
        costsCents = _songCosts(s),
        featuredNames = [
          for (final id in s.featuredArtistIds) w.artists[id].name
        ],
        usSingleUnits = _usSingleUnits(w, s),
        scheduledSingleWeek = _scheduledWeek(w, s, album: false),
        scheduledAlbumWeek = _scheduledWeek(w, s, album: true);

  factory SongView.of(World w, Song s) => SongView._(w, s);

  static int _scheduledWeek(World w, Song s, {required bool album}) {
    for (final sr in w.artists[s.primaryArtistId].scheduled) {
      if (sr.isAlbum == album && sr.songIds.contains(s.id)) {
        return sr.releaseWeek;
      }
    }
    return -1;
  }

  final bool isPlayer;

  /// The song's music video budget, if it has one (docs K52).
  final VideoBudget? video;

  /// Versions out and the single's physical editions, with their weeks
  /// (docs K92, F26).
  final List<(SongVersion, int)> versions;

  /// Bought streams (docs K95): status, weeks still coming, and what the
  /// platform removed if caught; filtered from the charts right now.
  final BotStatus botStatus;
  final int botWeeksLeft;
  final double botRemoved;
  final bool chartFiltered;

  /// In the autoplay programme (docs K96), and how far (K128).
  final bool autoplay;
  final AutoplayLevel autoplayLevel;

  /// A holiday song (docs K136).
  final bool holiday;

  /// A diss track's target (docs K229): a rival's id ([dissTargetName]),
  /// [Beefs.haters], or -1.
  final int dissTarget;
  final String dissTargetName;
  bool get isDiss => dissTarget != -1;

  /// The song this one re-records (-1: an original), and the week its
  /// own re-recording came out (-1: none; docs K139).
  final int rerecordOf;
  final int replacedWeek;

  /// The studio song this is a live recording of (-1: none; docs K146).
  final int liveOf;

  /// Leaks (docs K140): the week it leaked (-1: never), whether it can
  /// still be put out in answer, and whether the leak cost it (out too
  /// late).
  final int leakedWeek;

  /// Writing for others (docs K143): the writer when it is not the
  /// artist ('' otherwise), whether that is the player, and the player's
  /// royalties from it.
  final String writerName;
  final bool writtenByPlayer;

  /// The songwriter it was bought from on the song market (docs K205).
  final String? boughtFrom;
  final double writerCents;

  /// The player on it under another name (docs K158): a member's solo
  /// song or a verse on a rival's, and what the verse has paid.
  final ChartCredit credit;
  final double guestCents;

  /// On the player's own playlist, and whether it can go on it (K159).
  final bool onOwnPlaylist;
  final bool canOwnPlaylist;

  /// Independent curators (docs K160): whether it can be sent, when it
  /// was (-1: not), to how many, how many added it with how many
  /// followers, whether they answered, and last week's plays from them.
  final bool canCurators;
  final int curatorWeek;
  final int curatorSent;
  final int curatorAdds;
  final double curatorReach;
  final bool curatorAnswered;
  final double curatorStreams;
  final bool canAnswerLeak;
  final bool leakHurts;

  /// The artist's share of what it earns: the deal it came out under
  /// (docs K139).
  final double masterShare;

  /// What buying back this loose single's master costs (null: nothing to
  /// buy; docs K162).
  final int? masterBuyCents;

  /// A creator campaign on the short-video app (docs K131): when it
  /// started (-1: none), its size, how it went; and what each size costs
  /// while one can still be run (empty otherwise).
  final int creatorWeek;
  final CreatorCampaign creatorTier;
  final CreatorResult creatorResult;
  final Map<CreatorCampaign, int> creatorCosts;

  /// Its versions in other languages, and the ones it can still get
  /// (docs K155).
  final List<LanguageVersion> languageVersions;
  final List<LanguageVersion> languageOptions;

  /// A snippet test (docs K152): when (-1: never), the reaction and its
  /// score (0–100), and whether one can be made now.
  final int snippetWeek;
  final SnippetReaction? snippetReaction;
  final int snippetScore;
  final bool canSnippet;

  /// A free upload to the audio-sharing site (docs K148): when, whether
  /// it is still only there, its plays there, and whether it can go up.
  final int cloudWeek;
  final bool cloudOnly;
  final double cloudPlays;
  final bool canCloud;

  /// The streaming app's Marquee and Showcase (docs K147): when the song
  /// got them (-1: never) and what they cost now (null: not possible).
  final int marqueeWeek;
  final int? marqueeCostCents;
  final int showcaseWeek;
  final int? showcaseCostCents;

  /// The radio format it is worked to (docs K134), and while it can still
  /// change, each format's play and run against the calibrated ones.
  final RadioFormat radioFormat;
  final Map<RadioFormat, (double play, double run)> radioFormatOptions;

  /// Last week on the radio (docs K128): plays and stations playing it.
  final double radioSpins;
  final int radioStations;

  /// Radio pushes it can still be raised to, with what each costs now
  /// (empty once stations have made up their minds; K128).
  final Map<RadioPush, int> radioUpgradeCosts;

  /// Pitch to the playlist editors (docs K97).
  final bool canPitch;
  final int pitchWeek;

  /// Week the editors answer (-1 while the song is unreleased).
  final int pitchAnswerWeek;
  final bool pitchLanded;

  /// The streaming platform and its autoplay exist this year.
  final bool streamingOpen;
  final bool autoplayOpen;

  /// More people find it every week by word of mouth (docs K108).
  final bool catchingOn;

  /// The streaming algorithm (docs K119): how many skip it, what autoplay
  /// would add now, and whether the discovery mixes or the new-releases
  /// radar carry it this week.
  final double skipRate;
  final double autoplayLift;

  /// Pre-saves it came out with (docs K121).
  final double preSaves;

  /// Last week's listening by [StreamSource], as shares that add up to 1
  /// (empty when not known: a rival's song, or right after loading;
  /// docs K120).
  final List<double> streamSources;

  static List<double> _sources(Song s) {
    final x = s.streamSources;
    if (x == null) return const [];
    final total = x.fold(0.0, (t, v) => t + v);
    if (total <= 0) return const [];
    return List.unmodifiable([for (final v in x) v / total]);
  }

  final bool inDiscover;
  final bool inReleaseRadar;
  final List<(SingleFormat, int)> variants;

  /// The song's campaign, what the player paid and the income it brought
  /// in (estimated; docs K57). Album tracks share the album's campaign
  /// (see [AlbumView]).
  final int campaignCostCents;
  final int campaignReturnCents;

  /// The player's income from the song and what it cost them: writing,
  /// its own campaign, its video (docs K60).
  final int revenueCents;
  final int costsCents;

  /// Featured artists' names, in credit order.
  final List<String> featuredNames;

  /// Single units in the US, for certifications (docs K60).
  final double usSingleUnits;

  /// Week a scheduled single / album with this song comes out, or -1
  /// (docs K45).
  final int scheduledSingleWeek;
  final int scheduledAlbumWeek;

  final int id;
  final String title;
  final int artistId;
  final String artistName;
  final List<int> featuredArtistIds;
  final List<int> genres;
  final SongStatus status;
  final bool isSingle;
  final int writtenWeek;
  final int releasedWeek;
  final int singleWeek;
  final int albumId;

  /// Album whose cover this song shows (see [coverAlbumOf]).
  final int coverAlbumId;

  /// The team's estimate of the song's quality (1–100), not the true value.
  final int estimatedGrade;

  /// The range the team is fairly sure of (docs F36): what the player sees
  /// before the song comes out.
  final int gradeLow;
  final int gradeHigh;

  /// The song's real grade once it is out (-1 while in the vault).
  final int grade;
  final Campaign campaign;

  /// The radio push bought for it as a single (docs K84).
  final RadioPush radioPush;

  /// It can be taken off the radio for another single (docs K253).
  final bool canPullRadio;

  /// A radio edit was cut; what one costs now (null: not possible; docs
  /// K254).
  final bool radioEdit;
  final int? radioEditCost;

  /// The push the UK stations get, and the ones it can be raised to there
  /// with their price (docs K254).
  final RadioPush ukRadioPush;
  final Map<RadioPush, int> ukRadioOptions;
  final PlaylistAdd playlistAdd;
  final List<ChartRecord> charts;
  final double weekStreamsUs;
  final double weekStreams;
  final RegionalNumbers lifetimeStreams;
  final double lifetimeDownloads;

  /// CD singles sold.
  final double lifetimePhysical;

  /// Ringtones sold (docs K183).
  final double lifetimeRingtones;

  /// The mood playlist it was pitched to (null: none) and whether it got
  /// in, and whether it can be pitched now (docs K186).
  final Mood? mood;
  final bool moodIn;
  final bool canMood;

  /// Has a Canvas, the app has them, and it can get one now (docs K190).
  final bool canvas;
  final bool canvasOpen;
  final bool canCanvas;

  /// Radio audience (listener impressions).
  final double lifetimeRadio;

  /// Single sales: downloads + CD singles.
  double get singleSales => lifetimeDownloads + lifetimePhysical;

  /// Single units as certifications count them: sales + streams / 150.
  double get singleUnits =>
      singleSales + lifetimeStreams.total / streamsPerSingleUnit;

  static const streamsPerSingleUnit = 150;

  bool get inVault => status == SongStatus.vault;
}

class AlbumView {
  AlbumView._(World w, Album al)
      : id = al.id,
        title = al.title,
        artistId = al.artistId,
        artistName = w.artists[al.artistId].name,
        type = al.type,
        releaseWeek = al.releaseWeek,
        trackIds = List.unmodifiable(al.songIds),
        variantWeeks = List.unmodifiable(al.variantWeeks),
        variantFormats = [
          for (var k = 0; k < al.variantWeeks.length; k++)
            k < al.variantFormats.length && al.variantFormats[k] >= 0
                ? EditionFormat.values[al.variantFormats[k]]
                : null,
        ],
        campaign = al.campaign,
        charts = _records(al),
        firstWeekUsUnits = w.albumFirstWeekIn(al, ChartMarket.us),
        firstWeekUsPure = w.albumFirstWeekIn(al, ChartMarket.us, pure: true),
        firstWeekUkUnits = w.albumFirstWeekIn(al, ChartMarket.uk),
        firstWeekUnits = al.firstWeekUnits,
        firstWeekPure = al.firstWeekPure,
        preOrders = al.preOrders,
        exclusiveUntil = al.exclusiveUntil,
        exclusiveFeeCents = al.exclusiveFeeCents,
        windowUntil = al.windowUntil,
        bundle = al.bundle,
        isLive = al.isLive,
        hitTrackIds = List.unmodifiable(al.hitIds),
        rollout = RolloutStatus(al.rolloutApplicable, al.rolloutDone),
        priceCutWeek = al.priceCutWeek,
        priceCut = al.priceCut,
        priceCutBlocks = {
          if (w.player != null && al.artistId == w.playerArtistId)
            for (final c in PriceCut.values)
              c: PriceCuts.block(w, w.player!, al, c),
        },
        digitalShare = PriceCuts.digitalShare(GameTime.yearOf(w.week)),
        partnerId = al.partnerId,
        visual = al.visual,
        visualCostCents = w.player != null && VisualAlbums.can(w, w.player!, al)
            ? VisualAlbums.costCents(w, al)
            : null,
        partnerName = al.partnerId >= 0 ? w.artists[al.partnerId].name : '',
        anniversaryDue = w.player != null &&
                Anniversaries.can(w, w.player!, al)
            ? Anniversaries.years[Anniversaries.due(w, al)]
            : 0,
        anniversariesMarked = [
          for (var i = 0; i < Anniversaries.years.length; i++)
            if (al.anniversaries & (1 << i) != 0) Anniversaries.years[i]
        ],
        marqueeCostCents = StreamingTools.canMarqueeAlbum(w, al)
            ? StreamingTools.albumMarqueeCostCents(w.player!)
            : null,
        onMarquee = al.songIds.isNotEmpty &&
            w.songs[al.songIds.first].marqueeWeek >= 0,
        bundleUnits = al.bundleUnits,
        masterShare = Rerecords.albumShare(w.artists[al.artistId], al),
        masterBuyCents = w.player != null &&
                MasterBuyback.canAlbum(w, w.player!, al)
            ? MasterBuyback.albumPriceCents(w, w.player!, al)
            : null,
        masterOwnerYearCents = w.player != null &&
                MasterBuyback.canAlbum(w, w.player!, al)
            ? MasterBuyback.albumYearCents(w, w.player!, al)
            : 0,
        isRerecord = Rerecords.isRerecord(w, al),
        rerecordBlock = al.artistId == w.playerArtistId
            ? Rerecords.block(w, w.artists[al.artistId], al)
            : RerecordBlock.notYours,
        rerecordCostCents = Rerecords.costCents(al),
        replacedWeek = al.songIds.isEmpty
            ? -1
            : w.songs[al.songIds.first].replacedWeek,
        originalAlbumId = _originalAlbum(w, al),
        originalTitle = _originalAlbum(w, al) < 0
            ? ''
            : w.albums[_originalAlbum(w, al)].title,
        rerecordFrom = al.releaseWeek + Rerecords.waitWeeks,
        rerecordEnergy = Rerecords.energyCost(al),
        weekUnits = al.status == AlbumStatus.active ? al.weekUnits : 0,
        weekPure = al.status == AlbumStatus.active ? al.weekPure : 0,
        weekUsUnits = al.status == AlbumStatus.active
            ? albumWeekUnitsIn(w, al, ChartMarket.us)
            : 0,
        isPlayer = al.artistId == w.playerArtistId,
        usHits = ChartHistoryView.albumHits(w, al, Charts.usSongs),
        isDeluxe = Actions.hasDeluxe(al),
        canDeluxe = al.artistId == w.playerArtistId &&
            al.type != AlbumType.mixtape &&
            al.hitIds.isEmpty &&
            w.week > al.releaseWeek &&
            !Actions.hasDeluxe(al),
        versions = [
          for (final v in al.versions)
            AlbumVersionView(
              edition: v.edition,
              week: v.week,
              name: v.name,
              trackIds: List.unmodifiable(v.songIds),
              anniversaryYears:
                  v.anniversary >= 0 ? Anniversaries.years[v.anniversary] : 0,
              format: v.edition < al.variantFormats.length &&
                      al.variantFormats[v.edition] >= 0
                  ? EditionFormat.values[al.variantFormats[v.edition]]
                  : null,
            )
        ],
        versionBlock = w.player == null
            ? VersionBlock.notYours
            : AlbumVersions.block(w, w.player!, al),
        versionsRecent = AlbumVersions.recent(w, al),
        planned = al.planned,
        anniversaryIndexDue = Anniversaries.due(w, al),
        scheduleId = al.scheduleId,
        criticScore = al.criticScore,
        reviews = Critics.reviews(w, al),
        metascore = Critics.metascore(w, al),
        preSingleUnits = al.preSingleUnits,
        campaignCostCents = al.campaignCostCents,
        campaignReturnCents = al.campaignReturnCents.round(),
        revenueCents = (al.revenueCents +
                al.songIds.fold(0.0, (x, id) => x + w.songs[id].revenueCents))
            .round(),
        costsCents = al.campaignCostCents +
            (al.artistId == w.playerArtistId
                ? Actions.editionsCostCents(
                    al.variantWeeks.length, al.variantFormats)
                : 0) +
            al.songIds.fold(0, (x, id) => x + _songCosts(w.songs[id])),
        usLifetimeUnits =
            CountryShares.usOfNorthAmerica(w.artists[al.artistId].homeCountry) *
                w.albumLifetimeUnits(al, Region.northAmerica.index),
        trackStreams = al.songIds
            .fold(0.0, (sum, id) => sum + w.songLifetimeStreams(w.songs[id])),
        lifetimePure =
            _regional((r) => al.reg[AlbumReg.lifePure + r].toDouble()),
        lifetimeUnits = _regional((r) => w.albumLifetimeUnits(al, r));

  factory AlbumView.of(World w, Album al) => AlbumView._(w, al);

  static int _originalAlbum(World w, Album al) {
    for (final id in al.songIds) {
      final of = w.songs[id].rerecordOf;
      if (of >= 0) return w.songs[of].albumId;
    }
    return -1;
  }

  final int id;
  final String title;
  final int artistId;
  final String artistName;
  final AlbumType type;
  final int releaseWeek;
  final List<int> trackIds;
  final List<int> variantWeeks;

  /// Format of each edition (null = standard / classic), parallel to
  /// [variantWeeks].
  final List<EditionFormat?> variantFormats;
  final Campaign campaign;
  final List<ChartRecord> charts;
  final double firstWeekUsUnits;
  final double firstWeekUsPure;
  final double firstWeekUkUnits;
  final double firstWeekUnits;
  final double firstWeekPure;

  /// Copies ordered ahead that shipped in the first week (docs K126).
  final double preOrders;

  /// A streaming exclusive until this week (-1: none) and its fee (K135).
  final int exclusiveUntil;
  final int exclusiveFeeCents;

  /// Off the streaming services until this week (-1: never held; K174).
  final int windowUntil;

  /// What it came bundled with and the copies that added (docs K144).
  final AlbumBundle bundle;
  final double bundleUnits;

  /// A live album (docs K146).
  final bool isLive;

  /// A greatest hits album's released songs ([trackIds] are its new
  /// ones; docs K161).
  /// How it was rolled out (no steps counted: none scored; docs K165).
  final RolloutStatus rollout;
  final List<int> hitTrackIds;
  bool get isCompilation => hitTrackIds.isNotEmpty;

  /// Download price cuts (docs K163): the last one (-1: never), what
  /// stops each now (empty: not the player's; null value: possible) and
  /// the share of copies sold as downloads this year.
  final int priceCutWeek;
  final PriceCut priceCut;
  final Map<PriceCut, PriceCutBlock?> priceCutBlocks;
  final double digitalShare;

  /// A visual album, or what making it one costs now (null: not
  /// possible; docs K154).
  final bool visual;
  final int? visualCostCents;

  /// A joint album's partner (-1 and '': none; docs K150).
  final int partnerId;
  final String partnerName;

  /// Anniversary reissues (docs K149): the one it can have now (0: none)
  /// and the ones it had.
  final int anniversaryDue;
  final List<int> anniversariesMarked;

  /// The Marquee for the whole album (docs K147): its cost now (null:
  /// not possible) and whether it ran.
  final int? marqueeCostCents;
  final bool onMarquee;

  /// Re-recordings (docs K139): the artist's share of its money (the
  /// deal it came out under), whether it re-records [originalAlbumId],
  /// what stops the player re-recording it (null: nothing) and what it
  /// costs, and the week its re-recording came out (-1: none).
  final double masterShare;

  /// What buying back its masters costs (null: nothing to buy) and what
  /// their owner gets from it in a year now (docs K162).
  final int? masterBuyCents;
  final double masterOwnerYearCents;
  final bool isRerecord;
  final RerecordBlock? rerecordBlock;
  final int rerecordCostCents;
  final int replacedWeek;
  final int originalAlbumId;
  final String originalTitle;

  /// The first week it may be re-recorded, and the creativity it takes.
  final int rerecordFrom;
  final double rerecordEnergy;
  bool get canRerecord => rerecordBlock == null;

  /// Last played week (0 once the album is in the catalog).
  final double weekUnits;
  final double weekPure;
  final double weekUsUnits;
  final bool isPlayer;

  /// Re-released as a deluxe edition with bonus tracks, or could be
  /// (docs K115).
  final bool isDeluxe;
  final bool canDeluxe;

  /// Its songs on the US songs chart (docs K232): (charted, top 10s,
  /// #1s).
  final (int, int, int) usHits;

  /// Versions put out after it (docs K225), what stops a new one now
  /// (null: nothing) and how many came out in the last
  /// [AlbumVersions.fatigueWeeks] (two or more: fans call the next one a
  /// cash grab).
  final List<AlbumVersionView> versions;
  final VersionBlock? versionBlock;
  final int versionsRecent;

  /// A version set for a later week (docs K255), or null.
  final PlannedVersion? planned;
  bool get canVersion => versionBlock == null;

  /// The [Anniversaries.years] index it is in the year of (-1: none).
  final int anniversaryIndexDue;

  /// The version that made edition [k], or null.
  AlbumVersionView? versionOfEdition(int k) =>
      versions.where((v) => v.edition == k).firstOrNull;

  /// The version a track came out on as a bonus track, or null.
  AlbumVersionView? versionOfTrack(int songId) =>
      versions.where((v) => v.trackIds.contains(songId)).firstOrNull;

  /// The schedule it came out of, or -1.
  final int scheduleId;

  /// Pitchwork's review (1.0–10.0), or -1 for albums from before reviews.
  final double criticScore;

  /// Every outlet's score out of 10 and their average out of 100
  /// (docs K112; -1 when not reviewed).
  final Map<Outlet, double> reviews;
  final int metascore;

  /// Lifetime units from singles out before the album (part of
  /// [lifetimeUnits], never of a week's sales; docs K56).
  final double preSingleUnits;

  /// What the player paid for the album campaign and the income it brought
  /// in through the album's own tracks and sales (estimated; docs K57).
  final int campaignCostCents;
  final int campaignReturnCents;

  /// The player's income from the album and its tracks, and everything it
  /// cost them: songs, campaigns, videos, editions (docs K60).
  final int revenueCents;
  final int costsCents;
  int get profitCents => revenueCents - costsCents;

  /// Album units in the US, for certifications (docs K60).
  final double usLifetimeUnits;

  /// All streams of the album's tracks (singles included).
  final double trackStreams;
  final RegionalNumbers lifetimePure;
  final RegionalNumbers lifetimeUnits;
}

/// One line of a published chart.
class ChartRow {
  ChartRow({
    required this.albumId,
    required this.weekValue,
    this.points = 0,
    this.streams = 0,
    this.sales = 0,
    this.radio = 0,
    this.pure = 0,
    this.sea = 0,
    this.tea = 0,
    required this.position,
    required this.lastPos,
    required this.peak,
    required this.weeksOn,
    required this.entityId,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.isPlayer,
    this.featuring = '',
    this.credit = ChartCredit.none,
  });
  final int position;

  /// Album the entry belongs to (for its cover); -1 for a loose single.
  final int albumId;

  /// This week's streams (song charts) or units (album charts) in the
  /// chart's market.
  final double weekValue;

  /// The week in the chart's market, opened under the row (docs K89):
  /// chart points; for a song its streams, sales (downloads and CD
  /// singles) and radio audience; for an album its pure sales and the
  /// units from streams (SEA) and from track sales (TEA).
  final double points, streams, sales, radio, pure, sea, tea;

  /// 0 = new or re-entry this week.
  final int lastPos;
  final int peak;
  final int weeksOn;
  final int entityId;
  final String title;
  final int artistId;
  final String artistName;
  final bool isPlayer;

  /// The song's featured artists' names, joined ('' for none).
  final String featuring;

  /// How the player is on it when it is not under their name (K158).
  final ChartCredit credit;

  /// Under the player's name, by one of their members, or with their verse.
  bool get isOurs => isPlayer || credit != ChartCredit.none;
  bool get isNew => lastPos == 0 && weeksOn == 1;
  bool get isReentry => lastPos == 0 && weeksOn > 1;
}

/// How the player is on a record that is not under their name (K158).
enum ChartCredit {
  none,

  /// By one of the player's group members, under their own name.
  member,

  /// The player is featured on it.
  guest,

  /// By an artist on the player's label (docs K169).
  imprint;

  static ChartCredit of(World w, int artistId, List<int> featured) {
    final me = w.playerArtistId;
    if (me < 0 || artistId == me) return none;
    if (w.artists[artistId].managedBy == me) return member;
    if (featured.contains(me)) return guest;
    final label = w.imprint;
    if (label != null && label.roster.any((s) => s.artistId == artistId)) {
      return imprint;
    }
    return none;
  }
}

class ChartView {
  ChartView._(this.def, this.week, this.rows, [this.adds = const []]);

  /// A radio chart's most added songs this week (docs K254): the stations
  /// that took each one on since last week, the most first.
  final List<RadioAdd> adds;

  /// The latest published chart (the week just simulated).
  factory ChartView.latest(World w, int chartId) {
    final def = Charts.all[chartId];
    final kind =
        def.kind == ChartKind.songs ? EntityKind.song : EntityKind.album;
    final rows = [
      for (final e in w.charts[chartId])
        _row(w, def.market, kind, e.position, e.lastPos, e.peak, e.weeksOn,
            e.entityId, e.points),
    ];
    final adds = <RadioAdd>[];
    if (def.market == ChartMarket.usRadio ||
        def.market == ChartMarket.ukRadio) {
      final cap = def.market == ChartMarket.ukRadio
          ? Radio.ukReportingStations
          : Radio.reportingStations;
      int stations(double audience) => Radio.stations(audience, cap: cap);
      for (final r in rows) {
        final s = w.songs[r.entityId];
        if (!s.isSingle || s.status != SongStatus.active) continue;
        // Last week's audience by the song's radio curve.
        final age = w.week - 1 - s.singleWeek;
        final now = Simulator.radioLife(s, age);
        final before = age <= 0 || now <= 0
            ? 0.0
            : r.points * Simulator.radioLife(s, age - 1) / now;
        final added = stations(r.points) - stations(before);
        if (added > 0) {
          adds.add(RadioAdd(
              songId: s.id,
              title: s.title,
              artistId: s.primaryArtistId,
              artistName: w.artists[s.primaryArtistId].name,
              stations: stations(r.points),
              added: added));
        }
      }
      adds.sort((a, b) {
        final d = b.added.compareTo(a.added);
        return d != 0 ? d : a.songId.compareTo(b.songId);
      });
    }
    return ChartView._(def, w.week - 1, rows, adds.take(10).toList());
  }

  static ChartRow _row(World w, ChartMarket market, EntityKind kind,
      int position, int lastPos, int peak, int weeksOn, int id, double points) {
    final title =
        kind == EntityKind.song ? w.songs[id].title : w.albums[id].title;
    final artistId = kind == EntityKind.song
        ? w.songs[id].primaryArtistId
        : w.albums[id].artistId;
    final artist = w.artists[artistId];
    // A by-region number as the chart's market sees it.
    double inMarket(double Function(int r) byRegion) => switch (market) {
          ChartMarket.us ||
          ChartMarket.usRadio ||
          ChartMarket.usStreaming ||
          ChartMarket.usDigital ||
          ChartMarket.usAlbumSales ||
          ChartMarket.usStreamingAlbums ||
          ChartMarket.usRingtones =>
            CountryShares.usOfNorthAmerica(artist.homeCountry) *
                byRegion(Region.northAmerica.index),
          ChartMarket.uk ||
          ChartMarket.ukRadio =>
            CountryShares.ukOfEurope(artist.homeCountry) *
                byRegion(Region.europe.index),
          _ => byRegion(0) + byRegion(1) + byRegion(2),
        };
    double streams = 0, sales = 0, radio = 0, pure = 0, sea = 0, tea = 0;
    if (kind == EntityKind.song) {
      final s = w.songs[id];
      final wr = s.weekRegion;
      streams = w.songWeekStreamsIn(s, market);
      sales = inMarket((r) =>
          (wr == null ? 0 : wr[regionCount + r]) +
          s.weekPhysical * artist.regionShare[r]);
      radio = inMarket((r) => s.weekRadio * artist.regionShare[r]);
    } else {
      final al = w.albums[id];
      final wr = al.weekRegion;
      pure = inMarket((r) => wr[r]);
      final units = inMarket((r) => wr[regionCount + r]);
      // SEA and TEA are kept worldwide; the market gets its share.
      final share = al.weekUnits > 0 ? units / al.weekUnits : 0.0;
      sea = al.weekSea * share;
      tea = al.weekTea * share;
    }
    return ChartRow(
      points: points,
      streams: streams,
      sales: sales,
      radio: radio,
      pure: pure,
      sea: sea,
      tea: tea,
      albumId: kind == EntityKind.song ? coverAlbumOf(w, w.songs[id]) : id,
      // The ringtone chart ranks ringtones sold (docs K183).
      weekValue: market == ChartMarket.usRingtones
          ? points
          : kind == EntityKind.song
          ? w.songWeekStreamsIn(w.songs[id], market)
          // What the album chart ranked: pure sales before 2015, units
          // after (docs K49).
          : points,
      position: position,
      lastPos: lastPos,
      peak: peak,
      weeksOn: weeksOn,
      entityId: id,
      title: title,
      artistId: artistId,
      artistName: w.artists[artistId].name,
      isPlayer: artistId == w.playerArtistId,
      featuring: kind == EntityKind.song
          ? [for (final f in w.songs[id].featuredArtistIds) w.artists[f].name]
              .join(', ')
          : '',
      credit: ChartCredit.of(w, artistId,
          kind == EntityKind.song ? w.songs[id].featuredArtistIds : const []),
    );
  }

  final ChartDef def;
  final int week;
  final List<ChartRow> rows;
}

/// Year-end charts (docs K110), Billboard style: everything a release
/// sold and streamed over the year (its weekly chart points) counts; the
/// tracking year runs from December to November and the charts come out
/// in early December.
abstract final class YearEnd {
  /// Week of the year the charts come out (early December).
  static const publishWeekOfYear = 48;

  /// Entries in a year-end chart.
  static const size = 100;

  /// First and last chart week counted for [year].
  static (int, int) tracking(int year) => (
        GameTime.firstWeekOf(year - 1) + publishWeekOfYear - 1,
        GameTime.firstWeekOf(year) + publishWeekOfYear - 2,
      );

  /// Whether [year]'s charts are out in [week].
  static bool publishedBy(int year, int week) =>
      week >= GameTime.firstWeekOf(year) + publishWeekOfYear - 1;

  /// The songs of the summer (docs K137): a pseudo chart id for the US
  /// songs chart from late May to early September, out in mid-September.
  static const summer = -100;

  /// The critics' albums of the year (docs K187): a pseudo chart id for
  /// the year's reviewed albums ranked by their Metascore, out with the
  /// year-end charts.
  static const critics = -101;
  static const criticsSize = 50;
  static const summerFromWeekOfYear = 22, summerToWeekOfYear = 36;

  static (int, int) summerTracking(int year) => (
        GameTime.firstWeekOf(year) + summerFromWeekOfYear - 1,
        GameTime.firstWeekOf(year) + summerToWeekOfYear - 1,
      );

  /// Whether [year]'s summer chart is out in [week].
  static bool summerPublishedBy(int year, int week) =>
      week >= GameTime.firstWeekOf(year) + summerToWeekOfYear;

  /// Year-end charts there are (song and album charts of the US and the
  /// world).
  static const charts = [
    Charts.usSongs,
    Charts.usAlbums,
    Charts.globalSongs,
    Charts.globalAlbums,
  ];
}

/// One entry of a year-end chart (docs K110).
class YearEndRow {
  YearEndRow.of(World w, EntityKind kind,
      {required this.rank,
      required this.entityId,
      required this.points,
      required this.peak,
      required this.weeksOn,
      this.sales = 0,
      this.streams = 0})
      : title = kind == EntityKind.song
            ? w.songs[entityId].title
            : w.albums[entityId].title,
        artistId = kind == EntityKind.song
            ? w.songs[entityId].primaryArtistId
            : w.albums[entityId].artistId,
        albumId = kind == EntityKind.song
            ? coverAlbumOf(w, w.songs[entityId])
            : entityId,
        artistName = w
            .artists[kind == EntityKind.song
                ? w.songs[entityId].primaryArtistId
                : w.albums[entityId].artistId]
            .name,
        isPlayer = (kind == EntityKind.song
                ? w.songs[entityId].primaryArtistId
                : w.albums[entityId].artistId) ==
            w.playerArtistId;

  final int rank;
  final int entityId;

  /// Album for the cover (-1: a loose single).
  final int albumId;
  final String title;
  final int artistId;
  final String artistName;
  final bool isPlayer;

  /// Chart points over the year, best position and weeks on the chart.
  final int points;
  final int peak;
  final int weeksOn;

  /// A song's track sales and streams in the chart's territory over its
  /// weeks on the chart (docs K266; 0 for years played before).
  final double sales, streams;
}

/// A rival the player could ask to feature on a song (docs K117).
class FeatureCandidateView {
  FeatureCandidateView.of(World w, Artist rival, Artist p, [Song? song])
      : artistId = rival.id,
        name = rival.name,
        genre = rival.genre,
        fame = rival.fame,
        feeCents = Imprints.isSigned(w, rival.id)
            ? 0
            : song == null
                ? Features.feeCents(rival)
                : Features.feeFor(rival, song),
        labelMate = Imprints.isSigned(w, rival.id),
        willing = Features.willing(rival, p, w),
        favoured = OwnPlaylists.favours(w, rival),
        sameGenre = rival.genre == p.genre;
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final int feeCents;

  /// Would say yes (a star does not feature on an unknown's song).
  /// On the player's own label: free and always willing (docs K170).
  final bool labelMate;
  final bool willing;

  /// One of their songs is on the player's playlist (docs K159).
  final bool favoured;
  final bool sameGenre;
}

/// What the player has to show for a career beyond awards (docs K116):
/// records held, best year-end places, music show wins, the top artists
/// chart.
class HonorsView {
  HonorsView({
    required this.recordsHeld,
    required this.bestYearEndSong,
    required this.bestYearEndAlbum,
    required this.musicShowWins,
    required this.tripleCrowns,
    required this.bestArtistRank,
    required this.weeksTopArtist,
  });

  /// Records the player holds right now.
  final List<RecordKind> recordsHeld;

  /// Best year-end places on the US charts: (rank, year, title), or null.
  final (int, int, String)? bestYearEndSong;
  final (int, int, String)? bestYearEndAlbum;
  final int musicShowWins;
  final int tripleCrowns;

  /// Best place on the top artists chart (0: never) and weeks at #1.
  final int bestArtistRank;
  final int weeksTopArtist;

  bool get isEmpty =>
      recordsHeld.isEmpty &&
      bestYearEndSong == null &&
      bestYearEndAlbum == null &&
      musicShowWins == 0 &&
      bestArtistRank == 0;
}

/// The streaming app's year in review (docs K123), out in early December
/// from 2016, like the real one: January to the end of November.
abstract final class Wrapped {
  static const firstYear = 2016;

  /// Week of the year it comes out (a week after the year-end charts).
  static const publishWeekOfYear = 49;

  /// About three and a half minutes a play.
  static const minutesPerPlay = 3.4;

  /// First and last week counted for [year].
  static (int, int) tracking(int year) => (
        GameTime.firstWeekOf(year),
        GameTime.firstWeekOf(year) + publishWeekOfYear - 2,
      );

  /// Whether [year]'s is out in [week].
  static bool publishedBy(int year, int week) =>
      year >= firstYear &&
      week >= GameTime.firstWeekOf(year) + publishWeekOfYear - 1;
}

/// What the year was, in one word (docs K123).
enum WrappedStory {
  /// The first year with plays.
  newcomer,

  /// At least three times last year's plays.
  breakout,

  /// One song carried most of it.
  oneSong,

  /// Most plays came from songs out before the year.
  catalog,

  /// Half or more down on last year.
  quiet,
  steady,
}

/// One song of the player's year on the streaming app.
class WrappedSong {
  WrappedSong(
      {required this.songId,
      required this.title,
      required this.coverAlbumId,
      required this.plays});
  final int songId;
  final String title;
  final int coverAlbumId;
  final double plays;
}

/// The player's year on the streaming app (docs K123).
class WrappedView {
  WrappedView({
    required this.year,
    required this.plays,
    required this.playsBefore,
    required this.peakListeners,
    required this.peakWeek,
    required this.topSongs,
    required this.topAlbumId,
    required this.topAlbumPlays,
    required this.regionShare,
    required this.newSongs,
    required this.topFans,
    required this.story,
  });
  final int year;

  /// Plays of the player's songs there, and the same weeks a year before
  /// (0: none).
  final double plays;
  final double playsBefore;
  double get minutes => plays * Wrapped.minutesPerPlay;

  /// The most monthly listeners in a week, and that week.
  final double peakListeners;
  final int peakWeek;

  /// The most played songs, at most five.
  final List<WrappedSong> topSongs;

  /// The most played album (-1: none) and its tracks' plays.
  final int topAlbumId;
  final double topAlbumPlays;

  /// Share of the plays in each region ([Region] order).
  final List<double> regionShare;

  /// Songs first out this year.
  final int newSongs;

  /// Listeners whose most played artist the player was.
  final double topFans;
  final WrappedStory story;

  /// Change on last year, in percent (null: no plays then).
  int? get growthPct =>
      playsBefore <= 0 ? null : ((plays / playsBefore - 1) * 100).round();

  Region get topRegion {
    var best = 0;
    for (var k = 1; k < regionShare.length; k++) {
      if (regionShare[k] > regionShare[best]) best = k;
    }
    return Region.values[best];
  }
}

/// One week of the K-pop music show (docs K114).
class MusicShowRow {
  MusicShowRow.of(World w, MusicShowWeek x)
      : week = x.week,
        songId = x.songId,
        title = w.songs[x.songId].title,
        artistName = w.artists[w.songs[x.songId].primaryArtistId].name,
        albumId = coverAlbumOf(w, w.songs[x.songId]),
        score = x.score,
        runnerUpTitle = x.runnerUpId < 0 ? '' : w.songs[x.runnerUpId].title,
        runnerUpArtist = x.runnerUpId < 0
            ? ''
            : w.artists[w.songs[x.runnerUpId].primaryArtistId].name,
        runnerUpScore = x.runnerUpScore,
        tripleCrown = x.tripleCrown,
        wins = w.musicShow.wins[x.songId] ?? 0,
        isPlayer = w.songs[x.songId].primaryArtistId == w.playerArtistId;
  final int week;
  final int songId;
  final String title;
  final String artistName;
  final int albumId;
  final int score;
  final String runnerUpTitle;
  final String runnerUpArtist;
  final int runnerUpScore;
  final bool tripleCrown;

  /// The song's wins so far.
  final int wins;
  final bool isPlayer;
}

/// One artist on the top artists chart (docs K113).
class ArtistChartRow {
  ArtistChartRow.of(World w, this.rank, int id, this.weekStreams)
      : artistId = id,
        lastRank = w.artistChartPrev.indexOf(id) + 1,
        name = w.artists[id].name,
        isPlayer = id == w.playerArtistId;
  final int rank;

  /// Last week's place (0: not on the chart).
  final int lastRank;
  final int artistId;
  final String name;
  final double weekStreams;
  final bool isPlayer;
}

/// All-time records of a save (docs K111). Index order is UI order.
enum RecordKind {
  /// Most weeks at #1 on the US songs chart (a song).
  weeksAtNo1Song,

  /// Most weeks at #1 on the US albums chart (an album).
  weeksAtNo1Album,

  /// Most weeks on the US songs chart (a song).
  weeksOnChart,

  /// Biggest US first week of an album (units).
  albumDebut,

  /// Most streams of a song in one week, worldwide.
  streamWeek,

  /// Most US #1 songs (an artist).
  mostNo1s;

  bool get isAlbum => this == weeksAtNo1Album || this == albumDebut;
  bool get isArtist => this == mostNo1s;
}

/// One holder of a record.
class RecordEntry {
  RecordEntry(
      {required this.rank,
      required this.entityId,
      required this.title,
      required this.artistName,
      required this.albumId,
      required this.isPlayer,
      required this.value});
  final int rank;

  /// Song, album or artist id (see [RecordKind]).
  final int entityId;

  /// Song or album title (empty for an artist).
  final String title;
  final String artistName;

  /// Album for the cover (-1: none).
  final int albumId;
  final bool isPlayer;

  /// Weeks, units, streams or #1s.
  final double value;
}

/// One collaborator the player can hire (fame permitting).
class CollaboratorView {
  CollaboratorView(Collaborator c,
      {required this.available, this.requiredFans = 0})
      : id = c.id,
        name = c.name,
        role = c.role,
        skill = c.skill,
        genre = c.genre,
        feeCents = c.feeCents;
  final int id;
  final String name;
  final CollaboratorRole role;
  final double skill;
  final int genre;
  final int feeCents;

  /// False when the collaborator still refuses the player (too few fans).
  final bool available;

  /// Core fans this collaborator wants (0 = works with anyone).
  final int requiredFans;
}

/// This week's units of an album in a chart market (US/UK are shares of
/// their region, like [World.albumFirstWeekIn]).
double albumWeekUnitsIn(World w, Album al, ChartMarket market) {
  if (al.status != AlbumStatus.active) return 0;
  final home = w.artists[al.artistId].homeCountry;
  double units(Region r) => al.weekRegion[regionCount + r.index];
  return switch (market) {
    ChartMarket.us =>
      CountryShares.usOfNorthAmerica(home) * units(Region.northAmerica),
    ChartMarket.uk => CountryShares.ukOfEurope(home) * units(Region.europe),
    _ => al.weekUnits,
  };
}

/// Radio in numbers the trade press uses (docs K128), from a song's radio
/// audience: about 8,000 listeners hear each play, a station playing a
/// song spins it about 12 times a week, some 1,800 stations report.
abstract final class Radio {
  static const listenersPerSpin = 8000.0;
  static const spinsPerStation = 12.0;
  static const reportingStations = 1800;

  static double spins(double audience) => audience / listenersPerSpin;

  /// Stations reporting in the UK (docs K254).
  static const ukReportingStations = 300;

  static int stations(double audience, {int cap = reportingStations}) =>
      math.min(cap, spins(audience) / spinsPerStation).round();
}

/// A moment waiting for the player (docs K256): its scene now, the names
/// the scene mentions, the step out of how many.
class MomentView {
  MomentView.of(World w, Moment m)
      : kind = m.kind,
        scene = m.scene,
        step = m.step,
        steps = m.kind == MomentKind.crisis ? 2 : m.scenes.length,
        rivalName = m.rivalId >= 0 ? w.artists[m.rivalId].name : '',
        songTitle = m.songId >= 0 ? w.songs[m.songId].title : '',
        crisis = m.crisis >= 0 ? OpportunityKind.values[m.crisis] : null;
  final MomentKind kind;
  final MomentScene scene;
  final int step, steps;
  final String rivalName, songTitle;
  final OpportunityKind? crisis;
}

/// The player's station visits (docs K254): per market, whether one is
/// possible now and how long the last one still helps.
class RadioVisitsView {
  RadioVisitsView.of(World w, Artist a)
      : energy = RadioTools.visitEnergy.round(),
        markets = [
          for (final m in RadioMarket.values)
            (
              market: m,
              can: RadioTools.canVisit(w, a, m),
              weeksLeft: () {
                final last = RadioTools.lastVisit(w, m);
                return last < 0
                    ? 0
                    : math.max(0, RadioTools.visitWeeks - (w.week - last));
              }(),
              nextIn: () {
                final last = RadioTools.lastVisit(w, m);
                return last < 0
                    ? 0
                    : math.max(0, RadioTools.visitGapWeeks - (w.week - last));
              }(),
            )
        ];
  final int energy;
  final List<({RadioMarket market, bool can, int weeksLeft, int nextIn})>
      markets;
}

/// A song stations added this week (docs K254).
class RadioAdd {
  const RadioAdd(
      {required this.songId,
      required this.title,
      required this.artistId,
      required this.artistName,
      required this.stations,
      required this.added});
  final int songId;
  final String title;
  final int artistId;
  final String artistName;

  /// Stations playing it now, and those new this week.
  final int stations;
  final int added;
}

/// The fictional streaming platform's view of an artist (Streamify artist
/// page): its share of all streams, monthly listeners, popular tracks.
abstract final class Streamify {
  /// Share of all on-demand streams that happen on the platform: 0.45
  /// until docs K207, when a song with 400M plays here showed 1B in all.
  static const share = 0.6;

  /// Monthly listeners from weekly streams (about 16 plays per listener a
  /// month on the platform; 12 at the old share gave the same listeners).
  static double monthlyListeners(double weeklyStreams) =>
      weeklyStreams * share * 4.3 / 16;

  /// Share of a region's listeners in its big cities together.
  static const _cityShare = 0.4;

  /// The five cities with the most of [monthly] listeners (docs K130):
  /// each region's listeners spread over its big cities by size, more at
  /// home and where the genre is big.
  static List<CityListeners> topCities(List<double> regionShare,
      HomeCountry home, int genre, double monthly) {
    if (monthly <= 0) return const [];
    double weight(_City c) {
      var x = c.size;
      if (c.genres.contains(genre)) x *= c.genreBoost;
      if (c.home == home) x *= 2.5;
      return x;
    }

    final out = <CityListeners>[];
    for (final r in Region.values) {
      final cities = [
        for (final c in _cities)
          if (c.region == r) c
      ];
      final sum = cities.fold(0.0, (t, c) => t + weight(c));
      for (final c in cities) {
        out.add(CityListeners(c.name,
            monthly * regionShare[r.index] * _cityShare * weight(c) / sum));
      }
    }
    out.sort((a, b) => b.listeners.compareTo(a.listeners));
    return out.take(5).toList();
  }

  static const _latin = [6, 16];
  static const _cities = [
    _City('New York', Region.northAmerica, 1.0, home: HomeCountry.us),
    _City('Los Angeles', Region.northAmerica, 0.95, home: HomeCountry.us),
    _City('Chicago', Region.northAmerica, 0.6),
    _City('Houston', Region.northAmerica, 0.55, genres: _latin),
    _City('Dallas', Region.northAmerica, 0.5, genres: [4]),
    _City('Atlanta', Region.northAmerica, 0.5, genres: [1, 2]),
    _City('Toronto', Region.northAmerica, 0.45, home: HomeCountry.canada),
    _City('Mexico City', Region.northAmerica, 0.8,
        genres: _latin, genreBoost: 3),
    _City('Miami', Region.northAmerica, 0.4, genres: _latin, genreBoost: 2),
    _City('Nashville', Region.northAmerica, 0.2, genres: [4], genreBoost: 5),
    _City('London', Region.europe, 1.0,
        home: HomeCountry.uk, genres: [17], genreBoost: 1.5),
    _City('Paris', Region.europe, 0.7, home: HomeCountry.europe),
    _City('Berlin', Region.europe, 0.6, genres: [5], genreBoost: 1.5),
    _City('Madrid', Region.europe, 0.5, genres: _latin, genreBoost: 1.5),
    _City('Amsterdam', Region.europe, 0.45, genres: [5], genreBoost: 1.5),
    _City('Stockholm', Region.europe, 0.4),
    _City('Istanbul', Region.europe, 0.5),
    _City('Milan', Region.europe, 0.4),
    _City('Warsaw', Region.europe, 0.35),
    _City('São Paulo', Region.other, 1.0, genres: _latin, genreBoost: 1.5),
    _City('Jakarta', Region.other, 0.9, genres: [18], genreBoost: 2),
    _City('Manila', Region.other, 0.7, genres: [18], genreBoost: 2),
    _City('Sydney', Region.other, 0.6),
    _City('Santiago', Region.other, 0.6, genres: _latin, genreBoost: 2),
    _City('Bogotá', Region.other, 0.55, genres: _latin, genreBoost: 2),
    _City('Buenos Aires', Region.other, 0.5, genres: _latin, genreBoost: 2),
    _City('Lagos', Region.other, 0.5, genres: [17], genreBoost: 4),
    _City('Seoul', Region.other, 0.5, genres: [18], genreBoost: 4),
    _City('Tokyo', Region.other, 0.45, genres: [18], genreBoost: 1.5),
    _City('Bangkok', Region.other, 0.45, genres: [18], genreBoost: 1.5),
    _City('Johannesburg', Region.other, 0.35, genres: [17], genreBoost: 2),
  ];
}

class _City {
  const _City(this.name, this.region, this.size,
      {this.home, this.genres = const [], this.genreBoost = 1});
  final String name;
  final Region region;
  final double size;
  final HomeCountry? home;
  final List<int> genres;
  final double genreBoost;
}

/// A city and its monthly listeners (docs K130).
class CityListeners {
  const CityListeners(this.name, this.listeners);
  final String name;
  final double listeners;
}

class ArtistPageView {
  ArtistPageView({
    required this.artist,
    required this.weeklyStreams,
    double? listenerStreams,
    required this.popular,
    required this.albums,
    required this.singles,
    this.followers = 0,
    this.worldRank = 0,
    this.listenerHistory = const [],
    this.peakListeners = 0,
  }) : listenerStreams = listenerStreams ?? weeklyStreams;

  /// The player's most monthly listeners so far (docs K156; 0 for others).
  final double peakListeners;

  /// The player's monthly listeners over the last half year, oldest first
  /// (docs K130; empty for other artists).
  final List<double> listenerHistory;

  /// Where the listeners are: the five biggest cities (docs K130).
  List<CityListeners> get topCities => Streamify.topCities(
      artist.regionShare, artist.home, artist.genre, monthlyListeners);

  /// Place in the world by listeners (docs K113; 0: below the top 500).
  final int worldRank;

  /// Followers on Streamify (docs K82).
  final double followers;

  final ArtistView artist;

  /// All platforms; use [Streamify] for the platform's numbers.
  final double weeklyStreams;

  /// Most played songs right now (up to 10).
  final List<SongView> popular;

  /// Albums and EPs, newest first.
  final List<AlbumView> albums;

  /// Singles not on an album, newest first.
  final List<SongView> singles;

  /// Weekly streams averaged over the last month where known (the player);
  /// monthly listeners follow it rather than a single week.
  final double listenerStreams;

  double get monthlyListeners => Streamify.monthlyListeners(listenerStreams);
}

/// Which number best tells a song's success in a given year (docs K38):
/// CD singles and radio in the early 2000s, then downloads, then streams.
/// A player release set for a later week (docs K45).
class ScheduledView {
  ScheduledView.of(World w, ScheduledRelease sr)
      : id = sr.id,
        type = sr.type,
        title = sr.isAlbum ? sr.title : w.songs[sr.songIds.single].title,
        songIds = List.unmodifiable(sr.songIds),
        releaseWeek = sr.releaseWeek,
        announceWeek = sr.announceWeek,
        announced = sr.announcedBy(w.week),
        isSurprise = sr.isSurprise,
        isDraft = sr.isDraft,
        createdWeek = sr.createdWeek,
        editionsCostCents = Actions.editionsCostCents(
            sr.variantWeeks.length, sr.variantFormats),
        campaign = sr.campaign,
        radioPush = sr.radioPush,
        paidCents = sr.paidCents,
        buzz = sr.buzz,
        preSaves = sr.preSaves,
        preOrders = sr.preOrders,
        buzzCap = Actions.announceCap(
            w, w.player!, sr.type, w.week - 1 - sr.announceWeek),
        rollout = sr.isAlbum && !sr.isDraft && Rollouts.counts(sr.type)
            ? Rollouts.status(w, w.player!, sr.songIds, sr.releaseWeek,
                sr.isSurprise ? -1 : sr.announceWeek,
                planned: true)
            : null;

  final int id;
  final AlbumType type;

  /// How an album's rollout stands, with singles set for later (null: a
  /// single or a draft; docs K165).
  final RolloutStatus? rollout;

  /// The album title, or the single's song title.
  final String title;
  final List<int> songIds;
  final int releaseWeek;

  /// Equal to [releaseWeek] for a surprise release.
  final int announceWeek;
  final bool announced;
  final bool isSurprise;

  /// Kept in the vault with no date (docs F31); [releaseWeek] means nothing.
  final bool isDraft;

  /// When it was scheduled or saved as a draft.
  final int createdWeek;

  /// What its extra editions cost (paid when a draft is released or dated).
  final int editionsCostCents;
  final Campaign campaign;
  final RadioPush radioPush;
  final int paidCents;

  /// Excitement built since the announcement, and its ceiling.
  final double buzz;

  /// Pre-saves on the streaming apps so far (docs K121).
  final double preSaves;

  /// Copies of an album or EP ordered so far (docs K126).
  final double preOrders;
  final double buzzCap;
  bool get isAlbum => type != AlbumType.single;
}

/// A record label's terms for the player (docs K54).
class LabelView {
  LabelView.of(World w, Artist p, this.label, this.missing)
      : isCurrent = p.label == label,
        contractAlbumsLeft = p.contractAlbumsLeft,
        buyoutCents = Actions.buyoutCents(w, p),
        moneyCents = p.moneyCents,
        legend = w.difficulty == Difficulty.legend,
        leverage = Contracts.leverage(w, p, label),
        deals = {
          for (final d in ContractDeal.values)
            d: Contracts.terms(w, p, label, d)
        },
        currentShare = p.artistShare,
        unrecoupedCents = p.label == label ? p.unrecoupedCents : 0;

  final Label label;

  /// How much the label wants the player (0–1; docs K107), and what each
  /// deal shape would give.
  final double leverage;
  final Map<ContractDeal, ContractTerms> deals;

  /// The player's split now, and what of the current label's advance is
  /// still to be paid back (this label only).
  final double currentShare;
  final int unrecoupedCents;

  /// What the player still lacks for this label to sign them.
  final List<LabelRequirement> missing;
  final bool isCurrent;
  final int contractAlbumsLeft;

  /// What leaving the current label costs now (0: free to go; docs K78).
  final int buyoutCents;
  final int moneyCents;
  final bool legend;

  bool get wouldSign => missing.isEmpty;

  /// Money in hand after signing [deal]: the advance less the buyout.
  int netFor(ContractDeal deal) => deals[deal]!.advanceCents - buyoutCents;
  int get netCents => netFor(ContractDeal.standard);
  bool canAffordDeal(ContractDeal deal) => moneyCents + netFor(deal) >= 0;
  bool get canAfford =>
      ContractDeal.values.any((d) => moneyCents + netFor(d) >= 0);
  bool get canSign => wouldSign && !isCurrent && canAfford;

  /// Requirements as they apply in this game mode.
  double get minFans => label.minFans * (legend ? 0.4 : 1.0);
  double get minFame => label.minFame * (legend ? 0.4 : 1.0);
  EraResult? get minResult => legend ? null : label.minResult;
}

enum SalesEra {
  /// 2000–2004: single sales (mostly CD) first, radio second.
  physical,

  /// 2005–2011: single sales (mostly downloads) first, streams second.
  downloads,

  /// 2012 on: streams first, single sales second.
  streaming;

  static SalesEra of(int year) => year < 2005
      ? physical
      : year < 2012
          ? downloads
          : streaming;
}

bool _charted(Charted e) {
  for (var c = 0; c < Charts.count; c++) {
    if (Charts.all[c].retired) continue;
    if ((e.statsOrNull(c)?.weeksOn ?? 0) > 0) return true;
  }
  return false;
}

/// A demo on the song market (docs K205): the record's likely grade with
/// the player's voice, what it costs, and whether it is still there.
class SongPitchView {
  SongPitchView.of(World w, Artist a, SongPitch x)
      : index = x.index,
        title = x.title,
        genre = x.genre,
        writerName = x.writer.name,
        writerSkill = x.writer.skill.round(),
        writerGenre = x.writer.genre,
        priceCents = x.priceCents,
        gradeLow = (SongMarket.expected(w, a, x.demo) - SongMarket.spread)
            .round()
            .clamp(1, 100),
        gradeHigh = (SongMarket.expected(w, a, x.demo) + SongMarket.spread)
            .round()
            .clamp(1, 100),
        bought = w.boughtPitches.contains(_pitchKey(w, x)),
        taken = w.week >= x.takenWeek &&
            !w.boughtPitches.contains(_pitchKey(w, x));
  final int index;
  final String title;
  final int genre;
  final String writerName;
  final int writerSkill;
  final int writerGenre;
  final int priceCents;
  final int gradeLow, gradeHigh;

  /// The player bought it; another artist did.
  final bool bought, taken;
  bool get open => !bought && !taken;

  static int _pitchKey(World w, SongPitch x) =>
      SongMarket.period(w.week) * SongMarket.size + x.index;
}

/// The month's song market (docs K205).
class SongMarketView {
  SongMarketView.of(World w, Artist a)
      : pitches = [
          for (final x in SongMarket.pitches(w, a)) SongPitchView.of(w, a, x)
        ],
        weeksToNext =
            SongMarket.periodWeeks - w.week % SongMarket.periodWeeks,
        cutPct = (SongMarket.writerCut * 100).round();
  final List<SongPitchView> pitches;

  /// Weeks until next month's demos.
  final int weeksToNext;

  /// The writer's share of what a bought song earns, in per cent.
  final int cutPct;
}

/// An offer waiting for the player's answer (docs K59).
class OpportunityView {
  OpportunityView.of(World w, Opportunity o)
      : kind = o.kind,
        week = o.week,
        // The award show is at the end of its week (docs K91).
        weeksLeft = o.kind == OpportunityKind.award
            ? 1
            : o.week + Opportunities.answerWeeks + 1 - w.week,
        nominations = o.kind == OpportunityKind.award
            ? Awards.upcoming(w)?.racesOf(w.playerArtistId).length ?? 0
            : 0,
        partnerArtistId = o.partnerArtistId,
        partnerName =
            o.partnerArtistId >= 0 ? w.artists[o.partnerArtistId].name : '',
        feeCents = o.feeCents,
        brand = o.kind == OpportunityKind.brandDeal && o.brand >= 0
            ? Brands.all[o.brand]
            : null,
        brandFit = o.kind == OpportunityKind.brandDeal && o.brand >= 0
            ? Brands.fit(Brands.all[o.brand], w.player!)
            : 0,
        brandTasks = o.kind == OpportunityKind.brandDeal && o.brand >= 0
            ? [
                for (final t in Brands.tasksFor(Brands.all[o.brand], w.week))
                  t.$1
              ]
            : const [],
        songTitle = o.songId >= 0 ? w.songs[o.songId].title : '',
        medium = o.medium,
        memberName = o.member >= 0 && o.member < w.player!.members.length
            ? w.player!.members[o.member]
            : '',
        choices = o.choices;

  final OpportunityKind kind;

  /// The group member it is about (docs K87).
  final String memberName;
  final int week;

  /// Weeks still played before it lapses (1 = answer before next week).
  final int weeksLeft;
  final int partnerArtistId;
  final String partnerName;
  /// A sync's song and where it would be heard (docs K262).
  final String songTitle;
  final SyncMedium medium;
  final int feeCents;

  /// Award show: how many awards the player is up for.
  final int nominations;

  /// Brand deal (docs K102): the brand, how well it suits the artist
  /// (0..1) and the work it asks for.
  final BrandInfo? brand;
  final double brandFit;
  final List<DealTask> brandTasks;
  final List<OpportunityChoice> choices;
}

/// What a song cost the player: writing it, its own campaign, its video.
int _songCosts(Song s) =>
    s.productionCostCents +
    s.campaignCostCents +
    (s.videoBudget >= 0 ? VideoBudget.values[s.videoBudget].costCents : 0);

/// A song's single units in the US (certifications; docs K60).
double usSingleUnits(World w, Song s) => _usSingleUnits(w, s);

/// An album's units in the US (certifications; docs K60).
double usAlbumUnits(World w, Album al) =>
    CountryShares.usOfNorthAmerica(w.artists[al.artistId].homeCountry) *
    w.albumLifetimeUnits(al, Region.northAmerica.index);

double _usSingleUnits(World w, Song s) {
  final a = w.primaryOf(s);
  final na = Region.northAmerica.index;
  return CountryShares.usOfNorthAmerica(a.homeCountry) *
      (w.songLifetimeDownloads(s, na) +
          s.lifetimePhysical * a.regionShare[na] +
          w.songLifetimeStreams(s, na) / SongView.streamsPerSingleUnit);
}

/// US certification levels, RIAA-style (docs K60): units sold in the US.
enum Certification {
  gold(5e5),
  platinum(1e6),
  diamond(1e7);

  const Certification(this.units);
  final double units;

  /// The level reached with [units] and how many times over (platinum
  /// counts multiples: 3× platinum), or null below gold. Diamond counts
  /// in platinum too, as the RIAA does (docs K233): 10× is diamond, then
  /// 11×, 12× platinum on a diamond record.
  static (Certification, int)? of(double units) {
    if (units >= diamond.units) {
      return (diamond, (units / platinum.units).floor());
    }
    if (units >= platinum.units) {
      return (platinum, (units / platinum.units).floor());
    }
    if (units >= gold.units) return (gold, 1);
    return null;
  }

  /// A recorded [multiple] of [c] in platinum terms: saves from before
  /// docs K233 counted diamonds (2× diamond = 20× platinum).
  static int times(Certification c, int multiple) =>
      c == diamond && multiple < 10 ? multiple * 10 : multiple;

  /// The units [multiple] of [c] stands for.
  static double unitsOf(Certification c, int multiple) => c == diamond
      ? platinum.units * times(c, multiple)
      : c.units * multiple;
}

/// One song on the stream counter (docs K210): Streamify plays a day
/// (this week's average), the change from last week's and the total.
class CounterRow {
  const CounterRow({
    required this.songId,
    required this.title,
    required this.daily,
    required this.change,
    required this.total,
  });
  final int songId;
  final String title;
  final double daily;

  /// Plays a day more (or fewer) than last week's average.
  final double change;
  final double total;

  /// [change] against last week's daily plays (0 with none).
  double get changeShare =>
      daily - change > 0 ? change / (daily - change) : 0;
}

/// A version of an album put out after it (docs K225).
class AlbumVersionView {
  const AlbumVersionView({
    required this.edition,
    required this.week,
    required this.name,
    required this.trackIds,
    required this.anniversaryYears,
    required this.format,
  });

  /// Its edition (cover) index.
  final int edition;
  final int week;

  /// The player's name for it ('': the default).
  final String name;
  final List<int> trackIds;

  /// The anniversary it marks (0: none).
  final int anniversaryYears;
  final EditionFormat? format;
}

/// An album anniversary to ask the player about (docs K226).
class AnniversaryPrompt {
  const AnniversaryPrompt({
    required this.albumId,
    required this.title,
    required this.years,
    required this.releaseWeek,
    required this.quickCostCents,
    required this.trackCount,
    required this.lifetimeUnits,
  });
  final int albumId;
  final String title;
  final int years;
  final int releaseWeek;

  /// The quick reissue: remastered, on vinyl (docs K149).
  final int quickCostCents;
  final int trackCount;
  final double lifetimeUnits;
}

/// A release's Streamify counter, like the fan accounts post (docs K210):
/// daily plays, their change and the total, song by song.
class StreamCounterView {
  StreamCounterView({
    required this.kind,
    required this.id,
    required this.title,
    required this.artistName,
    required this.coverAlbumId,
    required this.week,
    required this.rows,
  });
  final EntityKind kind;
  final int id;
  final String title;
  final String artistName;

  /// The album whose cover it shows (-1: a single's own).
  final int coverAlbumId;

  /// The week the numbers are from.
  final int week;
  final List<CounterRow> rows;

  double get daily => rows.fold(0.0, (t, r) => t + r.daily);
  double get change => rows.fold(0.0, (t, r) => t + r.change);
  double get total => rows.fold(0.0, (t, r) => t + r.total);
  double get changeShare => daily - change > 0 ? change / (daily - change) : 0;
}

/// What kind of release a plaque is for (docs K209).
enum PlaqueFormat { single, track, album, ep, mixtape }

/// One certified release (docs K209): its highest level, when and under
/// which label it came, and how far the next one is.
class PlaqueView {
  PlaqueView.of(World w, EntityKind kind, int id, List<List<int>> levels)
      : kind = kind,
        id = id,
        title =
            kind == EntityKind.song ? w.songs[id].title : w.albums[id].title,
        artistName = w
            .artists[kind == EntityKind.song
                ? w.songs[id].primaryArtistId
                : w.albums[id].artistId]
            .name,
        coverAlbumId =
            kind == EntityKind.song ? coverAlbumOf(w, w.songs[id]) : id,
        format = kind == EntityKind.song
            ? (w.songs[id].isSingle ? PlaqueFormat.single : PlaqueFormat.track)
            : switch (w.albums[id].type) {
                AlbumType.ep => PlaqueFormat.ep,
                AlbumType.mixtape => PlaqueFormat.mixtape,
                _ => PlaqueFormat.album,
              },
        levels = [
          for (final x in levels)
            (
              Certification.values[x[0]],
              Certification.times(Certification.values[x[0]], x[1]),
              x[2],
              Label.values[x[3]]
            )
        ],
        usUnits = kind == EntityKind.song
            ? usSingleUnits(w, w.songs[id])
            : usAlbumUnits(w, w.albums[id]),
        totalStreams = kind == EntityKind.song
            ? [
                for (var r = 0; r < regionCount; r++)
                  w.songLifetimeStreams(w.songs[id], r)
              ].fold(0.0, (t, x) => t + x)
            : [
                for (final s in w.albums[id].songIds)
                  for (var r = 0; r < regionCount; r++)
                    w.songLifetimeStreams(w.songs[s], r)
              ].fold(0.0, (t, x) => t + x),
        releaseWeek = kind == EntityKind.song
            ? w.songs[id].releasedWeek
            : w.albums[id].releaseWeek;
  final EntityKind kind;
  final int id;
  final String title;
  final String artistName;

  /// The album whose cover it shows (-1: a single's own cover).
  final int coverAlbumId;
  final PlaqueFormat format;

  /// Every level reached, in order: level, multiple, week, label then.
  final List<(Certification, int, int, Label)> levels;
  final double usUnits;
  final double totalStreams;
  final int releaseWeek;

  (Certification, int, int, Label) get top => levels.last;

  /// Units the top level stands for.
  double get topUnits => Certification.unitsOf(top.$1, top.$2);

  /// The next level and the units it needs (after 9× platinum comes
  /// diamond, then 11× platinum and on).
  (Certification, int, double) get next {
    final (c, m, _, _) = top;
    if (c == Certification.gold) {
      return (Certification.platinum, 1, Certification.platinum.units);
    }
    if (c == Certification.platinum && m < 9) {
      return (
        Certification.platinum,
        m + 1,
        Certification.platinum.units * (m + 1)
      );
    }
    // Past diamond, every million is one more platinum (docs K233).
    final d = c == Certification.diamond ? m + 1 : 10;
    return (Certification.diamond, d, Certification.platinum.units * d);
  }
}

/// One release in the player's chart history (docs K232): its runs on
/// every chart, and for an album how many of its songs charted, made the
/// top 10 and went to #1 on the matching songs chart.
class ChartHistoryEntry {
  ChartHistoryEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.artistName,
    required this.coverAlbumId,
    required this.releaseWeek,
    required this.records,
    this.feature = false,
    this.hits = const {},
  });
  final EntityKind kind;
  final int id;
  final String title;

  /// The headliner (a rival on a feature).
  final String artistName;
  final int coverAlbumId;
  final int releaseWeek;
  final List<ChartRecord> records;

  /// A verse on a rival's song (docs K158).
  final bool feature;

  /// Album chart id to (charted, top 10s, #1s) among its songs on the
  /// matching songs chart.
  final Map<int, (int, int, int)> hits;

  ChartRecord? on(int chartId) =>
      records.where((r) => r.chartId == chartId).firstOrNull;
}

/// The player's whole chart history (docs K232): songs (with features on
/// rivals' songs) and albums, newest first.
class ChartHistoryView {
  ChartHistoryView.of(World w)
      : songs = [],
        albums = [] {
    final me = w.playerArtistId;
    ChartHistoryEntry song(Song s, {bool feature = false}) =>
        ChartHistoryEntry(
          kind: EntityKind.song,
          id: s.id,
          title: s.title,
          artistName: w.artists[s.primaryArtistId].name,
          coverAlbumId: coverAlbumOf(w, s),
          releaseWeek:
              s.isSingle && s.singleWeek >= 0 ? s.singleWeek : s.releasedWeek,
          records: _records(s),
          feature: feature,
        );
    for (final id in w.playerSongIds.reversed) {
      final s = w.songs[id];
      if (s.primaryArtistId != me || s.releasedWeek < 0) continue;
      if (_records(s).isEmpty) continue;
      songs.add(song(s));
    }
    for (final id in w.guestSongIds.reversed) {
      final s = w.songs[id];
      if (s.releasedWeek < 0 || !s.featuredArtistIds.contains(me)) continue;
      if (_records(s).isEmpty) continue;
      songs.add(song(s, feature: true));
    }
    songs.sort((a, b) => b.releaseWeek.compareTo(a.releaseWeek));
    for (final al in w.albums.reversed) {
      if (al.artistId != me || al.releaseWeek > w.week) continue;
      albums.add(ChartHistoryEntry(
        kind: EntityKind.album,
        id: al.id,
        title: al.title,
        artistName: w.artists[al.artistId].name,
        coverAlbumId: al.id,
        releaseWeek: al.releaseWeek,
        records: _records(al),
        hits: {
          for (final (albumChart, songChart) in const [
            (Charts.usAlbums, Charts.usSongs),
            (Charts.ukAlbums, Charts.ukSongs),
            (Charts.globalAlbums, Charts.globalSongs),
          ])
            albumChart: albumHits(w, al, songChart),
        },
      ));
    }
  }
  final List<ChartHistoryEntry> songs;
  final List<ChartHistoryEntry> albums;

  /// Of [al]'s songs on [songChart]: (charted, top 10s, #1s).
  static (int, int, int) albumHits(World w, Album al, int songChart) {
    var charted = 0, top10 = 0, no1 = 0;
    for (final id in al.songIds) {
      final peak = w.songs[id].peakOn(songChart);
      if (peak <= 0) continue;
      charted++;
      if (peak <= 10) top10++;
      if (peak == 1) no1++;
    }
    return (charted, top10, no1);
  }
}

/// The player's plaques (docs K209): how many releases stand at each
/// level, newest certification first.
class CertificationsView {
  CertificationsView(this.plaques)
      : gold = plaques.where((p) => p.top.$1 == Certification.gold).length,
        platinum =
            plaques.where((p) => p.top.$1 == Certification.platinum).length,
        diamond =
            plaques.where((p) => p.top.$1 == Certification.diamond).length;
  final List<PlaqueView> plaques;
  final int gold, platinum, diamond;
}

/// A career milestone and how far the player is (docs K61).
class MilestoneView {
  MilestoneView(
      {required this.milestone, required this.reachedWeek, this.progress});
  final Milestone milestone;

  /// Week it was reached, or null.
  final int? reachedWeek;

  /// (have, need) for count goals.
  final (double, double)? progress;

  bool get reached => reachedWeek != null;
}

/// A tour on the road (docs K63).
class TourView {
  TourView.of(World w, Tour t)
      : name = t.name,
        kind = t.kind,
        legs = List.unmodifiable(t.legs),
        production = t.production,
        priceFactor = t.priceFactor,
        openerName = t.openerId >= 0 ? w.artists[t.openerId].name : null,
        weeks = t.weeks,
        weekOfTour = (w.week - t.startWeek + 1).clamp(1, t.weeks),
        shows = [for (final s in t.shows) TourShowView.of(t, s)],
        thisWeek = [for (final s in t.showsIn(w.week)) TourShowView.of(t, s)],
        tickets = t.tickets,
        grossCents = t.grossCents.round(),
        merchCents = t.merchCents.round(),
        costCents = t.costCents.round(),
        netCents = t.netCents.round(),
        fans = t.fans,
        soldOut = t.soldOut,
        setlist = [for (final id in t.setlist) w.songs[id].title];

  /// The songs played each night (docs K223).
  final List<String> setlist;

  /// The player's name for it ('' = named after its biggest venues).
  final String name;

  /// The biggest venues on the tour.
  final TourKind kind;
  final List<TourLeg> legs;
  final TourProduction production;
  final double priceFactor;
  final String? openerName;
  final int weeks;

  /// The week of the tour about to be played (1-based).
  final int weekOfTour;

  /// Every night, played ones with their numbers.
  final List<TourShowView> shows;

  /// Nights this coming week.
  final List<TourShowView> thisWeek;
  final double tickets;
  final int grossCents;
  final int merchCents;
  final int costCents;
  final int netCents;
  final double fans;
  final int soldOut;

  int get played => shows.where((s) => s.played).length;
}

/// One of the player's finished tours (docs K208). Tours from before the
/// history was kept have only the box-office numbers ([detailed] false).
class TourHistoryView {
  TourHistoryView({
    required this.startWeek,
    required this.endWeek,
    required this.name,
    required this.artistName,
    required this.reunion,
    required this.shows,
    required this.tickets,
    required this.grossCents,
    required this.allTimeRank,
    this.kind,
    this.markets = const [],
    this.soldOut = 0,
    this.netCents = 0,
    this.fans = 0,
  });
  final int startWeek, endWeek;
  final String name;

  /// Who it went down as: the player, their group, or the reunited group.
  final String artistName;
  final bool reunion;
  final int shows;
  final double tickets;
  final double grossCents;

  /// Its place among every tour ever played in this world, by gross.
  final int allTimeRank;
  final TourKind? kind;
  final List<TourMarket> markets;
  final int soldOut;
  final int netCents;
  final double fans;

  bool get detailed => kind != null;
}

/// One night of a tour (docs K76): where, when, how big, and its tickets
/// (sold once played, else expected when planning).
class TourShowView {
  TourShowView({
    required this.weekOfTour,
    required this.market,
    required this.city,
    required this.venue,
    required this.kind,
    required this.capacity,
    required this.priceCents,
    required this.played,
    required this.tickets,
    required this.grossCents,
  });

  TourShowView.of(Tour t, TourShow s, [ShowResult? expected])
      : weekOfTour = s.week - t.startWeek + 1,
        market = s.market,
        city = s.cityName,
        venue = s.venue,
        kind = t.legs[s.leg].kind,
        capacity = s.capacity,
        priceCents = s.priceCents,
        played = s.played,
        tickets = s.played ? s.sold : (expected?.sold ?? 0),
        grossCents =
            (s.played ? s.grossCents : (expected?.grossCents ?? 0)).round();

  final int weekOfTour;
  final TourMarket market;
  final String city;
  final String venue;
  final TourKind kind;
  final int capacity;
  final int priceCents;
  final bool played;
  final double tickets;
  final int grossCents;

  bool get soldOut => tickets >= capacity * Tours.soldOutShare;
}

/// What the player asks for when planning a tour (docs K76).
class TourRequest {
  const TourRequest({
    required this.legs,
    this.name = '',
    this.priceFactor = 1.0,
    this.production = TourProduction.standard,
    this.openerId = -1,
    this.reunion = false,
    this.setlist = const [],
  });
  final List<TourLeg> legs;

  /// Songs for the set, in order (empty: the biggest ones; docs K223).
  final List<int> setlist;
  final String name;
  final double priceFactor;
  final TourProduction production;
  final int openerId;

  /// Played as the old group on its reunion (docs K196).
  final bool reunion;
}

/// A song that can go on a tour's setlist (docs K223).
class SetlistSong {
  SetlistSong.of(World w, Song s)
      : songId = s.id,
        title = s.title,
        albumId = coverAlbumOf(w, s),
        albumTitle = s.albumId >= 0 ? w.albums[s.albumId].title : null,
        streams = w.songLifetimeStreams(s),
        peak = s.statsOrNull(Charts.usSongs)?.peak ?? 0;
  final int songId;
  final String title;
  final int albumId;

  /// The album it is on (null: a single only).
  final String? albumTitle;
  final double streams;

  /// Best place on the US songs chart (0: never charted).
  final int peak;
}

/// A city a leg can play and the venues it offers there (docs K223).
class TourCityView {
  TourCityView(this.city, this.name, this.venues);
  final int city;
  final String name;

  /// Venue name and seats, by option.
  final List<(String, int)> venues;
}

/// One leg as planned: its expected turnout.
class TourLegView {
  TourLegView(
      {required this.leg,
      required this.tickets,
      required this.fill,
      required this.grossCents,
      required this.maxShows,
      required this.priceCents,
      this.mood = 1});
  final TourLeg leg;

  /// The market's appetite against a fresh one (docs K249): below 1 when
  /// toured lately, above after a long break.
  final double mood;
  final double tickets;
  final double fill;
  final int grossCents;

  /// Most shows this market can take at this size.
  final int maxShows;
  final int priceCents;
}

/// A rival who could open the tour, and their fee a night.
class OpenerView {
  OpenerView(
      {required this.artistId,
      required this.name,
      required this.genre,
      required this.fame,
      required this.coreFans,
      required this.feeCents});
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final double coreFans;
  final int feeCents;
}

/// A tour as planned now: what it would do, night by night, and what
/// stops it (docs K76).
class TourPlanView {
  TourPlanView({
    required this.request,
    required this.problems,
    required this.estimate,
    required this.netCents,
    required this.weeks,
    required this.legs,
    required this.schedule,
    required this.openerName,
    required this.openerFeeCents,
    required this.setlist,
  });
  final TourRequest request;

  /// The set as it would be played (docs K223).
  final List<SetlistSong> setlist;

  /// Why it cannot start: 'onTour', 'tourMarkets', 'tourTooBig',
  /// 'tourShows', 'noReunion', 'reunionTourLong' (empty = ready).
  final List<String> problems;
  final TourWeek estimate;

  /// What the player would keep (their manager's cut taken; K68).
  final int netCents;
  final int weeks;
  final List<TourLegView> legs;
  final List<TourShowView> schedule;
  final String? openerName;
  final int openerFeeCents;

  bool get available => problems.isEmpty;
}

/// A big rival's album due soon (docs K69): release dates are known about
/// two months ahead, so the player can pick their week around it.
class UpcomingRelease {
  UpcomingRelease(
      {required this.artistId,
      required this.artistName,
      required this.title,
      required this.week,
      required this.fame});
  final int artistId;
  final String artistName;
  final String title;
  final int week;
  final double fame;
}

/// A festival's next edition as the player sees it (docs K77).
class FestivalView {
  FestivalView({
    required this.index,
    required this.festival,
    required this.year,
    required this.week,
    required this.slot,
    required this.booked,
    required this.feeCents,
    required this.watched,
    required this.fans,
    required this.fitsGenre,
  });
  final int index;
  final Festival festival;
  final int year;

  /// Its week in the game calendar.
  final int week;

  /// The slot the player would get now (null: too small).
  final FestivalSlot? slot;

  /// The slot already booked (null: not booked).
  final FestivalSlot? booked;

  /// Fee, people watching and fans won for the slot shown.
  final int feeCents;
  final double watched;
  final double fans;

  /// The festival books the player's genre.
  final bool fitsGenre;

  bool get canBook => booked == null && slot != null && fitsGenre;
}

/// One act on a festival bill.
class FestivalAct {
  FestivalAct(this.artistId, this.name, this.isPlayer);
  final int artistId;
  final String name;
  final bool isPlayer;
}

/// A line in the box-office rankings (docs K77).
class TourRankView {
  TourRankView({
    required this.rank,
    required this.artistId,
    required this.artistName,
    required this.tourName,
    required this.grossCents,
    required this.tickets,
    required this.shows,
    required this.isPlayer,
    required this.onGoing,
  });
  final int rank;
  final int artistId;
  final String artistName;

  /// '' when the player left it unnamed.
  final String tourName;
  final double grossCents;
  final double tickets;
  final int shows;
  final bool isPlayer;

  /// Still on the road: numbers so far.
  final bool onGoing;
}

/// One nominee at an award show (docs K91).
class AwardNomineeView {
  AwardNomineeView._(World w, AwardRace race, int i)
      : entry = race.category.entry,
        id = race.nominees[i].id,
        artistId = race.nominees[i].artistId,
        artistName = w.artists[race.nominees[i].artistId].name,
        title = switch (race.category.entry) {
          AwardEntry.song => w.songs[race.nominees[i].id].title,
          AwardEntry.album => w.albums[race.nominees[i].id].title,
          AwardEntry.artist => w.artists[race.nominees[i].id].name,
        },
        coverAlbumId = switch (race.category.entry) {
          AwardEntry.song => coverAlbumOf(w, w.songs[race.nominees[i].id]),
          AwardEntry.album => race.nominees[i].id,
          AwardEntry.artist => -1,
        },
        isPlayer = race.nominees[i].artistId == w.playerArtistId,
        isWinner = race.winner == i;

  final AwardEntry entry;

  /// Song, album or artist id (by [entry]).
  final int id;
  final int artistId;
  final String artistName;
  final String title;

  /// The album whose cover it shows (-1: a song's own, or an artist).
  final int coverAlbumId;
  final bool isPlayer;
  final bool isWinner;
}

class AwardRaceView {
  AwardRaceView._(World w, AwardRace race)
      : category = race.category,
        genre = race.genre,
        nominees = [
          for (var i = 0; i < race.nominees.length; i++)
            AwardNomineeView._(w, race, i)
        ];
  final AwardCategory category;

  /// [genreNames] index for the genre album award.
  final int genre;
  final List<AwardNomineeView> nominees;
}

/// One year's Golden Record Awards.
class AwardShowView {
  AwardShowView.of(World w, AwardShow s)
      : year = s.year,
        held = s.held,
        ceremonyWeek = s.ceremonyWeek,
        eligibleFrom = Awards.window(s.year).$1,
        eligibleTo = Awards.window(s.year).$2 - 1,
        races = [for (final r in s.races) AwardRaceView._(w, r)],
        playerNominations = s.racesOf(w.playerArtistId).length,
        playerWins = s.winsOf(w.playerArtistId).length;
  final int year;
  final bool held;
  final int ceremonyWeek;

  /// First and last week of the records it honors.
  final int eligibleFrom;
  final int eligibleTo;
  final List<AwardRaceView> races;
  final int playerNominations;
  final int playerWins;
}

/// One post in the social feed (docs K93).
class SocialItemView {
  SocialItemView.of(World w, SocialItem i)
      : week = i.week,
        topic = i.topic,
        variant = i.variant,
        fan = i.fan,
        title = i.brand >= 0
            ? Brands.all[i.brand].name
            : i.songId >= 0
                ? w.songs[i.songId].title
                : i.albumId >= 0
                    ? w.albums[i.albumId].title
                    : '',
        likes = i.likes,
        number = i.number,
        songId = i.songId,
        albumId = i.albumId,
        rivalName = i.artistId >= 0 ? w.artists[i.artistId].name : '',
        rivalId = i.artistId,
        key = Comments.keyOf(i),
        authorMood = i.fan >= 0 ? Comments.authorMood(i) : null,
        answered = i.fan >= 0
            ? Comments.replyTo(w, i, Comments.author)?.kind
            : null,
        haters = i.byPlayer && w.player != null
            ? Comments.of(w, w.player!, i)
                .where((c) =>
                    c.mood == CommentMood.hater &&
                    Comments.replyTo(w, i, c.index) == null)
                .length
            : 0,
        coverAlbumId = i.albumId >= 0
            ? i.albumId
            : i.songId >= 0
                ? coverAlbumOf(w, w.songs[i.songId])
                : -1,
        media = _mediaOf(i);
  final int week;
  final FanTopic topic;
  final int variant;

  /// The fan's handle seed (-1: the player, [SocialItem.byRival]: the
  /// rival's own post).
  final int fan;
  bool get isPlayer => fan == -1;

  /// The rival posting it themself (docs K234).
  bool get isRival => fan == SocialItem.byRival;

  /// The rival a beef post is about ('' and -1 for none; docs K229).
  final String rivalName;
  final int rivalId;

  /// Opens the post with its comments (docs K238).
  final int key;

  /// How a fan post's author feels about the player, and the player's
  /// answer to it (null: none yet), to answer from the feed (docs K252).
  final CommentMood? authorMood;
  final ReplyKind? answered;

  /// Haters under the player's own post not answered yet (docs K252).
  final int haters;

  /// The song or album it talks about ('' if none).
  final String title;
  final int likes;
  final int number;

  /// The song or album it talks about (-1: none); the cover it shows.
  final int songId, albumId, coverAlbumId;
  bool get isAlbum => albumId >= 0;

  /// What the post shows under its text (docs K211); [SocialView] keeps
  /// it on the first post about a release in a week only.
  PostMedia media;

  static PostMedia _mediaOf(SocialItem i) {
    if (i.topic == FanTopic.postTeaser) return PostMedia.snippet;
    if (i.songId < 0 && i.albumId < 0) return PostMedia.none;
    return switch (i.topic) {
      FanTopic.numberOne || FanTopic.topTen || FanTopic.yearEndHit =>
        PostMedia.chart,
      FanTopic.bigWeek || FanTopic.billionsClub => PostMedia.stat,
      FanTopic.criticHigh || FanTopic.criticLow => PostMedia.score,
      FanTopic.releaseLove ||
      FanTopic.releaseMixed ||
      FanTopic.releaseHate ||
      FanTopic.deluxeOut ||
      FanTopic.versionOut ||
      FanTopic.cashGrab ||
      FanTopic.anniversaryOut ||
      FanTopic.surpriseDrop ||
      FanTopic.postPromote ||
      FanTopic.catchingOn ||
      FanTopic.viral ||
      FanTopic.recordBroken ||
      FanTopic.tripleCrown ||
      FanTopic.musicShowWin ||
      FanTopic.wrapped =>
        PostMedia.release,
      _ => PostMedia.none,
    };
  }
}

/// A post opened with its comments (docs K238).
class PostDetailView {
  PostDetailView.of(World w, Artist p, SocialItem i)
      : post = SocialItemView.of(w, i),
        network = Social.networkIn(GameTime.yearOf(w.week)),
        verified = p.fame >= 0.1 || Social.followers(w, p) >= 1e5,
        canReply = Social.canPostIn(GameTime.yearOf(w.week)) &&
            (i.byPlayer || i.fan >= 0),
        repliesLeft = Comments.repliesLeft(w),
        authorMood = i.fan >= 0 ? Comments.authorMood(i) : null,
        authorReply = switch (Comments.replyTo(w, i, Comments.author)) {
          final r? => ReplyView.of(r),
          null => null,
        },
        comments = [
          for (final c in Comments.of(w, p, i))
            CommentView(
                c,
                switch (Comments.replyTo(w, i, c.index)) {
                  final r? => ReplyView.of(r),
                  null => null,
                },
                i.byPlayer),
        ];
  final SocialItemView post;
  final SocialNetwork network;
  final bool verified;

  /// Social media is on and the post is the player's or a fan's.
  final bool canReply;
  final int repliesLeft;

  /// How a fan post's author feels about the player (null: the player's
  /// or a rival's post).
  final CommentMood? authorMood;
  final ReplyView? authorReply;
  final List<CommentView> comments;
}

/// One comment under a post (docs K238).
class CommentView {
  CommentView(Comment c, this.reply, this.answerable)
      : index = c.index,
        mood = c.mood,
        topic = c.topic,
        variant = c.variant,
        fan = c.fan,
        likes = c.likes;
  final int index;
  final CommentMood mood;
  final FanTopic topic;
  final int variant;
  final int fan;
  final int likes;

  /// The player's answer, if any.
  final ReplyView? reply;

  /// Under the player's own post: they may answer.
  final bool answerable;
}

/// The player's answer to a comment and how it went down (docs K238).
class ReplyView {
  ReplyView.of(CommentReply r)
      : kind = r.kind,
        ok = r.ok,
        variant = r.variant,
        week = r.week;
  final ReplyKind kind;
  final bool ok;
  final int variant;
  final int week;

  /// What the player wrote.
  FanTopic get topic => switch (kind) {
        ReplyKind.thanks => FanTopic.replyThanks,
        ReplyKind.clapBack => FanTopic.replyClapBack,
        ReplyKind.kind => FanTopic.replyKind,
      };

  /// The answer to it: the fan beside themself, a fan cheering the roast,
  /// the hater hitting back or softening (null: no answer).
  FanTopic? get reaction => switch ((kind, ok)) {
        (ReplyKind.thanks, _) => FanTopic.fanReplied,
        (ReplyKind.clapBack, true) => FanTopic.haterRoasted,
        (ReplyKind.clapBack, false) => FanTopic.haterComeback,
        (ReplyKind.kind, true) => FanTopic.haterSoftened,
        (ReplyKind.kind, false) => null,
      };

  /// The reaction comes from the commenter, except a fan cheering a roast.
  bool get reactionByOther => kind == ReplyKind.clapBack && ok;
}

/// What a feed post shows under its text (docs K211), as posts on real
/// networks carry a picture: the cover, a chart graphic, a big number,
/// a review score, or a sound clip for a teaser.
enum PostMedia { none, release, chart, stat, score, snippet }

/// The player's social media page (docs K93).
class SocialView {
  SocialView.of(World w, Artist p)
      : network = Social.networkIn(GameTime.yearOf(w.week)),
        canPost = Social.canPostIn(GameTime.yearOf(w.week)),
        repliesLeft = Comments.repliesLeft(w),
        followers = Social.followers(w, p),
        verified = p.fame >= 0.1 || Social.followers(w, p) >= 1e5,
        postsLeft = Social.postsPerWeek - w.social.postsIn(w.week),
        beefRivalId = Beefs.active(w)?.rivalId ?? -1,
        beefRivalName = switch (Beefs.active(w)) {
          final b? => w.artists[b.rivalId].name,
          null => '',
        },
        hasTeaser = Social.hasTeaser(w, p),
        songs = [
          for (final id in w.playerSongIds.reversed)
            if (w.songs[id].releasedWeek >= 0 &&
                w.songs[id].primaryArtistId == p.id)
              (id, w.songs[id].title),
        ].take(20).toList(),
        // Newest week first; within a week in the order it happened (a
        // post above the replies to it).
        items = _withMedia([
          for (final i in _newestWeeksFirst(w.social.feed).take(60))
            SocialItemView.of(w, i)
        ]);

  /// One picture of each kind per release a week (docs K211): a chart
  /// graphic, a big number and a score each show once; the plain cover
  /// only when none of them does. Other posts about it only write.
  static List<SocialItemView> _withMedia(List<SocialItemView> items) {
    final shown = <(int, int, int, PostMedia)>{};
    final pictured = <(int, int, int)>{};
    for (final i in items) {
      final m = i.media;
      if (m == PostMedia.none ||
          m == PostMedia.snippet ||
          m == PostMedia.release) {
        continue;
      }
      if (shown.add((i.week, i.songId, i.albumId, m))) {
        pictured.add((i.week, i.songId, i.albumId));
      } else {
        i.media = PostMedia.none;
      }
    }
    for (final i in items) {
      if (i.media == PostMedia.release &&
          !pictured.add((i.week, i.songId, i.albumId))) {
        i.media = PostMedia.none;
      }
    }
    return items;
  }

  static List<SocialItem> _newestWeeksFirst(List<SocialItem> feed) {
    final order = List.generate(feed.length, (i) => i)
      ..sort((a, b) {
        final d = feed[b].week.compareTo(feed[a].week);
        return d != 0 ? d : a.compareTo(b);
      });
    return [for (final i in order) feed[i]];
  }

  final SocialNetwork network;
  final bool canPost;

  /// Replies to comments left this week (docs K238, K252).
  final int repliesLeft;
  final double followers;

  /// The blue tick: famous or big enough (as on the streaming profiles).
  final bool verified;
  final int postsLeft;

  /// The rival in the player's beef now (-1: none; docs K234).
  final int beefRivalId;
  final String beefRivalName;

  /// Something unreleased to tease.
  final bool hasTeaser;

  /// Released songs to promote, newest first: (id, title).
  final List<(int, String)> songs;

  /// Newest first.
  final List<SocialItemView> items;
}

/// Units of [a]'s songs that are on no album, in region [r] (docs K99).
double _singleUnitsOffAlbums(World w, Artist a, int r) {
  final c = w.config;
  final streams = Charts.songRules(ChartMarket.global, w.week).albumUsesUnits;
  var t = 0.0;
  void add(Song s) {
    if (s.primaryArtistId != a.id || s.albumId >= 0 || s.releasedWeek < 0) {
      return;
    }
    if (streams) t += w.songLifetimeStreams(s, r) / c.streamEquivalentAlbum;
    t += (w.songLifetimeDownloads(s, r) +
            s.lifetimePhysical * a.regionShare[r]) /
        c.trackEquivalentAlbum;
  }

  if (a.tier == ArtistTier.player) {
    for (final id in w.playerSongIds) {
      add(w.songs[id]);
    }
  } else {
    for (final s in w.songs) {
      add(s);
    }
  }
  return t;
}

/// A rival in the editor list (docs K213).
class RivalEditRow {
  RivalEditRow.of(Artist a)
      : artistId = a.id,
        name = a.name,
        genre = a.genre,
        fame = a.fame,
        isGroup = a.kind.isGroup,
        retired = a.isRetired;
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final bool isGroup;
  final bool retired;
}

/// One of the player's brand deals (docs K102).
class BrandDealView {
  BrandDealView.of(World w, Artist p, this.index, BrandDeal d)
      : brand = d.info,
        fit = Brands.fit(d.info, p),
        feeCents = d.feeCents,
        paidCents = d.paidCents,
        status = d.status,
        startWeek = d.startWeek,
        tasks = [
          for (final (t, due, done) in d.tasks)
            (task: t, dueWeek: due, doneWeek: done)
        ];

  /// Position in the deal list (for doing its tasks).
  final int index;
  final BrandInfo brand;
  final double fit;
  final int feeCents;
  final int paidCents;
  final DealStatus status;
  final int startWeek;
  final List<({DealTask task, int dueWeek, int doneWeek})> tasks;
}

/// A rival who could buy one of the player's songs (docs K143).
class SongBuyerView {
  SongBuyerView.of(World w, Artist rival, Song s)
      : artistId = rival.id,
        name = rival.name,
        genre = rival.genre,
        fame = rival.fame,
        feeCents = Songwriting.feeCents(rival, s),
        wants = Songwriting.wants(rival, s);
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final int feeCents;

  /// They would record it (the song is good enough for them).
  final bool wants;
}

/// A song the player wrote for someone else (docs K143).
class WrittenSongView {
  WrittenSongView.of(World w, Song s, {double? earnedCents})
      : songId = s.id,
        title = s.title,
        artistId = s.primaryArtistId,
        artistName = w.artists[s.primaryArtistId].name,
        albumId = coverAlbumOf(w, s),
        released = s.releasedWeek >= 0,
        releasedWeek = s.isSingle && s.singleWeek >= 0
            ? s.singleWeek
            : s.releasedWeek,
        peak = s.statsOrNull(Charts.usSongs)?.peak ?? 0,
        streams = w.songLifetimeStreams(s),
        earnedCents = earnedCents ?? s.writerCents;
  final int songId;
  final String title;
  final int artistId;
  final String artistName;
  final int albumId;
  final bool released;

  /// The week it came out (-1: not yet).
  final int releasedWeek;

  /// Best place on the US songs chart (0: never charted).
  final int peak;
  final double streams;
  final double earnedCents;
}

/// What one song has earned the player (docs K220): a record of their
/// own (their share of streams and sales, less its campaign) or one they
/// wrote for someone else (the writer's royalty).
class SongEarningView {
  SongEarningView({
    required this.songId,
    required this.title,
    required this.albumId,
    required this.year,
    required this.earnedCents,
    required this.costCents,
    required this.streams,
    this.forArtist,
  });

  final int songId;
  final String title;
  final int albumId;
  final int year;
  final double earnedCents;

  /// What its campaign cost (own records only).
  final int costCents;
  final double streams;

  /// Who recorded it, for a song written for someone else.
  final String? forArtist;
}

/// The player's documentaries and what making one takes (docs K172).
class DocumentaryView {
  DocumentaryView.of(World w, Artist a)
      : block = Documentaries.block(w, a),
        originalFeeCents = Documentaries.originalFeeCents(a),
        docs = [
          for (final d in w.documentaries.reversed)
            (
              title: d.title,
              deal: d.deal,
              premiereWeek: d.premiereWeek,
              premiered: d.premiered,
              feeCents: d.feeCents
            )
        ];

  /// What stops a new one (null: nothing).
  final DocBlock? block;
  final int originalFeeCents;
  final List<
      ({
        String title,
        DocDeal deal,
        int premiereWeek,
        bool premiered,
        int feeCents
      })> docs;
}

/// The Artist Pick on the player's profile and what could be pinned
/// (docs K185).
class PickView {
  PickView.of(World w, Artist a)
      : open = ArtistPicks.open(w),
        countdownOpen = ArtistPicks.countdownOpen(w),
        current = ArtistPicks.current(w),
        songs = [
          for (final id in w.playerSongIds.reversed)
            if (w.songs[id].releasedWeek >= 0 &&
                w.songs[id].status != SongStatus.scrapped)
              (id: id, title: w.songs[id].title)
        ].take(15).toList(),
        albums = [
          for (final al in w.albums.reversed)
            if (al.artistId == a.id) (id: al.id, title: al.title)
        ],
        upcoming = ArtistPicks.countdownOpen(w)
            ? [
                for (final sr in a.scheduled)
                  if (sr.isAlbum && sr.announcedBy(w.week))
                    (id: sr.id, title: sr.title)
              ]
            : const [],
        title = _title(w, a, ArtistPicks.current(w)),
        freshness = switch (ArtistPicks.current(w)) {
          final p? => math.exp(-(w.week - p.sinceWeek) / ArtistPicks.fadeWeeks),
          null => 0.0,
        };

  final bool open;
  final bool countdownOpen;
  final ArtistPick? current;

  /// The pinned release's title ('' for none).
  final String title;

  /// How much of a fresh pick's lift it still has (1: just pinned).
  final double freshness;
  final List<({int id, String title})> songs;
  final List<({int id, String title})> albums;
  final List<({int id, String title})> upcoming;

  static String _title(World w, Artist a, ArtistPick? p) => switch (p) {
        null => '',
        ArtistPick(kind: PickKind.song, :final id) => w.songs[id].title,
        ArtistPick(kind: PickKind.album, :final id) => w.albums[id].title,
        ArtistPick(kind: PickKind.upcoming, :final id) =>
          a.scheduled.where((sr) => sr.id == id).firstOrNull?.title ?? '',
      };
}

/// An artist's This Is list on the streaming app (docs K189).
class ThisIsView {
  ThisIsView.of(World w, Artist a, this.listeners)
      : open = ThisIs.open(w),
        made = a.tier == ArtistTier.player
            ? w.thisIsWeek >= 0
            : ThisIs.qualifies(w, a, listeners),
        madeWeek = a.tier == ArtistTier.player ? w.thisIsWeek : -1,
        eligible = ThisIs.eligible(w, a).length,
        artistName = a.name,
        isPlayer = a.tier == ArtistTier.player {
    if (!made) return;
    final list = ThisIs.songs(w, a);
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      songs.add(SongView.of(w, s));
      if (ThisIs.isNew(w, s)) newIds.add(s.id);
      if (isPlayer) lifts.add(ThisIs.liftAt(w, s, i));
    }
  }

  /// The app has these lists yet.
  final bool open;
  final bool made;

  /// When the editors made the player's list (-1 for others).
  final int madeWeek;
  final String artistName;
  final bool isPlayer;

  /// Songs the list could take, against [ThisIs.minSongs].
  final int eligible;

  /// Monthly listeners, against [ThisIs.minListeners].
  final double listeners;
  final List<SongView> songs = [];

  /// Songs on it because they are new.
  final Set<int> newIds = {};

  /// The listening each of the player's songs gets from being on it.
  final List<double> lifts = [];
}

/// Why the listening data likes a track for the next single (docs K182).
enum SinglePickReason {
  /// The album's most played track that is not a single yet.
  mostPlayed,

  /// Few listeners skip it.
  fewSkips,

  /// Made for the radio.
  radio,

  /// Could take off on the short-video app (2019+).
  shortVideo,

  /// More people find it every week (word of mouth).
  growing,
}

/// An album track the listening data suggests as the next single.
class SinglePickView {
  SinglePickView(
      {required this.songId,
      required this.title,
      required this.share,
      required this.skipRate,
      required this.score,
      required this.reasons});
  final int songId;
  final String title;

  /// Its share of the album's non-single listening this week.
  final double share;
  final double skipRate;
  final double score;
  final List<SinglePickReason> reasons;
}

/// Streamify Sessions (docs K178): the invitation, the player's songs
/// that could be recorded, the hits that could be covered and the
/// sessions so far.
class SessionsView {
  SessionsView.of(World w, Artist a, this.listeners)
      : block = StreamifySessions.block(w, listeners),
        nextWeek = w.streamifySessions.isEmpty
            ? -1
            : w.streamifySessions.last.week + StreamifySessions.gapWeeks,
        songs = [
          for (final id in w.playerSongIds.reversed)
            if (StreamifySessions.canRecord(w.songs[id], a))
              (id: id, title: w.songs[id].title, artist: a.name, listeners: 0.0)
        ],
        covers = _covers(w, a),
        sessions = [
          for (final s in w.streamifySessions.reversed)
            (
              week: s.week,
              title: w.songs[s.songId].title,
              coverTitle: w.songs[s.coverSongId].title,
              coverArtist: w.artists[w.songs[s.coverSongId].primaryArtistId]
                  .name
            )
        ];

  /// The player's monthly listeners on the app now.
  final double listeners;
  final SessionBlock? block;

  /// When the next invitation comes after the last session (-1: none yet).
  final int nextWeek;
  final List<({int id, String title, String artist, double listeners})>
      songs;

  /// The biggest songs of others this week, with the listeners a cover
  /// would win.
  final List<({int id, String title, String artist, double listeners})>
      covers;
  final List<
      ({int week, String title, String coverTitle, String coverArtist})>
      sessions;

  static List<({int id, String title, String artist, double listeners})>
      _covers(World w, Artist a) {
    final hits = [
      for (final id in w.activeSongIds)
        if (StreamifySessions.canCover(w.songs[id], a)) w.songs[id]
    ]..sort((x, y) => y.weekStreams.compareTo(x.weekStreams));
    return [
      for (final s in hits.take(15))
        (
          id: s.id,
          title: s.title,
          artist: w.artists[s.primaryArtistId].name,
          listeners: StreamifySessions.coverListeners(w, a, s)
        )
    ];
  }
}

/// The awards season and the player's campaign (docs K171).
class FycView {
  FycView.of(World w)
      : phase = AwardCampaigns.phase(w).$2,
        year = AwardCampaigns.phase(w).$1,
        nomination =
            AwardCampaigns.current(w, AwardCampaigns.phase(w).$1)?.nomination,
        vote = AwardCampaigns.current(w, AwardCampaigns.phase(w).$1)?.vote;
  final FycPhase phase;

  /// The show it is for (0: closed).
  final int year;
  final FycTier? nomination;
  final FycTier? vote;

  /// What is running for the current part of the season.
  FycTier? get running => phase == FycPhase.nominations
      ? nomination
      : phase == FycPhase.voting
          ? vote
          : null;
}

/// The player's beefs (docs K229).
class BeefsView {
  BeefsView.of(World w, Artist p)
      : active = Beefs.active(w) == null
            ? null
            : BeefView.of(w, Beefs.active(w)!),
        past = [
          for (final b in w.beefs.reversed)
            if (!b.active) BeefView.of(w, b)
        ],
        canPost = Social.canPostIn(GameTime.yearOf(w.week)),
        postsLeft = Social.postsPerWeek - w.social.postsIn(w.week);
  final BeefView? active;
  final List<BeefView> past;
  final bool canPost;
  final int postsLeft;
}

/// One beef: the rival, how hot it is, whose side the public is on and
/// every diss.
class BeefView {
  BeefView.of(World w, Beef b)
      : rivalId = b.rivalId,
        rivalName = w.artists[b.rivalId].name,
        rivalFame = w.artists[b.rivalId].fame,
        startWeek = b.startWeek,
        playerStarted = b.playerStarted,
        heat = b.heat,
        opinion = b.opinion,
        endWeek = b.endWeek,
        end = b.end,
        moves = [
          for (final m in b.moves.reversed)
            BeefMoveView(
              week: m.week,
              byPlayer: m.byPlayer,
              kind: m.kind,
              songId: m.songId,
              title: m.songId >= 0 ? w.songs[m.songId].title : '',
            )
        ];
  final int rivalId;
  final String rivalName;
  final double rivalFame;
  final int startWeek;
  final bool playerStarted;
  final double heat;
  final double opinion;
  final int endWeek;
  final BeefEnd? end;

  /// Newest first.
  final List<BeefMoveView> moves;
}

class BeefMoveView {
  const BeefMoveView(
      {required this.week,
      required this.byPlayer,
      required this.kind,
      required this.songId,
      required this.title});
  final int week;
  final bool byPlayer;
  final BeefMoveKind kind;
  final int songId;
  final String title;
}

/// A rival the player could go at, and how it would look.
class DissTargetView {
  const DissTargetView(
      {required this.artistId,
      required this.name,
      required this.fame,
      required this.punch,
      required this.block});
  final int artistId;
  final String name;
  final double fame;

  /// How the public takes it: below 0 bullying, above 0 brave.
  final double punch;

  /// What stops a diss now (null: nothing; noPost is about posts only).
  final DissBlock? block;

  /// The biggest active rivals and those closest to the player's fame.
  static List<DissTargetView> list(World w, Artist p) {
    final rivals = [
      for (final id in w.activeArtistIds)
        if (w.artists[id] case final a
            when a.tier != ArtistTier.player && !a.isRetired && a.fame > 0.02)
          a
    ];
    final big = (List.of(rivals)..sort((a, b) => b.fame.compareTo(a.fame)))
        .take(8);
    final near = (List.of(rivals)
          ..sort((a, b) =>
              (a.fame - p.fame).abs().compareTo((b.fame - p.fame).abs())))
        .take(8);
    final seen = <int>{};
    return [
      for (final a in [...big, ...near])
        if (seen.add(a.id))
          DissTargetView(
              artistId: a.id,
              name: a.name,
              fame: a.fame,
              punch: Beefs.punch(p, a),
              block: Beefs.block(w, p, a.id))
    ]..sort((a, b) => b.fame.compareTo(a.fame));
  }
}

/// The player's award submissions for the next show (docs K227).
class AwardSubmissionsView {
  AwardSubmissionsView.of(World w)
      : year = Awards.showYearOf(w.week),
        deadlineWeek = w.week +
            Awards.nominationsWeekOfYear -
            GameTime.weekOfYear(w.week) -
            1,
        byLabel = w.awardSubmissions?.year != Awards.showYearOf(w.week),
        playerGenre = w.player?.genre ?? -1,
        songs = [],
        albums = [],
        newArtistEligible = Awards.newArtistEligible(w, Awards.showYearOf(w.week)),
        submitted = Awards.submissionsFor(w, Awards.showYearOf(w.week)) {
    final outlook = Awards.outlook(w, year);
    for (final s in Awards.eligibleSongs(w, year)) {
      songs.add(AwardSongEntry(
        songId: s.id,
        title: s.title,
        record: outlook[AwardSubmission(AwardCategory.record, s.id)],
        song: outlook[AwardSubmission(AwardCategory.song, s.id)],
        genres: [
          for (final g in Awards.songGenreOptions(w, s))
            (
              g,
              outlook[AwardSubmission(AwardCategory.genreSong, s.id, genre: g)]
            )
        ],
      ));
    }
    for (final al in Awards.eligibleAlbums(w, year)) {
      albums.add(AwardAlbumEntry(
        albumId: al.id,
        title: al.title,
        album: Awards.albumOfYearEligible(w, al)
            ? outlook[AwardSubmission(AwardCategory.album, al.id)]
            : null,
        genres: [
          for (final g in Awards.genreOptions(w, al))
            (
              g,
              Awards.genreFit(w, al, g),
              outlook[AwardSubmission(AwardCategory.genreAlbum, al.id,
                  genre: g)]
            )
        ],
      ));
    }
    newArtist = outlook[
        AwardSubmission(AwardCategory.newArtist, w.playerArtistId)];
  }

  /// The show it is for and the last week to submit.
  final int year;
  final int deadlineWeek;

  /// Nothing submitted yet: the label submits [submitted] for the player.
  final bool byLabel;
  final int playerGenre;
  final List<AwardSongEntry> songs;
  final List<AwardAlbumEntry> albums;
  final bool newArtistEligible;

  /// How Best New Artist looks (null: not eligible).
  late final AwardOutlook? newArtist;
  final AwardSubmissions submitted;

  bool get isEmpty => songs.isEmpty && albums.isEmpty && !newArtistEligible;
}

/// A song the player can put up for Record or Song of the Year, and how
/// it looks there (null: cannot).
class AwardSongEntry {
  const AwardSongEntry(
      {required this.songId,
      required this.title,
      required this.record,
      required this.song,
      this.genres = const []});
  final int songId;
  final String title;
  final AwardOutlook? record;
  final AwardOutlook? song;

  /// Genre song awards it can go up for: (genre, outlook) (docs K250).
  final List<(int, AwardOutlook?)> genres;
}

/// An album the player can put up for Album of the Year ([album], null:
/// cannot) and genre awards: (genre, fit 0..1, outlook).
class AwardAlbumEntry {
  const AwardAlbumEntry(
      {required this.albumId,
      required this.title,
      required this.album,
      required this.genres});
  final int albumId;
  final String title;
  final AwardOutlook? album;
  final List<(int, double, AwardOutlook?)> genres;
}

/// The player's own label, or what founding one takes (docs K169).
class ImprintView {
  ImprintView.of(World w, Artist a)
      : founded = w.imprint != null,
        canFound = Imprints.canFound(w, a),
        name = w.imprint?.name ?? '',
        foundedWeek = w.imprint?.foundedWeek ?? -1,
        roster = [
          for (final s in w.imprint?.roster ?? const <Signing>[])
            SigneeView.of(w, s)
        ];
  final bool founded;
  final bool canFound;
  final String name;
  final int foundedWeek;
  final List<SigneeView> roster;
  double get earnedCents => roster.fold(0.0, (t, s) => t + s.earnedCents);
}

/// An artist on the player's label.
class SigneeView {
  SigneeView.of(World w, Signing s)
      : artistId = s.artistId,
        name = w.artists[s.artistId].name,
        genre = w.artists[s.artistId].genre,
        fame = w.artists[s.artistId].fame,
        fans = w.artists[s.artistId].coreFans,
        signedWeek = s.signedWeek,
        advanceCents = s.advanceCents,
        earnedCents = s.earnedCents,
        retired = w.artists[s.artistId].isRetired,
        bestPeak = Imprints.bestPeak(w, s, Charts.usSongs),
        pushTitle = Imprints.pushable(w, s)?.title,
        pushCostCents = Imprints.pushCostCents(w.artists[s.artistId]);
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final double fans;
  final int signedWeek;
  final int advanceCents;
  final double earnedCents;
  final bool retired;

  /// Best US songs chart place since signing (0: none).
  final int bestPeak;

  /// The single the label can push now (null: none) and what it costs
  /// (docs K170).
  final String? pushTitle;
  final int pushCostCents;
}

/// A newcomer the player's label could sign.
class SigneeCandidateView {
  SigneeCandidateView.of(World w, Artist r)
      : artistId = r.id,
        name = r.name,
        genre = r.genre,
        fame = r.fame,
        fans = r.coreFans,
        debutYear = GameTime.yearOf(r.debutWeek),
        advanceCents = Imprints.advanceCents(r);
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final double fans;
  final int debutYear;
  final int advanceCents;
}

/// The player's paid fan club, or what opening one takes (docs K164).
class FanClubView {
  FanClubView.of(World w, Artist a)
      : open = w.fanClub != null,
        canOpen = FanClubs.can(w, a),
        coreFans = a.coreFans,
        price = w.fanClub?.price ?? ClubPrice.mid,
        members = w.fanClub?.members ?? 0,
        target = w.fanClub == null ? 0 : FanClubs.target(w, a, w.fanClub!),
        weekCents = (w.fanClub?.members ?? 0) *
            (w.fanClub?.price.monthCents ?? 0) *
            12 /
            GameTime.weeksPerYear,
        revenueCents = w.fanClub?.revenueCents ?? 0,
        activity = FanClubs.activity(w, a),
        estimates = {
          for (final p in ClubPrice.values)
            p: FanClubs.target(
                w, a, FanClub(openWeek: w.week, price: p)),
        };
  final bool open;
  final bool canOpen;
  final double coreFans;
  final ClubPrice price;
  final double members;

  /// Members it is heading to, and what it pays a week now.
  final double target;
  final double weekCents;
  final double revenueCents;

  /// How active the artist looks to members (1: a recent release).
  final double activity;

  /// Members each price would hold now.
  final Map<ClubPrice, double> estimates;
}

/// A released song that could go on a greatest hits album (docs K161).
class HitCandidateView {
  HitCandidateView.of(World w, Song s)
      : songId = s.id,
        title = s.title,
        albumId = coverAlbumOf(w, s),
        year = GameTime.yearOf(s.releasedWeek),
        peak = Compilations.bestPeak(s),
        streams = w.songLifetimeStreams(s),
        weight = Compilations.hitWeight(s);
  final int songId;
  final String title;
  final int albumId;
  final int year;

  /// Best place on any songs chart (0: never charted).
  final int peak;
  final double streams;

  /// What it adds to the album's pull.
  final double weight;
}

/// The player's own playlist on the streaming app (docs K159).
class OwnPlaylistView {
  OwnPlaylistView.of(World w, OwnPlaylist p)
      : name = p.name,
        createdWeek = p.createdWeek,
        followers = p.followers,
        target = w.player == null ? 0 : OwnPlaylists.target(w, w.player!, p),
        appeal = OwnPlaylists.appeal(w, p),
        ownShare = OwnPlaylists.ownShare(w, p, w.playerArtistId),
        freshness = OwnPlaylists.freshness(w, p),
        lift = OwnPlaylists.lift(p),
        tracks = [
          for (final id in p.songIds) PlaylistTrackView.of(w, w.songs[id])
        ];
  final String name;
  final int createdWeek;
  final double followers;

  /// Followers it is heading to now.
  final double target;

  /// What makes people follow it (0..1), the share of the player's own
  /// songs on it, how fresh it is (1: changed recently) and the lift
  /// its songs get each week.
  final double appeal;
  final double ownShare;
  final double freshness;
  final double lift;
  final List<PlaylistTrackView> tracks;

  bool get tooShort => tracks.length < OwnPlaylists.minSongs;
  bool get tooMuchSelf => ownShare > OwnPlaylists.ownFree;
}

/// A song on (or for) the player's playlist.
class PlaylistTrackView {
  PlaylistTrackView.of(World w, Song s)
      : songId = s.id,
        title = s.title,
        artistId = s.primaryArtistId,
        artistName = w.artists[s.primaryArtistId].name,
        albumId = coverAlbumOf(w, s),
        isPlayer = s.primaryArtistId == w.playerArtistId,
        weekStreams = s.releasedWeek < 0
            ? 0
            : w.songWeekStreamsIn(s, ChartMarket.global),
        fresh = w.week - s.releasedWeek <= 12,
        onPlaylist = w.ownPlaylist?.songIds.contains(s.id) ?? false;
  final int songId;
  final String title;
  final int artistId;
  final String artistName;
  final int albumId;
  final bool isPlayer;
  final double weekStreams;

  /// Out in the last 12 weeks (new songs draw followers).
  final bool fresh;
  final bool onPlaylist;
}

/// A group member and their solo records (docs K158).
/// The player's group's line split, morale bonus and contracts (docs
/// K193, K195).
class LineupView {
  LineupView.of(World w, Artist a)
      : split = Lineups.splitOf(a),
        center = Lineups.center(a),
        lift = Lineups.lineLift(w, a),
        cheerCents = Lineups.cheerCostCents(a),
        canCheer = Lineups.canCheer(w, a),
        nextCheerWeek = a.cheerWeek + Lineups.cheerEveryWeeks,
        renewalWeek = MemberMorale.nextRenewal(w, a),
        atRisk = [for (final i in MemberMorale.atRisk(a)) a.members[i]];
  final LineSplit split;

  /// The member the songs are built around, and what the split adds to
  /// the songs' listening.
  final int center;
  final double lift;

  /// A morale bonus: its cost, and whether one can be paid now (else
  /// from when).
  final int cheerCents;
  final bool canCheer;
  final int nextCheerWeek;

  /// When the contracts come up, and who would not sign again now.
  final int renewalWeek;
  final List<String> atRisk;
}

/// The reunion with the group the player left (docs K194).
class ReunionView {
  ReunionView.of(World w, Artist g)
      : groupId = g.id,
        groupName = g.name,
        block = Reunions.block(w),
        active = Reunions.active(w),
        openWeek = Reunions.openWeek(w),
        endWeek = w.reunionEndWeek,
        yearsApart = (w.week - w.playerSinceWeek) / 52,
        audience = Reunions.audience(w),
        done = w.reunionStartWeek >= 0;
  final int groupId;
  final String groupName;

  /// Why it cannot start now (null: it can).
  final ReunionBlock? block;
  final bool active;

  /// From when it can start, and when the running one ends.
  final int openWeek;
  final int endWeek;
  final double yearsApart;

  /// The group's audience with the reunion's nostalgia.
  final ({double fans, double casual, double fame}) audience;

  /// There has been a reunion before.
  final bool done;
}

/// What going solo as a member would bring (docs K191).
class GoSoloView {
  const GoSoloView({
    required this.name,
    required this.block,
    required this.fans,
    required this.casual,
    required this.fame,
    required this.groupFans,
    required this.importance,
    required this.ace,
    required this.groupBreaksUp,
    required this.hiatus,
    required this.scheduled,
    required this.fanClub,
  });
  final String name;

  /// Why it cannot happen now (null: it can).
  final GoSoloBlock? block;

  /// The member's audience after the split.
  final double fans, casual, fame;

  /// The group's fans after the split, and whether it breaks up.
  final double groupFans;
  final bool groupBreaksUp;

  /// The group ends because its star leaves, not for want of members.
  final bool hiatus;

  /// How much the member matters to the fans (1: average) and whether
  /// they are the group's ace (docs K192).
  final double importance;
  final bool ace;

  /// Scheduled releases that are called off, and whether a fan club closes.
  final int scheduled;
  final bool fanClub;
}

class MemberView {
  MemberView.of(World w, Artist group, this.index)
      : name = group.members[index],
        roles = index < group.memberRoles.length
            ? Lineups.rolesOf(group.memberRoles[index])
            : const [],
        popularity =
            index < group.memberPop.length ? group.memberPop[index] : 0,
        share = index < group.memberPop.length
            ? Lineups.share(group, index)
            : 0,
        focused = group.focusMember == index,
        morale = index < group.memberMorale.length
            ? group.memberMorale[index]
            : Lineups.moraleRest,
        center = group.memberPop.isNotEmpty && Lineups.center(group) == index,
        focusWeeks =
            group.focusMember == index ? w.week - group.focusSinceWeek : 0,
        artistId = Credits.memberIdOf(group, index),
        fans = _memberOrNull(w, group, index)?.coreFans ?? 0,
        fame = _memberOrNull(w, group, index)?.fame ?? 0,
        songs = [
          for (final id in w.managedSongIds.reversed)
            if (w.songs[id].primaryArtistId ==
                Credits.memberIdOf(group, index))
              WrittenSongView.of(w, w.songs[id],
                  earnedCents: w.songs[id].revenueCents),
        ],
        albums = [
          for (final al in w.albums.reversed)
            if (al.artistId == Credits.memberIdOf(group, index))
              (
                id: al.id,
                title: al.title,
                type: al.type,
                firstWeek: al.firstWeekUnits,
                peak: al.statsOrNull(Charts.usAlbums)?.peak ?? 0
              )
        ];
  final int index;
  final String name;

  /// Their roles, popularity (0–100) and share of the group's, and
  /// whether the label pushes them, for how many weeks (docs K192).
  final List<MemberRole> roles;
  final double popularity;
  final double share;
  final bool focused;
  final int focusWeeks;

  /// Their morale (0–100; docs K195) and whether the songs are built
  /// around them (docs K193).
  final double morale;
  final bool center;

  /// Their solo name's artist id (-1: no solo record yet).
  final int artistId;
  final double fans;
  final double fame;
  final List<WrittenSongView> songs;

  /// Their solo EPs and albums (docs K173), newest first: first week
  /// units and best US albums chart place (0: never charted).
  final List<
      ({int id, String title, AlbumType type, double firstWeek, int peak})>
      albums;

  static Artist? _memberOrNull(World w, Artist group, int i) {
    final id = Credits.memberIdOf(group, i);
    return id < 0 ? null : w.artists[id];
  }
}

/// A finished tour a live album can come from (docs K146).
class LiveTourView {
  LiveTourView.of(TourRecord t)
      : startWeek = t.startWeek,
        endWeek = t.endWeek,
        name = t.name,
        shows = t.shows,
        tickets = t.tickets;

  /// Identifies the tour.
  final int startWeek;
  final int endWeek;
  final String name;
  final int shows;
  final double tickets;
}

/// A rival who would make a joint album with the player (docs K150).
class JointPartnerView {
  JointPartnerView.of(Artist rival)
      : artistId = rival.id,
        name = rival.name,
        genre = rival.genre,
        fame = rival.fame,
        feeCents = JointAlbums.feeCents(rival);
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final int feeCents;
}

/// A fund's offer for the player's catalog (docs K153).
class CatalogOfferView {
  CatalogOfferView.of(World w, Artist a)
      : open = GameTime.yearOf(w.week) >= CatalogSale.fromYear,
        songs = CatalogSale.songs(w, a).length,
        yearCents = CatalogSale.yearCents(w, a),
        multiple = CatalogSale.multiple(GameTime.yearOf(w.week)),
        offerCents = CatalogSale.offerCents(w, a);

  /// Funds buy catalogs this year.
  final bool open;

  /// Songs three years and older the player still owns a part of.
  final int songs;

  /// What they earn the player in a year at last week's pace.
  final double yearCents;

  /// Years of earnings funds pay now.
  final double multiple;

  /// The offer (0: none).
  final int offerCents;
}

/// The independent player's distribution (docs K157): the current one and
/// what each would mean.
class DistributionView {
  DistributionView.of(World w, Artist a)
      : independent = a.label == Label.independent,
        current = a.distributor,
        available = {
          for (final d in Distributor.values)
            if (Distribution.can(w, a, d)) d
        },
        dealAdvanceCents = Distribution.advanceCents(a),
        unrecoupedCents = a.unrecoupedCents,
        year = GameTime.yearOf(w.week);
  final bool independent;
  final Distributor current;
  final Set<Distributor> available;
  final int dealAdvanceCents;
  final int unrecoupedCents;
  final int year;
}
