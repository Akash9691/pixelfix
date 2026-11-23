import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../settings/application/settings_controller.dart';

/// 3-step coach mark shown on first launch only.
class CoachOverlay extends ConsumerStatefulWidget {
  const CoachOverlay({super.key});

  @override
  ConsumerState<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends ConsumerState<CoachOverlay> {
  int _step = 0;

  static const _steps = <(IconData, String, String)>[
    (Icons.photo_library_rounded, 'Open a photo', 'Pick one from your gallery or take a new one. It never leaves your phone.'),
    (Icons.auto_fix_high_rounded, 'Choose an AI tool', 'Erase objects, expand, remove backgrounds, upscale or paint with art styles.'),
    (Icons.touch_app_rounded, 'Preview, then Apply', 'Hold the photo to see the original. Everything can be undone.'),
  ];

  void _next() {
    if (_step == _steps.length - 1) {
      ref.read(settingsProvider.notifier).finishOnboarding();
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, title, text) = _steps[_step];
    final t = Theme.of(context).textTheme;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                liveRegion: true,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 48, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(height: AppSpacing.m),
                        Text(title, style: t.titleLarge, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.s),
                        Text(text, style: t.bodyMedium, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.m),
                        Text('${_step + 1} / ${_steps.length}', style: t.labelSmall),
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          children: [
                            TextButton(
                              onPressed: ref.read(settingsProvider.notifier).finishOnboarding,
                              child: const Text('Skip'),
                            ),
                            const Spacer(),
                            FilledButton(onPressed: _next, child: Text(_step == _steps.length - 1 ? 'Got it' : 'Next')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
