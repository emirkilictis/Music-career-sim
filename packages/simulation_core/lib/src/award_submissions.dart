import 'dart:convert';

import 'awards.dart';

/// One record the player put up for one category (docs K227): a song for
/// Record or Song of the Year or a genre's song award, an album for Album
/// of the Year or a genre's album award ([genre], a [genreNames] index).
class AwardSubmission {
  const AwardSubmission(this.category, this.id, {this.genre = -1});
  final AwardCategory category;
  final int id;
  final int genre;

  @override
  bool operator ==(Object other) =>
      other is AwardSubmission &&
      other.category == category &&
      other.id == id &&
      other.genre == genre;

  @override
  int get hashCode => Object.hash(category, id, genre);
}

/// What the player submitted for one show (docs K227). Without one, the
/// label submits for them ([Awards.labelPicks]).
class AwardSubmissions {
  AwardSubmissions(this.year, this.entries, {this.newArtist = true});
  final int year;
  final List<AwardSubmission> entries;

  /// Up for Best New Artist this year; held back, the artist may still be
  /// up next year.
  final bool newArtist;

  bool has(AwardCategory c, int id, {int genre = -1}) =>
      entries.contains(AwardSubmission(c, id, genre: genre));

  /// Entries in [c] ([genre] for a genre award): more than one splits the
  /// voters.
  int count(AwardCategory c, {int genre = -1}) => entries
      .where((e) =>
          e.category == c && (!c.isGenre || e.genre == genre))
      .length;

  /// Genres entered, in either genre award (docs K250).
  Set<int> get genres => {
        for (final e in entries)
          if (e.category.isGenre) e.genre
      };

  String encode() => jsonEncode([
        year,
        newArtist ? 1 : 0,
        [
          for (final e in entries) [e.category.index, e.id, e.genre]
        ],
      ]);

  static AwardSubmissions? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final j = jsonDecode(s) as List;
    return AwardSubmissions(
      j[0] as int,
      [
        for (final e in j[2] as List)
          AwardSubmission(AwardCategory.values[(e as List)[0] as int],
              e[1] as int,
              genre: e[2] as int)
      ],
      newArtist: j[1] == 1,
    );
  }
}

/// How likely a submission looks to the voters now (docs K227).
enum AwardOutlook { strong, borderline, longShot }
