import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// 应用统一字体规范
///
/// 使用 Inter 作为英文字体，中文回退系统字体。
/// 字号层级：一级标题 28、二级标题 22、正文 16、辅助文字 14。
abstract final class AppTypography {
  static TextStyle _base({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.4,
      decoration: decoration,
      textBaseline: TextBaseline.alphabetic,
    );
  }

  // ---------- Light Mode ----------
  static TextStyle h1Light({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.primaryText,
        height: 1.25,
        decoration: decoration,
      );

  static TextStyle h2Light({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.primaryText,
        height: 1.3,
        decoration: decoration,
      );

  static TextStyle h3Light({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.primaryText,
        height: 1.35,
        decoration: decoration,
      );

  static TextStyle bodyLight({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.primaryText,
        decoration: decoration,
      );

  static TextStyle bodyMediumLight({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.primaryText,
        decoration: decoration,
      );

  static TextStyle captionLight({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.secondaryText,
        decoration: decoration,
      );

  static TextStyle captionMediumLight({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.secondaryText,
        decoration: decoration,
      );

  static TextStyle smallLight({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.tertiaryText,
        decoration: decoration,
      );

  static TextStyle smallMediumLight({Color? color, TextDecoration? decoration}) => _base(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.tertiaryText,
        decoration: decoration,
      );

  static TextStyle monoLight({Color? color, double? fontSize, TextDecoration? decoration}) => GoogleFonts.inter(
        fontSize: fontSize ?? 16,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.3,
        decoration: decoration,
      );

  // ---------- Dark Mode ----------
  static TextStyle h1Dark({Color? color, TextDecoration? decoration}) => h1Light(color: color ?? AppColors.primaryTextDark, decoration: decoration);
  static TextStyle h2Dark({Color? color, TextDecoration? decoration}) => h2Light(color: color ?? AppColors.primaryTextDark, decoration: decoration);
  static TextStyle h3Dark({Color? color, TextDecoration? decoration}) => h3Light(color: color ?? AppColors.primaryTextDark, decoration: decoration);
  static TextStyle bodyDark({Color? color, TextDecoration? decoration}) => bodyLight(color: color ?? AppColors.primaryTextDark, decoration: decoration);
  static TextStyle bodyMediumDark({Color? color, TextDecoration? decoration}) => bodyMediumLight(color: color ?? AppColors.primaryTextDark, decoration: decoration);
  static TextStyle captionDark({Color? color, TextDecoration? decoration}) => captionLight(color: color ?? AppColors.secondaryTextDark, decoration: decoration);
  static TextStyle captionMediumDark({Color? color, TextDecoration? decoration}) => captionMediumLight(color: color ?? AppColors.secondaryTextDark, decoration: decoration);
  static TextStyle smallDark({Color? color, TextDecoration? decoration}) => smallLight(color: color ?? AppColors.tertiaryTextDark, decoration: decoration);
  static TextStyle smallMediumDark({Color? color, TextDecoration? decoration}) => smallMediumLight(color: color ?? AppColors.tertiaryTextDark, decoration: decoration);
  static TextStyle monoDark({Color? color, double? fontSize, TextDecoration? decoration}) => monoLight(color: color ?? AppColors.primaryTextDark, fontSize: fontSize, decoration: decoration);
}

/// 上下文相关的字体扩展
extension AppTypographyContext on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  TextStyle get h1 => _isDark ? AppTypography.h1Dark() : AppTypography.h1Light();
  TextStyle get h2 => _isDark ? AppTypography.h2Dark() : AppTypography.h2Light();
  TextStyle get h3 => _isDark ? AppTypography.h3Dark() : AppTypography.h3Light();
  TextStyle get body => _isDark ? AppTypography.bodyDark() : AppTypography.bodyLight();
  TextStyle get bodyMedium => _isDark ? AppTypography.bodyMediumDark() : AppTypography.bodyMediumLight();
  TextStyle get caption => _isDark ? AppTypography.captionDark() : AppTypography.captionLight();
  TextStyle get captionMedium => _isDark ? AppTypography.captionMediumDark() : AppTypography.captionMediumLight();
  TextStyle get small => _isDark ? AppTypography.smallDark() : AppTypography.smallLight();
  TextStyle get smallMedium => _isDark ? AppTypography.smallMediumDark() : AppTypography.smallMediumLight();
}
