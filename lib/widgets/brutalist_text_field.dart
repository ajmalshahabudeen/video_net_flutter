import 'package:flutter/material.dart';

import '../theme/brutalist_theme.dart';

/// A Neo-Brutalist text field with thick borders and monospace styling.
class BrutalistTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  const BrutalistTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.errorText,
    this.onChanged,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: BrutalistTheme.labelLarge.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            boxShadow: BrutalistTheme.smallShadow,
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: BrutalistTheme.mono,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 20, color: BrutalistTheme.black)
                  : null,
              suffix: suffix,
              errorText: errorText,
            ),
          ),
        ),
      ],
    );
  }
}
