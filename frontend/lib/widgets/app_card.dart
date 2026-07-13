import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一卡片组件
///
/// 纯白、轻阴影、24dp 圆角，替代默认 Card。
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final List<BoxShadow>? shadows;
  final BorderRadius? borderRadius;
  final Border? border;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.shadows,
    this.borderRadius,
    this.border,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: color ?? theme.colorScheme.surface,
          borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
          border: border,
          boxShadow: shadows ?? (isDark ? AppShadows.dark : AppShadows.light),
        ),
        clipBehavior: clipBehavior,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
          child: InkWell(
            borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
