import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/projects_repository.dart';
import '../../editor/application/editor_controller.dart';
import '../../settings/application/settings_controller.dart';

Future<void> showExportSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExportSheet(),
    );

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  late String _format = ref.read(settingsProvider).exportFormat;
  double _quality = 90;
  double _scale = 1;
  bool _busy = false;

  Future<Uint8List?> _encode() => ref.read(editorProvider.notifier).encode(_format, _quality.round(), scale: _scale);

  void _msg(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
    setState(() => _busy = true);
    try {
      final bytes = await _encode();
      if (bytes != null) await action(bytes);
    } catch (e) {
      _msg('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() => _run((b) async {
        if (!await Gal.hasAccess()) await Gal.requestAccess();
        await Gal.putImageBytes(b, name: 'pixelfix_${DateTime.now().millisecondsSinceEpoch}.${_format == 'jpg' ? 'jpg' : _format}');
        await ref.read(projectsRepoProvider).save(b, _format);
        ref.invalidate(editsProvider);
        _msg('Saved to your gallery');
        if (mounted) Navigator.pop(context);
      });

  Future<void> _share() => _run((b) async {
        final f = File('${(await getTemporaryDirectory()).path}/pixelfix_share.$_format');
        await f.writeAsBytes(b, flush: true);
        await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
      });

  Future<void> _myEdits() => _run((b) async {
        await ref.read(projectsRepoProvider).save(b, _format);
        ref.invalidate(editsProvider);
        _msg('Saved to My Edits');
        if (mounted) Navigator.pop(context);
      });

  @override
  Widget build(BuildContext context) {
    final img = ref.read(editorProvider).image;
    final w = ((img?.width ?? 0) * _scale).round(), h = ((img?.height ?? 0) * _scale).round();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.m, AppSpacing.m + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            Text('Format', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'jpg', label: Text('JPG')),
                ButtonSegment(value: 'png', label: Text('PNG')),
                ButtonSegment(value: 'webp', label: Text('WebP')),
              ],
              selected: {_format},
              onSelectionChanged: (v) => setState(() => _format = v.first),
            ),
            if (_format != 'png') ...[
              const SizedBox(height: AppSpacing.m),
              Text('Quality ${_quality.round()}', style: Theme.of(context).textTheme.labelSmall),
              Slider(min: 50, max: 100, divisions: 50, value: _quality, onChanged: (v) => setState(() => _quality = v)),
            ],
            const SizedBox(height: AppSpacing.s),
            Text('Resolution', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.s,
              children: [
                ChoiceChip(label: Text('Full  ${img?.width} × ${img?.height}'), selected: _scale == 1, onSelected: (_) => setState(() => _scale = 1)),
                ChoiceChip(label: const Text('Half'), selected: _scale == 0.5, onSelected: (_) => setState(() => _scale = 0.5)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Output: $w × $h px', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.m),
            if (_busy)
              const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.m), child: CircularProgressIndicator()))
            else ...[
              FilledButton.icon(onPressed: _gallery, icon: const Icon(Icons.download_rounded), label: const Text('Save to Gallery')),
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share_rounded), label: const Text('Share'))),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(child: OutlinedButton.icon(onPressed: _myEdits, icon: const Icon(Icons.bookmark_add_rounded), label: const Text('My Edits'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
