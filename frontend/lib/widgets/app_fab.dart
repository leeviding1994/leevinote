import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一浮动操作按钮
///
/// 替代默认 FloatingActionButton，圆角矩形、轻阴影。
class AppFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? heroTag;

  const AppFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary;
    final fg = foregroundColor ?? theme.colorScheme.onPrimary;
    final hasLabel = label != null && label!.isNotEmpty;

    final fab = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.medium,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onPressed,
          child: SizedBox(
            width: hasLabel ? null : 56,
            height: hasLabel ? 48 : 56,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hasLabel ? AppSpacing.lg : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 20),
                  if (hasLabel) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label!,
                      style: AppTypography.bodyMediumLight(color: fg),
                    ),
                  ],
                ],
              ),
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
