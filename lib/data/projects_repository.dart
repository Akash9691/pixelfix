import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Saved results ("My Edits") live in the app documents folder.
class ProjectsRepository {
  Future<Directory> _dir() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/edits').create(recursive: true);

  Future<File> save(Uint8List bytes, String ext) async {
    final f = File('${(await _dir()).path}/pixelfix_${DateTime.now().millisecondsSinceEpoch}.$ext');
    return f.writeAsBytes(bytes, flush: true);
  }

  /// Newest first.
  Future<List<File>> list() async {
    final files = (await _dir()).listSync().whereType<File>().toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<void> delete(File f) async {
    if (await f.exists()) await f.delete();
  }
}

final projectsRepoProvider = Provider((ref) => ProjectsRepository());

final editsProvider = FutureProvider.autoDispose<List<File>>((ref) => ref.read(projectsRepoProvider).list());
