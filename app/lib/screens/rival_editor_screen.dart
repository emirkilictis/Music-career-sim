import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/format.dart';
import '../core/images.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/image_pickers.dart';

/// The rival editor (docs K213): the most famous rivals first, a search,
/// and each one's name and photos to change. The world is the player's:
/// real names, made-up names, their own photos, kept on the device.
class RivalEditorScreen extends StatefulWidget {
  const RivalEditorScreen({super.key});

  @override
  State<RivalEditorScreen> createState() => _RivalEditorScreenState();
}

class _RivalEditorScreenState extends State<RivalEditorScreen> {
  List<RivalEditRow>? _rows;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rows == null) _load();
  }

  Future<void> _load() async {
    final rows = await context.careerRead.read(Cmd.rivalsToEdit(_query));
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: Text(l.rivalEditorTitle)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l.rivalEditorSearch,
            ),
            onChanged: (v) {
              _query = v;
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l.rivalEditorHint,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        Expanded(
          child: rows == null
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? EmptyNote(l.rivalEditorEmpty)
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        return ListTile(
                          leading: ArtistAvatar(
                              name: r.name,
                              seed: r.artistId,
                              artistId: r.artistId),
                          title: Text(r.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              [
                                fmt.genre(r.genre),
                                if (r.retired) l.rivalRetired,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () async {
                            await showRivalEditor(context, r.artistId, r.name);
                            _load();
                          },
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

/// A rival's name and photos (docs K213), from the editor or their page.
/// The sheet opens above the career, so it takes the career along.
Future<void> showRivalEditor(BuildContext context, int artistId, String name) {
  final career = context.careerRead;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RivalSheet(career: career, artistId: artistId, name: name),
  );
}

class _RivalSheet extends StatefulWidget {
  const _RivalSheet(
      {required this.career, required this.artistId, required this.name});
  final CareerState career;
  final int artistId;
  final String name;

  @override
  State<_RivalSheet> createState() => _RivalSheetState();
}

class _RivalSheetState extends State<_RivalSheet> {
  late final _name = TextEditingController(text: widget.name);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.career.act(Cmd.renameArtist(widget.artistId, _name.text));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Rebuild when a photo changes.
    context.images;
    Widget photo(ArtistPhoto kind, String title) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ArtistAvatar(
              name: widget.name,
              seed: widget.artistId,
              artistId: widget.artistId,
              photo: kind,
              size: 48),
          title: Text(title),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () =>
              editImage(context, ImageStore.artistKey(widget.artistId, kind)),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.rivalEditTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                maxLength: CareerSetup.maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.rivalEditName),
                onSubmitted: (_) => _save(),
              ),
              photo(ArtistPhoto.general, l.photoGeneral),
              photo(ArtistPhoto.streamify, l.photoPlatform(platformName)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l.rivalEditSave),
              ),
            ]),
      ),
    );
  }
}
