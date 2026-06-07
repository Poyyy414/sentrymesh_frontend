import 'package:flutter/material.dart';

class SentryButton extends StatelessWidget {
  const SentryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );

    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              key: const ValueKey('label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );

    if (icon == null || isLoading) {
      return ElevatedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      );
    }

    return ElevatedButton.icon(
      onPressed: effectiveOnPressed,
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: style,
    );
  }
}
