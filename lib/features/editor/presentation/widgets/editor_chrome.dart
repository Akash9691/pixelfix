import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/shimmer_overlay.dart';
import '../../application/editor_controller.dart';
import '../../domain/editor_state.dart';
import '../../../export/presentation/export_sheet.dart';

class EditorTopBar extends ConsumerWidget {
  const EditorTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorProvider);
    final c = ref.read(editorProvider.notifier);
    final idle = s.busy == null;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo_rounded),
            onPressed: s.canUndo && idle ? c.undo : null,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo_rounded),
            onPressed: s.canRedo && idle ? c.redo : null,
          ),
          // Hold to see the original; tap opens the full-screen slider.
          Semantics(
            button: true,
            label: 'Compare with original. Hold to peek, tap for slider.',
            child: GestureDetector(
              onTapDown: (_) => c.setComparing(true),
              onTapUp: (_) {
                c.setComparing(false);
                context.push('/compare');
              },
              onTapCancel: () => c.setComparing(false),
              onLongPressEnd: (_) => c.setComparing(false),
              child: const SizedBox(
                width: AppSpacing.minTouch,
                height: AppSpacing.minTouch,
                child: Icon(Icons.compare_rounded),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: s.hasImage && idle ? () => showExportSheet(context) : null,
          ),
        ],
      ),
    );
  }
}

/// Bottom tool rail (Erase, Select, Expand, Background, Upscale, Styles, Combos).
class ToolRail extends ConsumerWidget {
  const ToolRail({super.key});

  static const _tools = <(EditorTool, IconData, String)>[
    (EditorTool.erase, Icons.auto_fix_high_rounded, 'Erase'),
    (EditorTool.select, Icons.touch_app_rounded, 'Select'),
    (EditorTool.expand, Icons.open_in_full_rounded, 'Expand'),
    (EditorTool.background, Icons.layers_rounded, 'Background'),
    (EditorTool.upscale, Icons.hd_rounded, 'Upscale'),
    (EditorTool.styles, Icons.palette_rounded, 'Styles'),
    (EditorTool.combos, Icons.bolt_rounded, 'Combos'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorProvider);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.xs),
        itemCount: _tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final (tool, icon, label) = _tools[i];
          final sel = s.tool == tool;
          return Semantics(
            button: true,
            selected: sel,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              onTap: s.busy == null ? () => ref.read(editorProvider.notifier).setTool(tool) : null,
              child: AnimatedContainer(
                duration: AppSpacing.motion,
                curve: Curves.easeOut,
                width: 72,
                decoration: BoxDecoration(
                  color: sel ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: sel ? AppColors.accent : scheme.onSurfaceVariant),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, color: sel ? scheme.onSurface : scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer over the canvas + progress card with Cancel while a model runs.
class BusyOverlay extends ConsumerWidget {
  const BusyOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(editorProvider.select((s) => s.busy));
    if (b == null) return const SizedBox.shrink();
    return Stack(
      children: [
        const Positioned.fill(child: ShimmerOverlay()),
        Positioned.fill(child: AbsorbPointer(child: Container(color: Colors.transparent))),
        Positioned(
          left: AppSpacing.m,
          right: AppSpacing.m,
          bottom: AppSpacing.m,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(b.label, style: Theme.of(context).textTheme.labelLarge),
                      ),
                      TextButton(
                        onPressed: ref.read(editorProvider.notifier).cancelJob,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: b.progress, minHeight: 6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Select → preview → apply / cancel.
class PendingBar extends ConsumerWidget {
  const PendingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorProvider.notifier);
    final hint = ref.watch(editorProvider.select((s) => s.hint));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Text(hint, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ),
          Text(
            'Preview. Hold the photo to compare with the original.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: c.discardPending,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: c.applyPending,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
