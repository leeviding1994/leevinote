import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一主按钮
///
/// 大圆角、高度 52、轻阴影，禁止使用默认 ElevatedButton。
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool destructive;
  final IconData? icon;
  final double? height;
  final double? width;
  final EdgeInsets? padding;
  final bool secondary;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.destructive = false,
    this.icon,
    this.height,
    this.width = double.infinity,
    this.padding,
    this.secondary = false,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.destructive = false,
    this.icon,
    this.height,
    this.width = double.infinity,
    this.padding,
  }) : secondary = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final foregroundColor = secondary
        ? (destructive ? AppColors.error : theme.colorScheme.primary)
        : Colors.white;
    final backgroundColor = secondary
        ? (destructive
            ? AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08)
            : theme.colorScheme.primaryContainer)
        : (destructive ? AppColors.error : theme.colorScheme.primary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width,
      height: height ?? 52,
      decoration: BoxDecoration(
        color: onPressed == null || isLoading ? backgroundColor.withValues(alpha: 0.5) : backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: secondary || onPressed == null || isLoading ? null : AppShadows.light,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(foregroundColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: foregroundColor),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        label,
                        style: AppTypography.bodyMediumLight(color: foregroundColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
