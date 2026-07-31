import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一图标按钮
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final String? tooltip;
  final double iconSize;
  final Widget? child;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.color,
    this.tooltip,
    this.iconSize = 22,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: child ??
                Icon(
                  icon,
                  size: iconSize,
                  color: color ?? theme.colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}
