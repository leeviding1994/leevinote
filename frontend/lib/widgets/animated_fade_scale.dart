import 'package:flutter/material.dart';

/// 统一的淡入缩放动画包装
///
/// 用于卡片、列表项等元素的入场动画。
class AnimatedFadeScale extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double beginScale;
  final int index;

  const AnimatedFadeScale({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    this.beginScale = 0.96,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1.0 - (1.0 - value) * (1.0 - beginScale),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 列表项渐入动画
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration baseDuration;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDuration = const Duration(milliseconds: 280),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedFadeScale(
      duration: baseDuration,
      index: index,
      child: child,
    );
  }
}
