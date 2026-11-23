import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ml/model_registry.dart';
import '../../../ml/model_spec.dart';
import '../../editor/application/editor_controller.dart';

class AiModelsScreen extends ConsumerWidget {
  const AiModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(registryProvider);
    final total = modelSpecs.values.fold<double>(0, (a, m) => a + m.sizeMb);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Models')),
      body: ListenableBuilder(
        listenable: reg,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            Text(
              'Models load only when a tool is first used (max ${2} in memory). Total bundled: ${total.toStringAsFixed(1)} MB.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.m),
            for (final m in modelSpecs.values) ...[
              _ModelCard(spec: m, stats: reg.stats[m.id]!),
              const SizedBox(height: AppSpacing.s),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.spec, required this.stats});
  final ModelSpec spec;
  final ModelStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              SizedBox(width: 110, child: Text(k, style: t.bodySmall?.copyWith(color: muted))),
              Expanded(child: Text(v, style: t.bodySmall)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(spec.name, style: t.titleMedium)),
                Chip(
                  label: Text(stats.loaded ? 'Loaded' : 'Not loaded'),
                  side: BorderSide(color: stats.loaded ? AppColors.ai : Colors.transparent),
                ),
              ],
            ),
            row('Task', spec.task),
            row('Size', '${spec.sizeMb} MB'),
            row('Input', spec.inputSize),
            row('Delegate', stats.delegate),
            row('Last inference', stats.lastMs == 0 ? 'not run yet' : '${stats.lastMs.round()} ms'),
          ],
        ),
      ),
    );
  }
}
