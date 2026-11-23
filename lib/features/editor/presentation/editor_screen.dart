import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/editor_controller.dart';
import '../domain/editor_state.dart';
import 'panels/background_panel.dart';
import 'panels/combos_panel.dart';
import 'panels/expand_panel.dart';
import 'panels/mask_panel.dart';
import 'panels/styles_panel.dart';
import 'panels/upscale_panel.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/editor_chrome.dart';

/// Editor: canvas (~75 %), contextual bottom panel, tool rail.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  Widget _panel(EditorState s) {
    final pending = s.pending;
    if (pending != null && pending.kind != 'style') {
      if (s.tool == EditorTool.background) {
        return const Column(mainAxisSize: MainAxisSize.min, children: [BackgroundPanel(), PendingBar()]);
      }
      return const PendingBar();
    }
    return switch (s.tool) {
      EditorTool.erase => const MaskPanel(select: false),
      EditorTool.select => const MaskPanel(select: true),
      EditorTool.expand => const ExpandPanel(),
      EditorTool.background => const BackgroundPanel(),
      EditorTool.upscale => const UpscalePanel(),
      EditorTool.styles => const StylesPanel(),
      EditorTool.combos => const CombosPanel(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(editorProvider.select((s) => s.toast), (_, t) {
      if (t == null) return;
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(
        content: Text(t.text),
        backgroundColor: t.error ? Theme.of(context).colorScheme.error : null,
        duration: Duration(seconds: t.error ? 5 : 3),
      ));
    });
    final s = ref.watch(editorProvider);
    if (!s.hasImage) {
      // Opened without a photo (e.g. after process death): go back home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const EditorTopBar(),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const EditorCanvas(),
                  if (s.comparing)
                    const Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(child: Chip(label: Text('Original'))),
                    ),
                  const BusyOverlay(),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _panel(s),
            ),
            const ToolRail(),
          ],
        ),
      ),
    );
  }
}
