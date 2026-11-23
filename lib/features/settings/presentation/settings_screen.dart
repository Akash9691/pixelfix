import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../ml/model_spec.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearCache(BuildContext context) async {
    var freed = 0;
    for (final d in [await getTemporaryDirectory(), Directory('${(await getApplicationDocumentsDirectory()).path}/style_cache')]) {
      if (!await d.exists()) continue;
      for (final e in d.listSync()) {
        try {
          if (e is File) freed += await e.length();
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cache cleared (${(freed / 1048576).toStringAsFixed(1)} MB)')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final label = Theme.of(context).textTheme.labelSmall;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Text('Theme', style: label),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android_rounded), label: Text('System')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => c.setTheme(v.first),
          ),
          const SizedBox(height: AppSpacing.l),
          Text('Default export format', style: label),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'jpg', label: Text('JPG')),
              ButtonSegment(value: 'png', label: Text('PNG')),
              ButtonSegment(value: 'webp', label: Text('WebP')),
            ],
            selected: {s.exportFormat},
            onSelectionChanged: (v) => c.setFormat(v.first),
          ),
          const SizedBox(height: AppSpacing.l),
          Text('Processing mode', style: label),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<ProcessingMode>(
            segments: const [
              ButtonSegment(value: ProcessingMode.auto, label: Text('Auto')),
              ButtonSegment(value: ProcessingMode.gpu, label: Text('GPU')),
              ButtonSegment(value: ProcessingMode.cpu, label: Text('CPU')),
            ],
            selected: {s.processing},
            onSelectionChanged: (v) => c.setProcessing(v.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Auto tries the GPU first and falls back to the CPU. Changing this reloads the models.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: AppSpacing.xl),
          ListTile(
            leading: const Icon(Icons.memory_rounded),
            title: const Text('AI Models'),
            subtitle: const Text('Sizes, tasks, delegate and speed'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/models'),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: const Text('Clear cache'),
            subtitle: const Text('Temporary undo files and cached style data'),
            onTap: () => _clearCache(context),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licences'),
            subtitle: const Text('Open-source and model licences'),
            onTap: () => showLicensePage(context: context, applicationName: 'PixelFix', applicationVersion: '1.0.0'),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text(
                      'Your photos never leave your phone. Every AI model runs on-device and the app works fully offline.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          const _ModelLicences(),
        ],
      ),
    );
  }
}

class _ModelLicences extends StatelessWidget {
  const _ModelLicences();

  @override
  Widget build(BuildContext context) {
    const items = [
      'MI-GAN (Picsart AI Research, ICCV 2023): MIT',
      'MediaPipe Selfie Segmenter and MagicTouch (Google): Apache-2.0',
      'Real-ESRGAN General x4v3 (xinntao; Qualcomm AI Hub build): BSD-3-Clause',
      'Magenta Arbitrary Image Stylization (Google): Apache-2.0',
      'Style images: public-domain paintings (Wikimedia Commons)',
      'Inter typeface: SIL Open Font Licence 1.1',
    ];
    return ExpansionTile(
      title: const Text('Model licences'),
      children: [for (final i in items) ListTile(dense: true, title: Text(i))],
    );
  }
}
