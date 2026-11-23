import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Single source of truth for the Material 3 themes.
abstract final class AppTheme {
  static const _fontFamily = 'Inter';

  static const _text = TextTheme(
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    bodySmall: TextStyle(fontSize: 12, height: 1.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
  );

  static ThemeData get dark => _build(
        Brightness.dark,
        bg: AppColors.bg,
        surface: AppColors.surface,
        surface2: AppColors.surface2,
        hi: AppColors.textHi,
        lo: AppColors.textLo,
        border: AppColors.border,
      );

  static ThemeData get light => _build(
        Brightness.light,
        bg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        surface2: AppColors.lightSurface2,
        hi: AppColors.lightText,
        lo: AppColors.lightTextLo,
        border: const Color(0x1F000000),
      );

  static ThemeData _build(Brightness b,
      {required Color bg,
      required Color surface,
      required Color surface2,
      required Color hi,
      required Color lo,
      required Color border}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: b,
    ).copyWith(
      primary: b == Brightness.dark ? AppColors.accent : const Color(0xFF5B3FE0),
      secondary: AppColors.ai,
      surface: surface,
      onSurface: hi,
      onSurfaceVariant: lo,
      surfaceContainerHighest: surface2,
      error: AppColors.danger,
      outlineVariant: border,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius));
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: bg,
      textTheme: _text.apply(bodyColor: hi, displayColor: hi),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: hi,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          shape: shape,
          side: BorderSide(color: border),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: surface2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: hi, fontFamily: _fontFamily),
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
    );
  }
}
