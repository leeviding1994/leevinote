import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';
import 'app_button.dart';

/// 统一对话框
class AppDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    final theme = Theme.of(context);

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h2Light(color: theme.colorScheme.onSurface)),
                if (content != null || contentWidget != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (contentWidget != null)
                    contentWidget
                  else
                    Text(content!, style: AppTypography.bodyLight(color: AppColors.secondaryText)),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    if (cancelLabel != null) ...[
                      Expanded(
                        child: AppButton.secondary(
                          label: cancelLabel,
                          onPressed: () {
                            if (onCancel != null) onCancel();
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: AppButton(
                        label: confirmLabel ?? '确定',
                        destructive: destructive,
                        onPressed: () {
                          if (onConfirm != null) onConfirm();
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    String? content,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
    bool destructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    );
  }
}
