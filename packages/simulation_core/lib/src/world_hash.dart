import 'dart:typed_data';

import 'config/charts.dart';
import 'model.dart';
import 'world.dart';

/// Stable hash of the simulation-relevant world state, used by determinism
/// tests ("same seed → same result", "continuous == save/load").
int worldHash(World w) {
  var h = 0xcbf29ce484222325;
  final bd = ByteData(8);
  void addInt(int v) {
    h ^= v;
    h *= 0x100000001b3;
  }

  void addDouble(double v) {
    bd.setFloat64(0, v);
    addInt(bd.getInt64(0));
  }

  void addAll(Float64List v) {
    for (final x in v) {
      addDouble(x);
    }
  }

  void addCharts(Charted e) {
    for (var c = 0; c < Charts.count; c++) {
      final st = e.statsOrNull(c);
      addInt(st?.peak ?? 0);
      addInt(st?.weeksOn ?? 0);
      addInt(st?.lastPos ?? 0);
    }
  }

  addInt(w.week);
  addInt(w.difficulty.index);
  for (final show in w.awardShows) {
    addInt(show.year);
    addInt(show.attendance.index);
    for (final race in show.races) {
      addInt(race.winner);
      for (final n in race.nominees) {
        addInt(n.id);
      }
    }
  }
  addAll(w.spaIndex);
  addAll(w.dpaIndex);
  addAll(w.retiredDormantAttention);
  addAll(w.emaAttention);
  addAll(w.chartCutoff);
  for (final a in w.artists) {
    addInt(a.id);
    addDouble(a.fame);
    addDouble(a.popularity);
    addDouble(a.coreFans);
    addDouble(a.casual);
    addDouble(a.devotion);
    addDouble(a.campaignFatigue);
    addInt(a.opportunity?.kind.index ?? -1);
    addInt(a.milestones.length);
    addDouble(a.tour?.tickets ?? -1);
    addInt(a.manager.index);
    addDouble(a.anticipation);
    addAll(a.reg);
    addAll(a.regionShare);
    addAll(a.marketBonus);
    addInt(a.distributor.index);
    addInt(a.managedBy);
    addInt(a.moneyCents);
    addInt(a.job.index);
    addInt(a.restWeek);
    addInt(a.skillPoints);
    addInt(a.label.index);
    addInt(a.contractAlbumsLeft);
    addInt(a.unrecoupedCents);
    addInt(a.surpriseWeek);
    for (final sr in a.scheduled) {
      addInt(sr.releaseWeek);
      addInt(sr.announceWeek);
      addDouble(sr.buzz);
      addDouble(sr.preSaves);
      addDouble(sr.preOrders);
      addInt(sr.exclusive ? 1 : 0);
    }
    addDouble(a.creativeEnergy);
    addInt(a.kind.index);
    addInt(a.members.length);
    addInt(a.lastAdWeek);
    addInt(a.adsWatchedThisWeek);
    for (final v in a.no1Singles) {
      addInt(v);
    }
  }
  addInt(w.songs.length);
  for (final s in w.songs) {
    addAll(s.reg);
    addDouble(s.videoPower);
    addDouble(s.campaignPower);
    addDouble(s.campaignReturnCents);
    addInt(s.radioPush.index);
    addDouble(s.dormantRate);
    addDouble(s.lifetimePhysical);
    for (final g in s.genres) {
      addInt(g);
    }
    addInt(s.campaign.index);
    addInt(s.playlistAdd.index);
    addDouble(s.playlistBoost);
    addInt(s.curatorWeek);
    addDouble(s.curatorReach);
    addDouble(s.versionBoost);
    addDouble(s.botTotal);
    addInt(s.botWeeksLeft);
    addDouble(s.botDelivered);
    addInt(s.botStatus.index);
    addInt(s.chartFilterUntil);
    addInt(s.autoplay.index);
    addInt(s.pitchWeek);
    addInt(s.creatorWeek);
    addInt(s.holiday ? 1 : 0);
    addInt(s.rerecordOf);
    addInt(s.replacedWeek);
    addInt(s.leakedWeek);
    addInt(s.writerId);
    addDouble(s.guestCents);
    addInt(s.liveOf);
    addInt(s.marqueeWeek);
    addInt(s.cloudWeek);
    addInt(s.snippetWeek);
    addInt(s.languages);
    addDouble(s.snippetScore);
    addInt(s.cloudOnly ? 1 : 0);
    addInt(s.showcaseWeek);
    addInt(s.soldTo);
    addDouble(s.writerCents);
    addDouble(s.masterShare ?? -1);
    addInt(s.radioFormat?.index ?? -1);
    addInt(s.creatorTier.index);
    addInt(s.creatorResult.index);
    for (final (v, wk) in s.versions) {
      addInt(v.index * 100000 + wk);
    }
    for (final (f, wk) in s.variants) {
      addInt(f.index * 100000 + wk);
    }
    addCharts(s);
  }
  addInt(w.channelVideos.length);
  for (final v in w.channelVideos) {
    addInt(v.kind.index * 100000 + v.week);
    addDouble(v.baseViews);
  }
  if (w.fycCampaign case final fyc?) {
    addInt(fyc.year);
    addInt(fyc.nomination?.index ?? -1);
    addInt(fyc.vote?.index ?? -1);
  }
  if (w.imprint case final label?) {
    for (final s in label.roster) {
      addInt(s.artistId);
      addDouble(s.earnedCents);
    }
  }
  if (w.fanClub case final club?) {
    addDouble(club.members);
    addInt(club.price.index);
  }
  final own = w.ownPlaylist;
  if (own != null) {
    addInt(own.songIds.length);
    for (final id in own.songIds) {
      addInt(id);
    }
    addDouble(own.followers);
    addInt(own.updatedWeek);
  }
  addInt(w.albums.length);
  for (final al in w.albums) {
    addAll(al.reg);
    addInt(al.hitIds.length);
    addInt(al.priceCutWeek);
    addInt(al.rolloutDone);
    addInt(al.campaign.index);
    addDouble(al.campaignReturnCents);
    addDouble(al.preOrders);
    addInt(al.exclusiveUntil);
    addDouble(al.masterShare ?? -1);
    addInt(al.bundle.index);
    addInt(al.liveTour);
    addInt(al.anniversaries);
    addInt(al.partnerId);
    addInt(al.visual ? 1 : 0);
    addDouble(al.bundleUnits);
    addCharts(al);
  }
  for (final chart in w.charts) {
    for (final e in chart) {
      addInt(e.entityId);
    }
  }
  return h;
}
