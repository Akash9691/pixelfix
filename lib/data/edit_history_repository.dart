import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../core/utils/image_io.dart';

/// Undo / redo stored as PNG files in the temp directory (not in RAM).
/// Keeps at most [maxSteps] undo steps.
class EditHistory {
  EditHistory({this.maxSteps = 20});

  final int maxSteps;
  final _undo = <File>[];
  final _redo = <File>[];
  Directory? _dir;
  int _n = 0;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoCount => _undo.length;

  Future<Directory> _ensure() async {
    return _dir ??= await Directory('${(await getTemporaryDirectory()).path}/history_${DateTime.now().millisecondsSinceEpoch}')
        .create(recursive: true);
  }

  Future<File> _write(ui.Image img) async {
    final d = await _ensure();
    final f = File('${d.path}/${_n++}.png');
    await f.writeAsBytes(await imageToPng(img), flush: true);
    return f;
  }

  /// Records [before] (the image about to be replaced). Clears redo.
  Future<void> push(ui.Image before) async {
    _undo.add(await _write(before));
    _deleteAll(_redo);
    while (_undo.length > maxSteps) {
      _undo.removeAt(0).delete().ignore();
    }
  }

  /// Returns the previous image; [current] goes onto the redo stack.
  Future<ui.Image?> undo(ui.Image current) async {
    if (_undo.isEmpty) return null;
    _redo.add(await _write(current));
    final f = _undo.removeLast();
    final img = await _read(f);
    f.delete().ignore();
    return img;
  }

  Future<ui.Image?> redo(ui.Image current) async {
    if (_redo.isEmpty) return null;
    _undo.add(await _write(current));
    final f = _redo.removeLast();
    final img = await _read(f);
    f.delete().ignore();
    return img;
  }

  Future<ui.Image> _read(File f) async => decodeBytesCapped(await f.readAsBytes(), maxEdge: 8192);

  void _deleteAll(List<File> l) {
    for (final f in l) {
      f.delete().ignore();
    }
    l.clear();
  }

  Future<void> clear() async {
    _deleteAll(_undo);
    _deleteAll(_redo);
    final d = _dir;
    _dir = null;
    if (d != null && await d.exists()) await d.delete(recursive: true);
  }
}
