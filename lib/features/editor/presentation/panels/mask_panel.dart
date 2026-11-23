import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../application/ai_actions.dart';
import '../../application/editor_controller.dart';

/// Panel for the Erase tool (brush) and the Select tool (tap an object).
class MaskPanel extends ConsumerWidget {
  const MaskPanel({super.key, required this.select});
  final bool select;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorProvider);
    final c = ref.read(editorProvider.notifier);
    final mask = c.mask;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            select
                ? 'Tap an object to select it, then refine with the brush.'
                : 'Brush over what you want to remove.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Row(
            children: [
              Icon(Icons.brush_rounded, size: 18, color: scheme.onSurfaceVariant),
              Expanded(
                child: Slider(
                  min: 8,
                  max: 90,
                  value: s.brushDp,
                  semanticFormatterCallback: (v) => 'Brush size ${v.round()}',
                  onChanged: c.setBrush,
                ),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.brush_rounded), tooltip: 'Add to selection'),
                  ButtonSegment(value: true, icon: Icon(Icons.cleaning_services_rounded), tooltip: 'Remove from selection'),
                ],
                selected: {s.eraserMode},
                onSelectionChanged: (v) => c.setEraserMode(v.first),
              ),
            ],
          ),
          Row(
            children: [
              ListenableBuilder(
                listenable: mask,
                builder: (_, __) => Row(
                  children: [
                    IconButton(
                      tooltip: 'Undo last stroke',
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: mask.strokes.isEmpty ? null : mask.undoStroke,
                    ),
                    IconButton(
                      tooltip: 'Clear selection',
                      icon: const Icon(Icons.layers_clear_rounded),
                      onPressed: mask.isEmpty ? null : mask.clear,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: ListenableBuilder(
                  listenable: mask,
                  builder: (_, __) => AiButton(
                    label: select ? 'Erase selection' : 'Erase',
                    icon: Icons.auto_fix_high_rounded,
                    onPressed: mask.isEmpty ? null : ref.read(aiProvider).erase,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
