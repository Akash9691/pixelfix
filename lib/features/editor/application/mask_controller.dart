import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/utils/image_io.dart';

class Stroke {
  Stroke(this.path, this.width, this.erase);
  final Path path;

  /// Width in image pixels.
  final double width;
  final bool erase;
}

/// The user's selection: an optional bitmap base (from Tap-to-Select) plus brush
/// strokes stored as vector paths (one Path per stroke, never a bitmap per stroke).
/// Extends [ChangeNotifier] so only the canvas painter repaints while painting.
class MaskController extends ChangeNotifier {
  ui.Image? base;
  final strokes = <Stroke>[];
  Stroke? _current;
  Offset _last = Offset.zero;

  Stroke? get current => _current;
  bool get isEmpty => base == null && strokes.isEmpty;

  void begin(Offset p, double width, bool erase) {
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..lineTo(p.dx + 0.01, p.dy);
    _current = Stroke(path, width, erase);
    strokes.add(_current!);
    _last = p;
    notifyListeners();
  }

  void extend(Offset p) {
    final s = _current;
    if (s == null) return;
    // quadratic smoothing through midpoints
    final mid = Offset((_last.dx + p.dx) / 2, (_last.dy + p.dy) / 2);
    s.path.quadraticBezierTo(_last.dx, _last.dy, mid.dx, mid.dy);
    _last = p;
    notifyListeners();
  }

  void end() {
    _current = null;
    notifyListeners();
  }

  void undoStroke() {
    if (strokes.isNotEmpty) {
      strokes.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    base?.dispose();
    base = null;
    strokes.clear();
    _current = null;
    notifyListeners();
  }

  /// Adds a Tap-to-Select overlay (RGBA, alpha = selected) to the bitmap base.
  Future<void> mergeBase(ui.Image overlay) async {
    final old = base;
    if (old == null) {
      base = overlay;
    } else {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawImage(old, Offset.zero, Paint());
      c.drawImage(overlay, Offset.zero, Paint());
      final pic = rec.endRecording();
      base = await pic.toImage(old.width, old.height);
      pic.dispose();
      old.dispose();
      overlay.dispose();
    }
    notifyListeners();
  }

  /// Draws the selection (base + strokes) on [c]; used by both the on-screen
  /// overlay and [rasterize].
  void paintInto(Canvas c, Rect bounds, Color color) {
    c.saveLayer(bounds, Paint());
    if (base != null) {
      c.drawImage(base!, Offset.zero, Paint());
    }
    for (final s in strokes) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.width
        ..color = color
        ..blendMode = s.erase ? BlendMode.clear : BlendMode.srcOver;
      c.drawPath(s.path, p);
    }
    c.restore();
  }

  /// RGBA bytes (w×h) whose alpha channel is the selection mask.
  Future<Uint8List> rasterize(int w, int h) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    paintInto(c, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Colors.white);
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    final bytes = await imageToRgba(img);
    img.dispose();
    return bytes;
  }

  @override
  void dispose() {
    base?.dispose();
    super.dispose();
  }
}
