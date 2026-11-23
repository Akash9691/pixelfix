import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/ai_actions.dart';
import '../../application/canvas_view.dart';
import '../../application/editor_controller.dart';
import '../../application/mask_controller.dart';
import '../../domain/editor_state.dart';

/// Photo canvas: pinch-zoom/pan with two fingers, one finger paints the mask
/// (Erase / Select tools). Double-tap fits, press-and-hold shows the original.
class EditorCanvas extends ConsumerStatefulWidget {
  const EditorCanvas({super.key});

  @override
  ConsumerState<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<EditorCanvas> {
  final _pointers = <int, Offset>{};
  final _cursor = ValueNotifier<Offset?>(null);
  Offset? _downPos;
  DateTime _downTime = DateTime.now();
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  bool _stroking = false, _moved = false, _holdActive = false;
  double _lastDist = 0;
  Offset _lastMid = Offset.zero, _lastPos = Offset.zero;
  Timer? _hold;
  ui.Image? _checker;

  EditorController get _c => ref.read(editorProvider.notifier);
  CanvasView get _view => _c.view;
  MaskController get _mask => _c.mask;

  @override
  void initState() {
    super.initState();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const s = 12.0;
    c.drawRect(const Rect.fromLTWH(0, 0, 2 * s, 2 * s), Paint()..color = const Color(0xFF2A2C34));
    final p = Paint()..color = const Color(0xFF3A3D47);
    c.drawRect(const Rect.fromLTWH(0, 0, s, s), p);
    c.drawRect(const Rect.fromLTWH(s, s, s, s), p);
    final pic = rec.endRecording();
    _checker = pic.toImageSync(24, 24);
    pic.dispose();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _checker?.dispose();
    _cursor.dispose();
    super.dispose();
  }

  bool get _paintTool {
    final s = ref.read(editorProvider);
    return (s.tool == EditorTool.erase || s.tool == EditorTool.select) && s.pending == null;
  }

  void _beginStroke(Offset screen) {
    final s = ref.read(editorProvider);
    _mask.begin(_view.toImage(screen), s.brushDp / _view.scale, s.eraserMode);
    _stroking = true;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _downPos = e.localPosition;
      _lastPos = e.localPosition;
      _downTime = DateTime.now();
      _moved = false;
      final tool = ref.read(editorProvider).tool;
      if (_paintTool && tool == EditorTool.erase) {
        _beginStroke(e.localPosition);
        _cursor.value = e.localPosition;
      } else if (!_paintTool || tool == EditorTool.select) {
        _hold?.cancel();
        _hold = Timer(const Duration(milliseconds: 450), () {
          if (!_moved && _pointers.length == 1 && !_stroking) {
            _holdActive = true;
            _c.setComparing(true);
          }
        });
      }
    } else {
      // Second finger: abort a just-started stroke and switch to zoom/pan.
      if (_stroking) {
        _mask.end();
        if (DateTime.now().difference(_downTime).inMilliseconds < 250) _mask.undoStroke();
        _stroking = false;
      }
      _hold?.cancel();
      _cursor.value = null;
      _resetPinch();
    }
  }

  void _resetPinch() {
    if (_pointers.length >= 2) {
      final a = _pointers.values.elementAt(0), b = _pointers.values.elementAt(1);
      _lastDist = (a - b).distance;
      _lastMid = (a + b) / 2;
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2) {
      final a = _pointers.values.elementAt(0), b = _pointers.values.elementAt(1);
      final d = (a - b).distance, mid = (a + b) / 2;
      if (_lastDist > 0) _view.zoom(d / _lastDist, mid, mid - _lastMid);
      _lastDist = d;
      _lastMid = mid;
      return;
    }
    final p = e.localPosition;
    if (!_moved && (p - (_downPos ?? p)).distance > 8) {
      _moved = true;
      _hold?.cancel();
      if (_holdActive) {
        _holdActive = false;
        _c.setComparing(false);
      }
      if (_paintTool && !_stroking) _beginStroke(_downPos!); // Select tool: drag = brush
    }
    if (_stroking) {
      _mask.extend(_view.toImage(p));
      _cursor.value = p;
    } else if (_moved && !_paintTool) {
      _view.zoom(1, p, p - _lastPos);
    }
    _lastPos = p;
  }

  void _up(PointerUpEvent e) {
    final wasOne = _pointers.length == 1;
    _pointers.remove(e.pointer);
    _hold?.cancel();
    if (_holdActive) {
      _holdActive = false;
      _c.setComparing(false);
    }
    if (_stroking) {
      _mask.end();
      _stroking = false;
    }
    _cursor.value = null;
    if (wasOne && !_moved) {
      final now = DateTime.now();
      if (now.difference(_lastTap).inMilliseconds < 300) {
        _view.fit();
        _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
      } else {
        _lastTap = now;
        final s = ref.read(editorProvider);
        if (s.tool == EditorTool.select && s.pending == null && now.difference(_downTime).inMilliseconds < 300) {
          ref.read(aiProvider).selectAt(_view.toImage(e.localPosition));
        }
      }
    }
    if (_pointers.length == 1) _lastPos = _pointers.values.first;
    _resetPinch();
  }

  void _cancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    _hold?.cancel();
    if (_stroking) {
      _mask.end();
      _stroking = false;
    }
    if (_holdActive) {
      _holdActive = false;
      _c.setComparing(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editorProvider);
    final img = s.shown;
    if (img == null) return const SizedBox.expand();
    return LayoutBuilder(builder: (context, box) {
      _view.configure(box.biggest, Size(img.width.toDouble(), img.height.toDouble()));
      return Semantics(
        label: 'Photo canvas. One finger paints, two fingers zoom, double tap to fit.',
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: ClipRect(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _CanvasPainter(
                  image: img,
                  checker: _checker!,
                  view: _view,
                  mask: _mask,
                  cursor: _cursor,
                  showMask: _paintToolOf(s) && !s.comparing,
                  brushDp: s.brushDp,
                  eraser: s.eraserMode,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  bool _paintToolOf(EditorState s) => (s.tool == EditorTool.erase || s.tool == EditorTool.select) && s.pending == null;
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.image,
    required this.checker,
    required this.view,
    required this.mask,
    required this.cursor,
    required this.showMask,
    required this.brushDp,
    required this.eraser,
  }) : super(repaint: Listenable.merge([view, mask, cursor]));

  final ui.Image image, checker;
  final CanvasView view;
  final MaskController mask;
  final ValueNotifier<Offset?> cursor;
  final bool showMask, eraser;
  final double brushDp;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.save();
    canvas.translate(view.offset.dx, view.offset.dy);
    canvas.scale(view.scale);
    // checkerboard (shows transparency from Background Studio)
    final shader = ImageShader(checker, TileMode.repeated, TileMode.repeated, Matrix4.diagonal3Values(1 / view.scale, 1 / view.scale, 1).storage);
    canvas.drawRect(dst, Paint()..shader = shader);
    canvas.drawImageRect(image, dst, dst, Paint()..filterQuality = FilterQuality.medium);
    if (showMask && !mask.isEmpty) {
      canvas.saveLayer(dst, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.55));
      mask.paintInto(canvas, dst, AppColors.accent);
      canvas.restore();
    }
    canvas.restore();
    final c = cursor.value;
    if (c != null) {
      canvas.drawCircle(
        c,
        brushDp / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = eraser ? AppColors.danger : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.image != image || old.showMask != showMask || old.eraser != eraser || old.brushDp != brushDp;
}
