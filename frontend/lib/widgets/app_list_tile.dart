import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一列表项
///
/// 替代默认 ListTile，保持一致的间距、圆角与文字样式。
class AppListTile extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AppListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.pageHorizontal,
      vertical: AppSpacing.md,
    ),
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: backgroundColor ?? Colors.transparent,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: AppTypography.bodyLight(color: theme.colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: AppTypography.captionLight(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
