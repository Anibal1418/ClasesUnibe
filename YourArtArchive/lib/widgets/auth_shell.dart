import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'editorial_logo.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 840;
            final form = SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 360 ? 16 : 28,
                vertical: 24,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (onBack != null)
                          IconButton(
                            onPressed: onBack,
                            tooltip: 'Back',
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        if (!desktop) ...[
                          const EditorialLogo(size: 46),
                          const SizedBox(height: 44),
                        ],
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            );

            if (!desktop) return form;
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    color: AppColors.brown,
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EditorialLogo(light: true),
                        const Spacer(),
                        Text(
                          'Every story\nleaves a trace.',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Keep the books, films, games, and performances '
                          'that shaped you in one personal archive.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: .76),
                              ),
                        ),
                        const Spacer(),
                        Text(
                          'YOUR PERSONAL ARCHIVE',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.goldSoft,
                                letterSpacing: 1.7,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(flex: 7, child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}
