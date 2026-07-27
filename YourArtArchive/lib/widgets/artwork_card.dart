import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'archive_image.dart';

class ArtworkCard extends StatelessWidget {
  const ArtworkCard({
    super.key,
    required this.title,
    required this.creator,
    required this.category,
    this.imageSource,
    this.rating,
    this.isFavorite = false,
    this.status,
    this.onTap,
    this.onFavorite,
  });

  final String title;
  final String creator;
  final String category;
  final String? imageSource;
  final num? rating;
  final bool isFavorite;
  final String? status;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title by $creator',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArchiveImage(
                    source: imageSource,
                    category: category,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _CircleAction(
                      tooltip: isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onTap: onFavorite,
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? AppColors.danger : AppColors.brown,
                    ),
                  ),
                  if (rating != null)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '★ ${_formatRating(rating!)}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: Colors.white, letterSpacing: 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              creator,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                _Tag(label: category),
                if (status != null) _Tag(label: status!, accent: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRating(num rating) {
    return rating % 1 == 0
        ? rating.toInt().toString()
        : rating.toStringAsFixed(1);
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper.withValues(alpha: .94),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        color: color,
        icon: Icon(icon),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.goldSoft.withValues(alpha: .25)
            : AppColors.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: accent ? AppColors.gold : AppColors.brownSoft,
        ),
      ),
    );
  }
}
