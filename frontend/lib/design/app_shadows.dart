import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 应用统一阴影规范
///
/// 使用极轻的阴影，保持界面干净、高级。
abstract final class AppShadows {
  static List<BoxShadow> get light => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -6,
        ),
      ];

  static List<BoxShadow> get dark => [
        BoxShadow(
          color: AppColors.shadowDark,
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get input => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: -2,
        ),
      ];
}
