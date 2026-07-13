import 'package:flutter/material.dart';

/// 统一顶部导航栏
///
/// 替代默认 AppBar，更克制的样式与一致的高度。
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.bottom,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));
}
