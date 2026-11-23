import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../editor/application/editor_controller.dart';

/// Full-screen before / after with a draggable divider (left = original).
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  double _f = 0.5;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editorProvider);
    final before = s.original, after = s.image;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (before == null || after == null)
              const Center(child: Text('Nothing to compare yet'))
            else
              LayoutBuilder(builder: (context, box) {
                final x = box.maxWidth * _f;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => setState(() => _f = (_f + d.delta.dx / box.maxWidth).clamp(0.0, 1.0)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RawImage(image: after, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                      ClipRect(
                        clipper: _LeftClipper(x),
                        child: RawImage(image: before, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                      ),
                      Positioned(left: x - 1, top: 0, bottom: 0, child: Container(width: 2, color: Colors.white)),
                      Positioned(
                        left: x - 22,
                        top: box.maxHeight / 2 - 22,
                        child: Semantics(
                          label: 'Comparison divider',
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                            child: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                          ),
                        ),
                      ),
                      const Positioned(left: 16, bottom: 24, child: Chip(label: Text('Before'))),
                      const Positioned(right: 16, bottom: 24, child: Chip(label: Text('After'))),
                    ],
                  ),
                );
              }),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton.filledTonal(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.x);
  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.x != x;
}
