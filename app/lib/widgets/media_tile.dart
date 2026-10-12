import 'package:flutter/material.dart';

import '../ui/palette.dart';
import 'art.dart';

/// A song or release row: cover, title, subtitle and a value on the right.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.coverSeed,
    required this.title,
    required this.subtitle,
    this.value,
    this.badge,
    this.onTap,
  });

  final int coverSeed;
  final String title;
  final String subtitle;
  final String? value;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          CoverArt(seed: coverSeed, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
          if (value != null) ...[
            const SizedBox(width: 10),
            Text(value!,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          ],
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
        ]),
      ),
    );
  }
}

/// "#12" peak tag; gold for #1, hidden when it never charted.
class PeakTag extends StatelessWidget {
  const PeakTag(this.peak, {super.key});
  final int peak;

  @override
  Widget build(BuildContext context) {
    if (peak <= 0) return const SizedBox.shrink();
    final top = peak == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: top ? AppColors.gold : AppColors.lilac.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('#$peak',
          style: TextStyle(
              fontFamily: AppFonts.condensed,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: top ? Colors.black : AppColors.lilac)),
    );
  }
}
