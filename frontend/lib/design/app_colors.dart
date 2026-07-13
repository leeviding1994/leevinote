import 'package:flutter/material.dart';

/// 应用统一颜色规范
///
/// 整体颜色数量尽量少，保持高级感与现代感。
/// 主色调为蓝紫色，避免使用 Flutter 默认蓝色。
abstract final class AppColors {
  // ---------- 品牌/强调色 ----------
  /// 主品牌色：蓝紫色，不刺眼，具有科技感
  static const Color brand = Color(0xFF6366F1);

  /// 品牌浅色：用于 hover、弱强调背景
  static const Color brandLight = Color(0xFFEEF2FF);

  /// 品牌深色：用于按压、强调描边
  static const Color brandDark = Color(0xFF4F46E5);

  // ---------- 背景色 ----------
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF5F5F5);

  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceSecondaryDark = Color(0xFF2C2C2E);

  // ---------- 文字色 ----------
  static const Color primaryText = Color(0xFF222222);
  static const Color secondaryText = Color(0xFF666666);
  static const Color tertiaryText = Color(0xFF999999);
  static const Color disabledText = Color(0xFFBBBBBB);

  static const Color primaryTextDark = Color(0xFFFFFFFF);
  static const Color secondaryTextDark = Color(0xFFAAAAAA);
  static const Color tertiaryTextDark = Color(0xFF777777);
  static const Color disabledTextDark = Color(0xFF555555);

  // ---------- 边框/分隔线 ----------
  static const Color border = Color(0xFFEEEEEE);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color borderDark = Color(0xFF2C2C2E);
  static const Color dividerDark = Color(0xFF2C2C2E);

  // ---------- 功能色 ----------
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ---------- 阴影 ----------
  static Color shadow = const Color(0xFF000000).withValues(alpha: 0.06);
  static Color shadowDark = const Color(0xFF000000).withValues(alpha: 0.25);
}
