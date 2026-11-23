import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/image_io.dart';
import '../../../data/edit_history_repository.dart';
import '../../../ml/inference_worker.dart';
import '../../../ml/model_registry.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/editor_state.dart';
import 'canvas_view.dart';
import 'mask_controller.dart';

final registryProvider = Provider<ModelRegistry>((ref) {
  final r = ModelRegistry(mode: ref.read(settingsProvider).processing);
  ref.listen(settingsProvider.select((s) => s.processing), (_, m) => r.setMode(m));
  ref.onDispose(r.dispose);
  return r;
});

final editorProvider = NotifierProvider<EditorController, EditorState>(EditorController.new);

typedef ProgressFn = void Function(String label, double? value);

class EditorController extends Notifier<EditorState> {
  final history = EditHistory();
  final mask = MaskController();
  final view = CanvasView();
  CancelToken? _token;
  int _toastId = 0;
  String? sourceName;

  @override
  EditorState build() {
    ref.onDispose(() {
      state.image?.dispose();
      state.original?.dispose();
      state.pending?.image.dispose();
      history.clear();
      mask.dispose();
      view.dispose();
    });
    return const EditorState();
  }

  // ---- loading -------------------------------------------------------------

  /// Opens a photo, capped at 3000 px on the long edge.
  Future<bool> openFile(String path) async {
    try {
      final img = await decodeBytesCapped(await File(path).readAsBytes());
      sourceName = path.split(RegExp(r'[\\/]')).last;
      await _reset(img);
      return true;
    } catch (e) {
      state = state.copyWith(toast: Toast(++_toastId, 'Could not open this image', error: true));
      return false;
    }
  }

  Future<void> _reset(ui.Image img) async {
    state.image?.dispose();
    state.original?.dispose();
    state.pending?.image.dispose();
    mask.clear();
    await history.clear();
    state = EditorState(image: img, original: img.clone());
  }

  // ---- state helpers -------------------------------------------------------

  void toast(String text, {bool error = false}) => state = state.copyWith(toast: Toast(++_toastId, text, error: error));

  void setTool(EditorTool t) {
    if (t == state.tool) return;
    HapticFeedback.selectionClick();
    discardPending();
    state = state.copyWith(tool: t, hint: () => null);
  }

  void setBrush(double dp) => state = state.copyWith(brushDp: dp);
  void setEraserMode(bool v) => state = state.copyWith(eraserMode: v);
  void setComparing(bool v) {
    if (state.comparing != v && state.original != null) state = state.copyWith(comparing: v);
  }

  void setHint(String? h) => state = state.copyWith(hint: () => h);

  // ---- pending / history ---------------------------------------------------

  void setPending(ui.Image img, String kind) {
    state.pending?.image.dispose();
    state = state.copyWith(pending: () => Pending(img, kind));
  }

  void discardPending() {
    final p = state.pending;
    if (p == null) return;
    p.image.dispose();
    state = state.copyWith(pending: () => null, hint: () => null);
  }

  /// Makes the pending result the current image; the old one goes to undo.
  Future<void> applyPending() async {
    final p = state.pending, cur = state.image;
    if (p == null || cur == null) return;
    HapticFeedback.mediumImpact();
    await history.push(cur);
    cur.dispose();
    if (p.kind == 'erase') mask.clear();
    state = state.copyWith(
      image: p.image,
      pending: () => null,
      canUndo: history.canUndo,
      canRedo: history.canRedo,
      hint: () => null,
    );
  }

  Future<void> undo() async {
    final cur = state.image;
    if (cur == null || state.busy != null) return;
    discardPending();
    final prev = await history.undo(cur);
    if (prev == null) return;
    cur.dispose();
    state = state.copyWith(image: prev, canUndo: history.canUndo, canRedo: history.canRedo);
  }

  Future<void> redo() async {
    final cur = state.image;
    if (cur == null || state.busy != null) return;
    discardPending();
    final next = await history.redo(cur);
    if (next == null) return;
    cur.dispose();
    state = state.copyWith(image: next, canUndo: history.canUndo, canRedo: history.canRedo);
  }

  // ---- jobs ----------------------------------------------------------------

  void cancelJob() => _token?.cancel();

  /// Runs [job] with a busy overlay, cancellation, error toasts and a timing toast.
  Future<T?> runJob<T>(
    String label,
    Future<T> Function(CancelToken token, ProgressFn progress) job, {
    bool timing = true,
  }) async {
    if (state.busy != null) return null;
    final token = _token = CancelToken();
    final sw = Stopwatch()..start();
    state = state.copyWith(busy: () => BusyInfo(label));
    try {
      final r = await job(token, (l, v) => state = state.copyWith(busy: () => BusyInfo(l, progress: v)));
      if (timing) {
        toast('Processed on-device in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} s');
      }
      return r;
    } on CancelledException {
      toast('Cancelled');
    } on WorkerException catch (e) {
      toast('AI step failed: ${e.message.split('\n').first}', error: true);
    } on OutOfMemoryError {
      toast('Not enough memory for this image. Try a smaller photo.', error: true);
    } catch (e) {
      toast('Something went wrong: $e', error: true);
    } finally {
      _token = null;
      state = state.copyWith(busy: () => null);
    }
    return null;
  }

  // ---- export --------------------------------------------------------------

  /// Encodes the current image. [scale] < 1 shrinks it (GPU scaling).
  Future<Uint8List?> encode(String format, int quality, {double scale = 1}) async {
    final img = state.image;
    if (img == null) return null;
    var src = img;
    var owned = false;
    if (scale < 1) {
      src = await scaledCopy(img, (math.max(img.width, img.height) * scale).round());
      owned = true;
    }
    try {
      return await NativeCodec.encode(await imageToPng(src), format, quality);
    } finally {
      if (owned) src.dispose();
    }
  }
}
