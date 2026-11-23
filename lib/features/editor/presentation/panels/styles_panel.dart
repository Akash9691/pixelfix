import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/ai_actions.dart';
import '../../application/editor_controller.dart';
import '../../domain/style_catalog.dart';

class StylesPanel extends ConsumerStatefulWidget {
  const StylesPanel({super.key});

  @override
  ConsumerState<StylesPanel> createState() => _StylesPanelState();
}

class _StylesPanelState extends ConsumerState<StylesPanel> {
  StyleSource? _style;
  StyleSource? _custom;
  double _strength = 0.8;

  void _preview() {
    if (_style != null) ref.read(aiProvider).style(_style!, _strength);
  }

  void _pick(StyleSource s) {
    setState(() => _style = s);
    _preview();
  }

  Future<void> _pickCustom() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final s = StyleSource(id: 'custom_${DateTime.now().millisecondsSinceEpoch}', name: 'My image', bytes: bytes);
    setState(() => _custom = s);
    _pick(s);
  }

  Widget _tile(String label, Widget child, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.s),
        child: Semantics(
          button: true,
          selected: sel,
          label: 'Style $label',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? AppColors.accent : Colors.white24, width: sel ? 2.5 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                  const SizedBox(height: 2),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(editorProvider.select((s) => s.pending));
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _tile('Gallery', const Center(child: Icon(Icons.add_photo_alternate_rounded)), false, _pickCustom),
                if (_custom != null)
                  _tile('My image', Image.memory(_custom!.bytes!, fit: BoxFit.cover, cacheWidth: 128), _style == _custom, () => _pick(_custom!)),
                for (final s in bundledStyles)
                  _tile(s.name, Image.asset(s.asset!, fit: BoxFit.cover, cacheWidth: 128), _style == s, () => _pick(s)),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: scheme.onSurfaceVariant),
              Expanded(
                child: Slider(
                  value: _strength,
                  min: 0.1,
                  max: 1,
                  label: 'Strength ${(_strength * 100).round()}%',
                  semanticFormatterCallback: (v) => 'Style strength ${(v * 100).round()} percent',
                  onChanged: (v) => setState(() => _strength = v),
                  onChangeEnd: (_) => _preview(),
                ),
              ),
              Text('${(_strength * 100).round()}%'),
            ],
          ),
          if (pending?.kind == 'style')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: ref.read(editorProvider.notifier).discardPending,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    // Preview was made at 384 px; Apply re-runs it at full quality.
                    onPressed: () => ref.read(aiProvider).style(_style!, _strength, full: true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Apply in full quality'),
                  ),
                ),
              ],
            )
          else
            Text(
              _style == null ? 'Pick a style to preview it on your photo.' : 'Adjust strength, then tap the style again to re-preview.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
