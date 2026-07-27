import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EditorialLogo extends StatelessWidget {
  const EditorialLogo({
    super.key,
    this.size = 58,
    this.light = false,
    this.showName = true,
  });

  final double size;
  final bool light;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : AppColors.brown;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: .13)
                : AppColors.goldSoft.withValues(alpha: .25),
            borderRadius: BorderRadius.circular(size * .31),
            border: Border.all(
              color: light
                  ? Colors.white.withValues(alpha: .42)
                  : AppColors.goldSoft,
            ),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: size * .48,
            color: foreground,
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 13),
          Text(
            'YourArtArchive',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: foreground, fontSize: 20),
          ),
        ],
      ],
    );
  }
}
