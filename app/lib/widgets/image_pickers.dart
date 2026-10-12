import 'dart:io';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/images.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'art.dart';

/// "Choose from photos / Use the generated one" for one image [key].
Future<void> editImage(BuildContext context, String key) async {
  final l = context.l10n;
  final store = context.imagesRead;
  final hasOwn = store.path(key) != null;
  final choice = await showModalBottomSheet<bool>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l.chooseFromPhotos),
          onTap: () => Navigator.pop(c, true),
        ),
        if (hasOwn)
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l.useGeneratedImage),
            onTap: () => Navigator.pop(c, false),
          ),
      ]),
    ),
  );
  if (choice == true) {
    await store.pickFor(key);
  } else if (choice == false) {
    store.remove(key);
  }
}

/// Cover row for release flows: the current cover and "Add / Change cover".
class CoverPickRow extends StatelessWidget {
  const CoverPickRow({super.key, required this.songId, this.albumId = -1});
  final int songId;
  final int albumId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final own = context.images.path(ImageStore.songKey(songId)) != null;
    return ListTile(
      leading: CoverArt(
          seed: songCoverSeed(songId, albumId),
          songId: songId,
          albumId: albumId,
          size: 52),
      title: Text(l.cover, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(own ? l.coverOwn : l.coverGenerated),
      trailing: TextButton(
        onPressed: () => editImage(context, ImageStore.songKey(songId)),
        child: Text(own ? l.changeCover : l.addCover),
      ),
    );
  }
}

/// Cover of a scheduled album, stored under [imageKey] until it comes out.
class PendingKeyCoverRow extends StatelessWidget {
  const PendingKeyCoverRow({super.key, required this.imageKey});
  final String imageKey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final own = context.images.path(imageKey) != null;
    return ListTile(
      leading: CoverArt(seed: imageKey.hashCode, imageKey: imageKey, size: 52),
      title: Text(l.cover, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(own ? l.coverOwn : l.coverGenerated),
      trailing: TextButton(
        onPressed: () => editImage(context, imageKey),
        child: Text(own ? l.changeCover : l.addCover),
      ),
    );
  }
}

/// Cover chosen before the album exists (album builder); saved on release.
class PendingCoverRow extends StatelessWidget {
  const PendingCoverRow(
      {super.key, required this.path, required this.onChanged});
  final String? path;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = path;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 52,
          child: p == null
              ? ColoredBox(
                  color: AppColors.surfaceHigh,
                  child: Icon(Icons.image_outlined, color: AppColors.textMuted))
              : Image.file(File(p), fit: BoxFit.cover),
        ),
      ),
      title: Text(l.cover, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(p == null ? l.coverGenerated : l.coverOwn),
      trailing: TextButton(
        onPressed: () async {
          if (p != null) {
            onChanged(null);
            return;
          }
          final picked = await context.imagesRead.source.pick();
          if (picked != null) onChanged(picked);
        },
        child: Text(p == null ? l.addCover : l.useGeneratedImage),
      ),
    );
  }
}

/// The player's photos: a general one and one per platform (Career tab).
class ArtistPhotosSection extends StatelessWidget {
  const ArtistPhotosSection(
      {super.key, required this.artistId, required this.name});
  final int artistId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = context.images;
    Widget row(ArtistPhoto kind, String title, String subtitle) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ArtistAvatar(
              name: name,
              seed: artistId,
              artistId: artistId,
              photo: kind,
              size: 48),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => editImage(context, ImageStore.artistKey(artistId, kind)),
        );
    final ownStreamify =
        store.path(ImageStore.artistKey(artistId, ArtistPhoto.streamify)) !=
            null;
    return Column(children: [
      row(ArtistPhoto.general, l.photoGeneral, l.photoGeneralHint),
      row(ArtistPhoto.streamify, l.photoPlatform(platformName),
          ownStreamify ? l.photoPlatformOwn : l.photoUsesGeneral),
    ]);
  }
}
