import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/image_io.dart';
import '../../../../ml/background_composer.dart';
import '../../application/ai_actions.dart';

class BackgroundPanel extends ConsumerStatefulWidget {
  const BackgroundPanel({super.key});

  @override
  ConsumerState<BackgroundPanel> createState() => _BackgroundPanelState();
}

class _BackgroundPanelState extends ConsumerState<BackgroundPanel> {
  static const _colors = [0xFFFFFFFF, 0xFF000000, 0xFF7C5CFF, 0xFF22D3EE, 0xFFFF5C7A, 0xFFFFC857, 0xFF3DDC97];
  static const _gradients = <(int, int)>[
    (0xFF7C5CFF, 0xFF22D3EE),
    (0xFFFF5C7A, 0xFFFFC857),
    (0xFF0E0F13, 0xFF7C5CFF),
    (0xFF3DDC97, 0xFF22D3EE),
  ];

  BgMode? _mode;
  int _blur = 24;
  int _c1 = 0xFFFFFFFF, _c2 = 0xFF000000;

  void _run({dynamic picture}) {
    ref.read(aiProvider).background(_mode!, blur: _blur, color1: _c1, color2: _c2, picture: picture);
  }

  void _setMode(BgMode m) {
    setState(() => _mode = m);
    if (m == BgMode.image) {
      _pickPhoto();
    } else {
      _run();
    }
  }

  Future<void> _pickPhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null || !mounted) return;
    final img = await decodeBytesCapped(await f.readAsBytes(), maxEdge: 2000);
    _run(picture: img);
  }

  Widget _swatch(int argb, {int? second}) {
    final sel = second == null ? (_mode == BgMode.color && _c1 == argb) : (_mode == BgMode.gradient && _c1 == argb && _c2 == second);
    return Semantics(
      button: true,
      label: second == null ? 'Solid colour' : 'Gradient',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _c1 = argb;
            if (second != null) _c2 = second;
            _mode = second == null ? BgMode.color : BgMode.gradient;
          });
          _run();
        },
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(right: AppSpacing.s),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: second == null ? Color(argb) : null,
            gradient: second == null ? null : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(argb), Color(second)]),
            border: Border.all(color: sel ? Colors.white : Colors.white24, width: sel ? 2.5 : 1),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <(BgMode, String, IconData)>[
      (BgMode.transparent, 'Remove', Icons.content_cut_rounded),
      (BgMode.blur, 'Blur', Icons.blur_on_rounded),
      (BgMode.image, 'Photo', Icons.image_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _mode == null ? 'One tap cuts the person out. Works best on portraits.' : 'Pick a new backdrop, then Apply.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (m, l, i) in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s),
                    child: ChoiceChip(
                      avatar: Icon(i, size: 18),
                      label: Text(l),
                      selected: _mode == m,
                      onSelected: (_) => _setMode(m),
                    ),
                  ),
                for (final c in _colors) _swatch(c),
                for (final g in _gradients) _swatch(g.$1, second: g.$2),
              ],
            ),
          ),
          if (_mode == BgMode.blur)
            Row(
              children: [
                const Text('Blur'),
                Expanded(
                  child: Slider(
                    min: 6,
                    max: 60,
                    value: _blur.toDouble(),
                    onChanged: (v) => setState(() => _blur = v.round()),
                    onChangeEnd: (_) => _run(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
