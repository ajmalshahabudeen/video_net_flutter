import 'package:flutter/material.dart';

import '../theme/brutalist_theme.dart';

/// Brutalist-styled scan progress indicator with raw border aesthetics.
class ScanProgressIndicator extends StatelessWidget {
  final double progress;
  final String? label;
  final String? sublabel;

  const ScanProgressIndicator({
    super.key,
    required this.progress,
    this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label!, style: BrutalistTheme.labelLarge),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: BrutalistTheme.mono.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BrutalistTheme.accent,
                  ),
                ),
              ],
            ),
          ),
        Container(
          height: 28,
          decoration: BoxDecoration(
            border: BrutalistTheme.hardBorder,
            color: BrutalistTheme.white,
          ),
          child: Stack(
            children: [
              // Progress fill
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  color: BrutalistTheme.accent,
                ),
              ),
              // Scan lines effect
              if (progress < 1.0)
                Positioned.fill(
                  child: _ScanLineAnimation(),
                ),
            ],
          ),
        ),
        if (sublabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              sublabel!,
              style: BrutalistTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _ScanLineAnimation extends StatefulWidget {
  @override
  State<_ScanLineAnimation> createState() => _ScanLineAnimationState();
}

class _ScanLineAnimationState extends State<_ScanLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanLinePainter(_controller.value),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BrutalistTheme.accent.withValues(alpha: 0.3)
      ..strokeWidth = 2;

    final x = size.width * progress;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
