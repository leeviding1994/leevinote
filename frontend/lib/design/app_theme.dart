import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_radius.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// 应用主题配置
///
/// 保持与旧版 API 兼容：AppTheme.lightTheme(seedColor:) / darkTheme(seedColor:)
abstract final class AppTheme {
  static ThemeData lightTheme({Color seedColor = AppColors.brand}) {
    const brightness = Brightness.light;
    final isBrand = seedColor.toARGB32() == AppColors.brand.toARGB32();
    final primary = isBrand ? AppColors.brand : seedColor;

    final colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandLight,
      onPrimaryContainer: primary,
      secondary: primary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.primaryText,
      surfaceContainerHighest: AppColors.surfaceSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: Colors.white,
      brightness: brightness,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      brightness: brightness,
    );
  }

  static ThemeData darkTheme({Color seedColor = AppColors.brand}) {
    const brightness = Brightness.dark;
    final isBrand = seedColor.toARGB32() == AppColors.brand.toARGB32();
    final primary = isBrand ? AppColors.brand : seedColor;

    final colorScheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.surfaceSecondaryDark,
      onPrimaryContainer: Colors.white,
      secondary: primary,
      onSecondary: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.primaryTextDark,
      surfaceContainerHighest: AppColors.surfaceSecondaryDark,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderDark,
      error: AppColors.error,
      onError: Colors.white,
      brightness: brightness,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      brightness: brightness,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: (isDark ? AppTypography.h3Dark() : AppTypography.h3Light()).copyWith(
          color: colorScheme.onSurface,
        ),
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.captionMediumLight(color: colorScheme.onSurfaceVariant),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        hintStyle: AppTypography.bodyLight(color: AppColors.tertiaryText),
        labelStyle: AppTypography.captionLight(color: AppColors.secondaryText),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceSecondaryDark : AppColors.primaryText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        contentTextStyle: AppTypography.bodyLight(color: Colors.white),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: AppTypography.captionMediumLight(color: colorScheme.onSurface),
        secondaryLabelStyle: AppTypography.captionMediumLight(color: colorScheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide.none,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return isDark ? AppColors.surfaceSecondaryDark : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary.withValues(alpha: 0.3);
          return isDark ? AppColors.borderDark : AppColors.border;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
