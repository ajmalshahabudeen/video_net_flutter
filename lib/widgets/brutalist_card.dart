import 'package:flutter/material.dart';

import '../theme/brutalist_theme.dart';

/// A Neo-Brutalist card with thick borders and hard offset shadows.
class BrutalistCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool showShadow;
  final Border? border;

  const BrutalistCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.onTap,
    this.padding,
    this.showShadow = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? BrutalistTheme.white,
          border: border ?? BrutalistTheme.hardBorder,
          boxShadow: showShadow ? BrutalistTheme.hardShadow : null,
        ),
        child: child,
      ),
    );
  }
}
