import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ai_button.dart';
import '../../../data/projects_repository.dart';
import '../../editor/application/editor_controller.dart';
import '../../editor/domain/editor_state.dart';
import '../../onboarding/presentation/coach_overlay.dart';
import '../../settings/application/settings_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _tools = <(EditorTool, IconData, String, String)>[
    (EditorTool.erase, Icons.auto_fix_high_rounded, 'Magic Eraser', 'Brush an object away'),
    (EditorTool.select, Icons.touch_app_rounded, 'Tap to Select', 'One tap masks an object'),
    (EditorTool.expand, Icons.open_in_full_rounded, 'Expand', 'Extend the borders'),
    (EditorTool.background, Icons.layers_rounded, 'Background', 'Remove or replace it'),
    (EditorTool.upscale, Icons.hd_rounded, 'AI Upscale', 'Sharpen 2× or 4×'),
    (EditorTool.styles, Icons.palette_rounded, 'Art Styles', 'Paint your photo'),
    (EditorTool.combos, Icons.bolt_rounded, 'Smart Combos', 'One-tap pipelines'),
  ];

  Future<void> _pick(BuildContext context, WidgetRef ref, ImageSource src, [EditorTool? tool]) async {
    final f = await ImagePicker().pickImage(source: src);
    if (f == null) return;
    final c = ref.read(editorProvider.notifier);
    final ok = await c.openFile(f.path);
    if (!ok) return;
    if (tool != null) c.setTool(tool);
    if (context.mounted) context.push('/editor');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    final edits = ref.watch(editsProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final body = SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => AppColors.aiGradient.createShader(r),
                child: Text('PixelFix', style: t.displayMedium?.copyWith(color: Colors.white)),
              ),
              const Spacer(),
              IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_rounded), onPressed: () => context.push('/settings')),
            ],
          ),
          Text('Offline AI photo studio. Nothing leaves your phone.', style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.l),
          AiButton(label: 'Open Photo', icon: Icons.photo_library_rounded, onPressed: () => _pick(context, ref, ImageSource.gallery)),
          const SizedBox(height: AppSpacing.s),
          OutlinedButton.icon(
            onPressed: () => _pick(context, ref, ImageSource.camera),
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Camera'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: AppSpacing.l),
          Text('Tools', style: t.titleLarge),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tools.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
              itemBuilder: (_, i) {
                final (tool, icon, name, desc) = _tools[i];
                return SizedBox(
                  width: 156,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                      onTap: () => _pick(context, ref, ImageSource.gallery, tool),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: AppColors.ai),
                            const SizedBox(height: AppSpacing.s),
                            Text(name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(desc, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Text('Recent edits', style: t.titleLarge),
              const Spacer(),
              TextButton(onPressed: () => context.push('/edits'), child: const Text('See all')),
            ],
          ),
          SizedBox(
            height: 96,
            child: edits.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (files) => files.isEmpty
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(AppSpacing.radius)),
                      child: Text('Your exported photos appear here', style: t.bodySmall),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: files.length.clamp(0, 12),
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () async {
                            if (await ref.read(editorProvider.notifier).openFile(files[i].path) && context.mounted) context.push('/editor');
                          },
                          child: Image.file(File(files[i].path), width: 96, height: 96, fit: BoxFit.cover, cacheWidth: 200, semanticLabel: 'Recent edit ${i + 1}'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(body: onboarded ? body : Stack(children: [body, const CoachOverlay()]));
  }
}
