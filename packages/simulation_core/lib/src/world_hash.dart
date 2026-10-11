import 'dart:typed_data';

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

  addInt(w.week);
  for (final a in w.artists) {
    addInt(a.id);
    addDouble(a.fame);
    addDouble(a.popularity);
    addDouble(a.coreFans);
    addDouble(a.casual);
    addDouble(a.anticipation);
    addDouble(a.lifetimeStreams);
    addInt(a.moneyCents);
  }
  addInt(w.songs.length);
  for (final s in w.songs) {
    addDouble(s.lifetimeStreams);
    addInt(s.peakPos);
  }
  addInt(w.albums.length);
  for (final al in w.albums) {
    addDouble(al.lifetimeUnits);
    addInt(al.peakPos);
  }
  for (final e in w.songChart) {
    addInt(e.entityId);
  }
  return h;
}
