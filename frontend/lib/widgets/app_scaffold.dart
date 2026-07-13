import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一页面骨架
///
/// 提供一致的背景色与内容内边距。
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
    this.backgroundColor,
  });

  /// 不带水平内边距的骨架，适用于列表全宽场景
  const AppScaffold.noPadding({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  }) : padding = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      appBar: appBar,
      body: Padding(
        padding: padding,
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}
