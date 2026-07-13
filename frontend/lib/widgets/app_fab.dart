import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一浮动操作按钮
///
/// 替代默认 FloatingActionButton，圆角矩形、轻阴影。
class AppFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? heroTag;

  const AppFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fab = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.medium,
      ),
      child: Material(
        color: backgroundColor ?? theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              icon,
              color: foregroundColor ?? theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
        ),
      ),
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: fab);
    }
    return fab;
  }
}
