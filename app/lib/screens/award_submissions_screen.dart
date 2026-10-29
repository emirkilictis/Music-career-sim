import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

/// The player's award submissions (docs K227): which songs go up for
/// Record and Song of the Year, which albums for Album of the Year and
/// which genre awards, and Best New Artist, each with how the voters see
/// it now. Pops with true when submitted.
class AwardSubmissionsScreen extends StatefulWidget {
  const AwardSubmissionsScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<AwardSubmissionsScreen> createState() => _AwardSubmissionsScreenState();
}

class _AwardSubmissionsScreenState extends State<AwardSubmissionsScreen> {
  AwardSubmissionsView? _v;
  bool _loaded = false;
  final _picked = <AwardSubmission>{};
  bool _newArtist = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.awardSubmissions()).then((v) {
      if (!mounted) return;
      setState(() {
        _v = v;
        _loaded = true;
        if (v != null) {
          _picked.addAll(v.submitted.entries);
          _newArtist = v.submitted.newArtist;
        }
      });
    });
  }

  int _count(AwardCategory c, {int genre = -1}) => _picked
      .where((e) =>
          e.category == c && (!c.isGenre || e.genre == genre))
      .length;

  int get _genres => {
        for (final e in _picked)
          if (e.category.isGenre) e.genre
      }.length;

  bool _canAdd(AwardSubmission e) {
    if (_count(e.category, genre: e.genre) >= Awards.maxEntries) return false;
    if (e.category.isGenre &&
        !_picked.any((x) => x.category.isGenre && x.genre == e.genre) &&
        _genres >= Awards.maxGenres) {
      return false;
    }
    return true;
  }

  void _toggle(AwardSubmission e) => setState(() {
        if (!_picked.remove(e) && _canAdd(e)) _picked.add(e);
      });

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await widget.state
          .act(Cmd.submitForAwards(_picked.toList(), _newArtist));
      if (!mounted) return;
      showInfo(context, l.subsDone, icon: Icons.how_to_vote_rounded);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = _v;
    return Scaffold(
      appBar: AppBar(title: Text(l.subsTitle)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : v == null
              ? Center(child: EmptyNote(l.errorSubmissionsClosed))
              : v.isEmpty
                  ? Center(child: EmptyNote(l.subsEmpty))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Text(l.subsCardHint(v.year, fmt.week(v.deadlineWeek)),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(l.subsIntro,
                            style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(l.subsLimit(Awards.maxEntries, Awards.maxGenres),
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                        for (final c in const [
                          AwardCategory.record,
                          AwardCategory.song,
                          AwardCategory.album,
                        ])
                          if (_count(c) > 1)
                            _Warn(l.subsSplit(
                                fmt.awardCategory(c, -1), _count(c))),
                        if (v.songs.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Section(
                            title: l.subsSongs,
                            icon: Icons.music_note_rounded,
                            child: Column(children: [
                              for (final s in v.songs)
                                _Entry(
                                  cover: CoverArt(
                                      seed: songCoverSeed(s.songId, -1),
                                      songId: s.songId,
                                      size: 44),
                                  title: s.title,
                                  options: [
                                    if (s.record != null)
                                      _option(
                                          AwardSubmission(
                                              AwardCategory.record, s.songId),
                                          fmt.awardCategory(
                                              AwardCategory.record, -1),
                                          s.record!),
                                    if (s.song != null)
                                      _option(
                                          AwardSubmission(
                                              AwardCategory.song, s.songId),
                                          fmt.awardCategory(
                                              AwardCategory.song, -1),
                                          s.song!),
                                    // Genre song awards (docs K250).
                                    for (final (g, o) in s.genres)
                                      if (o != null)
                                        _option(
                                            AwardSubmission(
                                                AwardCategory.genreSong,
                                                s.songId,
                                                genre: g),
                                            l.subsGenreSongAward(fmt.genre(g)),
                                            o),
                                  ],
                                ),
                            ]),
                          ),
                        ],
                        if (v.albums.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Section(
                            title: l.subsAlbums,
                            icon: Icons.album_rounded,
                            child: Column(children: [
                              for (final a in v.albums)
                                _Entry(
                                  cover: CoverArt(
                                      seed: albumCoverSeed(a.albumId),
                                      albumId: a.albumId,
                                      size: 44),
                                  title: a.title,
                                  options: [
                                    if (a.album != null)
                                      _option(
                                          AwardSubmission(
                                              AwardCategory.album, a.albumId),
                                          fmt.awardCategory(
                                              AwardCategory.album, -1),
                                          a.album!),
                                    for (final (g, fit, o) in a.genres)
                                      if (o != null)
                                        _option(
                                            AwardSubmission(
                                                AwardCategory.genreAlbum,
                                                a.albumId,
                                                genre: g),
                                            l.subsGenreAward(fmt.genre(g),
                                                (fit * 100).round()),
                                            o),
                                  ],
                                ),
                            ]),
                          ),
                        ],
                        if (v.newArtist case final o?) ...[
                          const SizedBox(height: 12),
                          Section(
                            title: l.subsNewArtist,
                            icon: Icons.auto_awesome_rounded,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _newArtist,
                                    onChanged: (x) =>
                                        setState(() => _newArtist = x == true),
                                    title: Text(l.subsNewArtist),
                                    secondary: _OutlookTag(o),
                                  ),
                                  Text(l.subsNewArtistHint,
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12.5)),
                                ]),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: const Icon(Icons.how_to_vote_rounded),
                          label: Text(l.subsSave),
                        ),
                      ],
                    ),
    );
  }

  Widget _option(AwardSubmission e, String label, AwardOutlook o) {
    final on = _picked.contains(e);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: on,
      onChanged: on || _canAdd(e) ? (_) => _toggle(e) : null,
      title: Text(label),
      secondary: _OutlookTag(o),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

/// A record and the categories it can go up for.
class _Entry extends StatelessWidget {
  const _Entry(
      {required this.cover, required this.title, required this.options});
  final Widget cover;
  final String title;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            cover,
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15.5)),
            ),
          ]),
          ...options,
        ]),
      );
}

/// How the voters see an entry now.
class _OutlookTag extends StatelessWidget {
  const _OutlookTag(this.outlook);
  final AwardOutlook outlook;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (text, color) = switch (outlook) {
      AwardOutlook.strong => (l.subsStrong, AppColors.mint),
      AwardOutlook.borderline => (l.subsBorderline, AppColors.gold),
      AwardOutlook.longShot => (l.subsLongShot, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppShape.r(10)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Warn extends StatelessWidget {
  const _Warn(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Icon(Icons.call_split_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}
