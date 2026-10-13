import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/scope.dart';
import '../core/career_state.dart';
import '../screens/streamify/artist_page.dart';

/// "Artist page ›" under a rival's release: their platform page, once the
/// streaming platform exists (docs K38).
class ArtistLink extends StatelessWidget {
  const ArtistLink(
      {super.key,
      required this.artistId,
      required this.name,
      required this.state});
  final int artistId;
  final String name;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    if (GameTime.yearOf(state.week) <
        Charts.all[Charts.platformGlobal].startYear) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        // Detail screens are pushed without the career scope; give it here.
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Scope<CareerState>(
                value: state, child: ArtistPage(artistId: artistId)))),
        icon: const Icon(Icons.person_outline_rounded),
        label: Text('$name · ${context.l10n.openArtist}'),
      ),
    );
  }
}
