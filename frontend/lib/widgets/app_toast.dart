import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

enum AppToastType { success, error, info }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppToastView(
        message: message,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
    Timer(duration, () {
      if (entry.mounted) entry.remove();
    });
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: AppToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: AppToastType.error);
  }
}

class _AppToastView extends StatelessWidget {
  final String message;
  final AppToastType type;
  final VoidCallback onDismiss;

  const _AppToastView({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 600;
    final maxWidth =
        isWide ? 360.0 : media.size.width - AppSpacing.pageHorizontal * 2;
    final accent = switch (type) {
      AppToastType.success => const Color(0xFF16A34A),
      AppToastType.error => theme.colorScheme.error,
      AppToastType.info => theme.colorScheme.primary,
    };
    final icon = switch (type) {
      AppToastType.success => Icons.check_circle_outline,
      AppToastType.error => Icons.error_outline,
      AppToastType.info => Icons.info_outline,
    };

    return Positioned(
      top: media.padding.top + AppSpacing.md,
      right: isWide ? AppSpacing.pageHorizontal : AppSpacing.pageHorizontal,
      left: isWide ? null : AppSpacing.pageHorizontal,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: isWide ? Alignment.topRight : Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.12),
                  ),
                  boxShadow: AppShadows.medium,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accent, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          message,
                          style: AppTypography.bodyMediumLight(
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        onTap: onDismiss,
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
