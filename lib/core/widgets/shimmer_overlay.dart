import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diagonal violet/cyan sweep shown over the canvas while a model runs.
class ShimmerOverlay extends StatefulWidget {
  const ShimmerOverlay({super.key});

  @override
  State<ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<ShimmerOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.5 + 3 * t, -1),
                  end: Alignment(-0.5 + 3 * t, 1),
                  colors: [
                    Colors.transparent,
                    AppColors.ai.withValues(alpha: 0.18),
                    AppColors.accent.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.4, 0.6, 1],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
