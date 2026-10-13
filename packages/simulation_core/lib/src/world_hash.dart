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
    addDouble(a.anticipation);
    addAll(a.reg);
    addAll(a.regionShare);
    addInt(a.moneyCents);
    addInt(a.job.index);
    addInt(a.restWeek);
    addInt(a.skillPoints);
    addInt(a.label.index);
    addInt(a.contractAlbumsLeft);
    for (final sr in a.scheduled) {
      addInt(sr.releaseWeek);
      addInt(sr.announceWeek);
      addDouble(sr.buzz);
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
    addDouble(s.dormantRate);
    addDouble(s.lifetimePhysical);
    for (final g in s.genres) {
      addInt(g);
    }
    addInt(s.campaign.index);
    addInt(s.playlistAdd.index);
    addDouble(s.playlistBoost);
    addCharts(s);
  }
  addInt(w.albums.length);
  for (final al in w.albums) {
    addAll(al.reg);
    addInt(al.campaign.index);
    addDouble(al.campaignReturnCents);
    addCharts(al);
  }
  for (final chart in w.charts) {
    for (final e in chart) {
      addInt(e.entityId);
    }
  }
  return h;
}
