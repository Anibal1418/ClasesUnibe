import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/editorial_logo.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brown,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 840;
            if (desktop) {
              return Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _EditorialIntro(
                      alignment: CrossAxisAlignment.start,
                      titleSize: 68,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: ColoredBox(
                      color: AppColors.cream,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Padding(
                            padding: const EdgeInsets.all(42),
                            child: _Actions(
                              onLogin: onLogin,
                              onRegister: onRegister,
                              dark: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                constraints.maxWidth < 360 ? 18 : 28,
                24,
                constraints.maxWidth < 360 ? 18 : 28,
                26,
              ),
              child: Column(
                children: [
                  const Expanded(
                    child: _EditorialIntro(
                      alignment: CrossAxisAlignment.center,
                      titleSize: 44,
                    ),
                  ),
                  _Actions(
                    onLogin: onLogin,
                    onRegister: onRegister,
                    dark: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditorialIntro extends StatelessWidget {
  const _EditorialIntro({required this.alignment, required this.titleSize});

  final CrossAxisAlignment alignment;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final centered = alignment == CrossAxisAlignment.center;
    return Stack(
      children: [
        Positioned(
          right: -70,
          top: -90,
          child: Container(
            width: 310,
            height: 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldSoft.withValues(alpha: .11),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(centered ? 0 : 64),
          child: Column(
            crossAxisAlignment: alignment,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EditorialLogo(
                light: true,
                showName: !centered,
                size: centered ? 68 : 58,
              ),
              SizedBox(height: centered ? 38 : 68),
              Text(
                'YOUR PERSONAL ARCHIVE',
                textAlign: centered ? TextAlign.center : TextAlign.left,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.goldSoft,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Art\nArchive',
                textAlign: centered ? TextAlign.center : TextAlign.left,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: titleSize,
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 510),
                child: Text(
                  'Track, review, and remember every story that shaped you.',
                  textAlign: centered ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: centered ? 15 : 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onLogin,
    required this.onRegister,
    required this.dark,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : AppColors.brown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: onLogin,
          style: FilledButton.styleFrom(
            backgroundColor: dark ? Colors.white : AppColors.brown,
            foregroundColor: dark ? AppColors.brown : Colors.white,
          ),
          child: const Text('Log In'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRegister,
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: .45)
                  : AppColors.goldSoft,
            ),
          ),
          child: const Text('Create Account'),
        ),
        const SizedBox(height: 20),
        Text(
          'A thoughtful home for every story that stays with you.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: foreground.withValues(alpha: .6),
          ),
        ),
      ],
    );
  }
}
