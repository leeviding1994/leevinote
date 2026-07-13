import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一标签/筛选组件
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final Color? selectedColor;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveSelectedColor = selectedColor ?? theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected
            ? effectiveSelectedColor.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected ? effectiveSelectedColor : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onSelected != null ? () => onSelected!(!selected) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? effectiveSelectedColor : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: AppTypography.captionMediumLight(
                    color: selected ? effectiveSelectedColor : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
