import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/projects_repository.dart';
import '../../editor/application/editor_controller.dart';

class MyEditsScreen extends ConsumerWidget {
  const MyEditsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, File f) async {
    if (await ref.read(editorProvider.notifier).openFile(f.path) && context.mounted) context.push('/editor');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this edit?'),
        content: const Text('This removes it from My Edits. Copies saved to your gallery stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(projectsRepoProvider).delete(f);
      ref.invalidate(editsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edits = ref.watch(editsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Edits')),
      body: edits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load edits: $e')),
        data: (files) {
          if (files.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.m),
                    Text('No saved edits yet', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.s),
                    const Text('Export a photo from the editor and it will show up here.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.m),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.s,
              crossAxisSpacing: AppSpacing.s,
            ),
            itemCount: files.length,
            itemBuilder: (_, i) {
              final f = files[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InkWell(
                      onTap: () => _open(context, ref, f),
                      child: Image.file(f, fit: BoxFit.cover, cacheWidth: 400, semanticLabel: 'Saved edit ${i + 1}'),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Share',
                            icon: const Icon(Icons.share_rounded, size: 20),
                            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(f.path)])),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            onPressed: () => _delete(context, ref, f),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
