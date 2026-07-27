import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ArchiveImage extends StatelessWidget {
  const ArchiveImage({
    super.key,
    this.source,
    this.category = 'Artwork',
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? source;
  final String category;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  IconData get _icon {
    return switch (category.toLowerCase()) {
      'book' || 'manga' => Icons.menu_book_rounded,
      'movie' => Icons.local_movies_outlined,
      'series' || 'anime' => Icons.live_tv_outlined,
      'video game' || 'game' => Icons.sports_esports_outlined,
      'theater' || 'theatre' => Icons.theater_comedy_outlined,
      _ => Icons.auto_awesome_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget fallback() => ColoredBox(
      color: AppColors.goldSoft.withValues(alpha: .28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: AppColors.gold, size: 34),
            const SizedBox(height: 7),
            Text(
              category,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.brownSoft,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );

    final value = source?.trim() ?? '';
    Widget image;
    if (value.isEmpty) {
      image = fallback();
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      image = Image.network(
        value,
        fit: fit,
        frameBuilder: (context, child, frame, _) {
          if (frame != null) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              fallback(),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        },
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = Image.asset(
        value,
        fit: fit,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(18),
      child: image,
    );
  }
}
