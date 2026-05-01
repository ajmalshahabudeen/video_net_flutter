import 'package:flutter/material.dart';

import '../theme/brutalist_theme.dart';

/// A Neo-Brutalist button with thick borders and hard shadows.
class BrutalistButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final bool small;

  const BrutalistButton({
    super.key,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.small = false,
  });

  @override
  State<BrutalistButton> createState() => _BrutalistButtonState();
}

class _BrutalistButtonState extends State<BrutalistButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? BrutalistTheme.black;
    final fg = widget.textColor ?? BrutalistTheme.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: widget.small ? 16 : 24,
          vertical: widget.small ? 10 : 16,
        ),
        decoration: BoxDecoration(
          color: widget.onPressed == null
              ? BrutalistTheme.concrete
              : bg,
          border: Border.all(
            color: BrutalistTheme.black,
            width: BrutalistTheme.borderWidth,
          ),
          boxShadow: _isPressed || widget.onPressed == null
              ? []
              : BrutalistTheme.hardShadow,
        ),
        transform: _isPressed
            ? Matrix4.translationValues(4, 4, 0)
            : Matrix4.identity(),
        child: widget.isLoading
            ? Center(
                child: SizedBox(
                  height: widget.small ? 16 : 20,
                  width: widget.small ? 16 : 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: fg,
                  ),
                ),
              )
            : Row(
                mainAxisSize:
                    widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: fg, size: widget.small ? 16 : 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.label,
                    style: BrutalistTheme.labelLarge.copyWith(
                      color: fg,
                      fontSize: widget.small ? 12 : 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
