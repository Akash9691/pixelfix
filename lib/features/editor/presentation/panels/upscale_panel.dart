import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../../../ml/upscaler.dart';
import '../../application/ai_actions.dart';
import '../../application/editor_controller.dart';

class UpscalePanel extends ConsumerStatefulWidget {
  const UpscalePanel({super.key});

  @override
  ConsumerState<UpscalePanel> createState() => _UpscalePanelState();
}

class _UpscalePanelState extends ConsumerState<UpscalePanel> {
  int _scale = 2;

  @override
  Widget build(BuildContext context) {
    final img = ref.watch(editorProvider.select((s) => s.image));
    final plan = img == null ? null : planUpscale(img.width, img.height, _scale);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 2, label: Text('2×')), ButtonSegment(value: 4, label: Text('4×'))],
            selected: {_scale},
            onSelectionChanged: (v) => setState(() => _scale = v.first),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            plan == null
                ? ''
                : 'Result: ${plan.outW} × ${plan.outH} px (long edge max 4096). Large photos take a while; you can cancel.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.s),
          AiButton(label: 'Upscale $_scale×', icon: Icons.hd_rounded, onPressed: () => ref.read(aiProvider).upscale(_scale)),
        ],
      ),
    );
  }
}
