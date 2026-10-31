import 'dart:convert';

enum EraSound { familiar, reinvention, experimental }

enum SongTheme { love, heartbreak, nightlife, anger, confidence }

enum SongDirection { balanced, dance, ballad, vocal, experimental }

/// A creative brief is a snapshot: later eras never rewrite earlier records.
class EraBrief {
  const EraBrief(
      {this.name = '',
      this.sound = EraSound.familiar,
      this.theme = SongTheme.love,
      this.producerId = -1,
      this.cowriterId = -1});
  final String name;
  final EraSound sound;
  final SongTheme theme;
  final int producerId, cowriterId;
  Map<String, Object> toJson() => {
        'name': name,
        'sound': sound.index,
        'theme': theme.index,
        'producer': producerId,
        'writer': cowriterId
      };
  factory EraBrief.fromJson(Map<String, dynamic> j) => EraBrief(
      name: j['name'] as String? ?? '',
      sound: EraSound.values[j['sound'] as int? ?? 0],
      theme: SongTheme.values[j['theme'] as int? ?? 0],
      producerId: j['producer'] as int? ?? -1,
      cowriterId: j['writer'] as int? ?? -1);
}

class SongConcept {
  const SongConcept(this.brief, this.direction);
  final EraBrief brief;
  final SongDirection direction;
  Map<String, Object> toJson() =>
      {'brief': brief.toJson(), 'direction': direction.index};
  factory SongConcept.fromJson(Map<String, dynamic> j) => SongConcept(
      EraBrief.fromJson(j['brief'] as Map<String, dynamic>),
      SongDirection.values[j['direction'] as int]);
}

class CreativeStudio {
  EraBrief brief = const EraBrief();
  final Map<int, SongConcept> songs = {};
  final Map<int, EraBrief> albums = {};
  String encode() => jsonEncode({
        'brief': brief.toJson(),
        'songs': {for (final e in songs.entries) '${e.key}': e.value.toJson()},
        'albums': {for (final e in albums.entries) '${e.key}': e.value.toJson()}
      });
  static CreativeStudio decode(String? value) {
    final out = CreativeStudio();
    if (value == null || value.isEmpty) return out;
    final j = jsonDecode(value) as Map<String, dynamic>;
    out.brief = EraBrief.fromJson(j['brief'] as Map<String, dynamic>);
    for (final e in (j['songs'] as Map<String, dynamic>).entries) {
      out.songs[int.parse(e.key)] =
          SongConcept.fromJson(e.value as Map<String, dynamic>);
    }
    for (final e in (j['albums'] as Map<String, dynamic>).entries) {
      out.albums[int.parse(e.key)] =
          EraBrief.fromJson(e.value as Map<String, dynamic>);
    }
    return out;
  }
}
