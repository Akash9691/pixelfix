import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/ai_actions.dart';
import '../../application/editor_controller.dart';
import '../../domain/editor_state.dart';

/// One-tap pipelines built from the other tools.
class CombosPanel extends ConsumerWidget {
  const CombosPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.read(aiProvider);
    final c = ref.read(editorProvider.notifier);
    final cards = <(String, String, String, IconData, VoidCallback)>[
      ('Remove person', 'Select person → Erase', 'Cuts out the main person and fills the gap.', Icons.person_remove_rounded, ai.removePerson),
      (
        'Old photo fix',
        'Erase scratches → Upscale 2×',
        'Brush over scratches first (Erase tool).',
        Icons.history_edu_rounded,
        () {
          if (c.mask.isEmpty) {
            c.toast('Brush over the scratches first, then come back');
            c.setTool(EditorTool.erase);
            return;
          }
          ai.oldPhotoFix();
        }
      ),
      ('Insta fit', 'Expand to 4:5 → Upscale 2×', 'Makes any photo a crisp Instagram portrait.', Icons.crop_portrait_rounded, ai.instaFit),
    ];
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpacing.m),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (_, i) {
          final (title, chain, desc, icon, run) = cards[i];
          return SizedBox(
            width: 220,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
                onTap: run,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(icon, color: AppColors.ai),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1)),
                      ]),
                      const SizedBox(height: 4),
                      Text(chain, style: const TextStyle(fontSize: 12, color: AppColors.ai)),
                      const SizedBox(height: 4),
                      Expanded(child: Text(desc, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.fade)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
