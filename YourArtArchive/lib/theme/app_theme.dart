import 'package:flutter/material.dart';

abstract final class AppColors {
  static const cream = Color(0xFFF8F4ED);
  static const paper = Color(0xFFFFFDF9);
  static const brown = Color(0xFF2B1A0F);
  static const brownSoft = Color(0xFF654A38);
  static const gold = Color(0xFFC47A36);
  static const goldSoft = Color(0xFFE8C29E);
  static const line = Color(0xFFE9E1D8);
  static const muted = Color(0xFF8C7665);
  static const success = Color(0xFF0B9A72);
  static const danger = Color(0xFFC94C3B);
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.light,
      primary: AppColors.brown,
      secondary: AppColors.gold,
      surface: AppColors.paper,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'DMSans',
      visualDensity: VisualDensity.standard,
    );

    final body = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.brown,
        fontSize: 48,
        height: 1.03,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.brown,
        fontSize: 38,
        height: 1.08,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.brown,
        fontSize: 32,
        height: 1.12,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.brown,
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.brown,
        fontSize: 21,
        height: 1.18,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.brown,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: const TextStyle(
        color: AppColors.brown,
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: const TextStyle(
        color: AppColors.brown,
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: const TextStyle(
        color: AppColors.brownSoft,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.brownSoft,
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: const TextStyle(
        color: AppColors.brown,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .35,
      ),
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: body,
      primaryTextTheme: body,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.brown,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: body.bodyMedium?.copyWith(color: AppColors.muted),
        labelStyle: body.bodyMedium?.copyWith(color: AppColors.muted),
        floatingLabelStyle: body.labelMedium?.copyWith(color: AppColors.gold),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.gold, 1.6),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          backgroundColor: AppColors.brown,
          foregroundColor: Colors.white,
          textStyle: body.labelLarge?.copyWith(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          foregroundColor: AppColors.brown,
          side: const BorderSide(color: AppColors.goldSoft),
          textStyle: body.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle: body.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.brown,
        disabledColor: AppColors.line,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        labelStyle: body.labelMedium?.copyWith(
          color: AppColors.brownSoft,
          letterSpacing: 0,
        ),
        secondaryLabelStyle: body.labelMedium?.copyWith(
          color: Colors.white,
          letterSpacing: 0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColors.paper,
        indicatorColor: AppColors.goldSoft.withValues(alpha: .34),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => body.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : AppColors.muted,
            letterSpacing: 0,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : AppColors.muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.paper,
        selectedIconTheme: const IconThemeData(color: AppColors.gold),
        unselectedIconTheme: const IconThemeData(color: AppColors.muted),
        selectedLabelTextStyle: body.labelMedium?.copyWith(
          color: AppColors.gold,
          letterSpacing: 0,
        ),
        unselectedLabelTextStyle: body.labelMedium?.copyWith(
          color: AppColors.muted,
          letterSpacing: 0,
        ),
        indicatorColor: AppColors.goldSoft.withValues(alpha: .34),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brown,
        contentTextStyle: body.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.gold : null,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
      ),
    );
  }
}
