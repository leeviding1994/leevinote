import 'package:flutter/material.dart';
import 'package:leevinote/design/app_theme.dart';

/// 统一输入框
///
/// 现代风格、无传统边框、大圆角、轻阴影背景。
class AppInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextAlign textAlign;
  final TextStyle? style;
  final EdgeInsets? contentPadding;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const AppInput({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.contentPadding,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.input,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        minLines: minLines,
        onChanged: onChanged,
        onTap: onTap,
        readOnly: readOnly,
        textAlign: textAlign,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onEditingComplete: onEditingComplete,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        style: style ?? AppTypography.bodyLight(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
                  child: prefixIcon,
                )
              : null,
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.lg),
                  child: suffixIcon,
                )
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          contentPadding: contentPadding ?? const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintStyle: AppTypography.bodyLight(color: AppColors.tertiaryText),
        ),
      ),
    );
  }
}
