import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/ai_button.dart';
import '../../application/ai_actions.dart';
import '../../application/editor_controller.dart';

class ExpandPanel extends ConsumerStatefulWidget {
  const ExpandPanel({super.key});

  @override
  ConsumerState<ExpandPanel> createState() => _ExpandPanelState();
}

class _ExpandPanelState extends ConsumerState<ExpandPanel> {
  static const _presets = <(String, double)>[('1:1', 1), ('4:5', 4 / 5), ('16:9', 16 / 9), ('9:16', 9 / 16)];
  double _aspect = 1;
  String _label = '1:1';

  Future<void> _custom() async {
    final w = TextEditingController(text: '3'), h = TextEditingController(text: '2');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom ratio'),
        content: Row(
          children: [
            Expanded(child: TextField(controller: w, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width'))),
            const Padding(padding: EdgeInsets.all(8), child: Text(':')),
            Expanded(child: TextField(controller: h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set')),
        ],
      ),
    );
    final a = double.tryParse(w.text), b = double.tryParse(h.text);
    if (ok == true && a != null && b != null && a > 0 && b > 0) {
      setState(() {
        _aspect = (a / b).clamp(0.2, 5.0);
        _label = '${w.text}:${h.text}';
      });
    }
    w.dispose();
    h.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = ref.watch(editorProvider.select((s) => s.image));
    final plan = img == null ? null : AiActions.planOf(img, _aspect);
    final scheme = Theme.of(context).colorScheme;
    final sizeText = (img == null || plan == null)
        ? 'The photo already has this shape.'
        : 'New size: ${img.width + plan[0] + plan[2]} × ${img.height + plan[1] + plan[3]} px (max 50% per side)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s,
            children: [
              for (final (l, a) in _presets)
                ChoiceChip(
                  label: Text(l),
                  selected: _label == l,
                  onSelected: (_) => setState(() {
                    _aspect = a;
                    _label = l;
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: Text(_presets.any((p) => p.$1 == _label) ? 'Custom' : _label),
                onPressed: _custom,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(sizeText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          Text(
            'Works best with simple backgrounds (sky, walls, sand, water).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.s),
          AiButton(
            label: 'Expand image',
            icon: Icons.open_in_full_rounded,
            onPressed: plan == null ? null : () => ref.read(aiProvider).expand(_aspect),
          ),
        ],
      ),
    );
  }
}
