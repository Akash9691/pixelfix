import 'dart:math' as math;
import 'dart:typed_data';

import '../core/utils/pixel_ops.dart';
import '../core/utils/tiling.dart';

typedef SegRun = Float32List Function(Float32List input);

const int selfieSize = 256;
const int touchSize = 512;
const int touchRadius = 20;

/// Soft threshold around 0.5 (values 90..166 ramp to 0..255): smooth but crisp edges.
Uint8List refineMask(Uint8List m) {
  final o = Uint8List(m.length);
  for (var i = 0; i < m.length; i++) {
    o[i] = (((m[i] - 90) * 255) ~/ 76).clamp(0, 255);
  }
  return o;
}

/// Selfie Segmenter: 256² RGB (0..1) → 256² person probability. The mask is
/// enlarged bilinearly to w×h, lightly blurred and thresholded around 0.5.
Uint8List selfieMask(Uint8List rgba, int w, int h, SegRun run) {
  final small = resizeRgba(rgba, w, h, selfieSize, selfieSize);
  final p = run(rgbaToNhwc(small, selfieSize));
  final m = Uint8List(selfieSize * selfieSize);
  for (var i = 0; i < m.length; i++) {
    m[i] = (p[i] * 255 + 0.5).floor().clamp(0, 255);
  }
  final big = resizeMask(m, selfieSize, selfieSize, w, h);
  return refineMask(blurMask(big, w, h, math.max(1, math.max(w, h) ~/ 400)));
}

/// MagicTouch input: NHWC `[512,512,4]` = rgb (0..1) + tap channel (filled disk of
/// [touchRadius] px = 1). Public for tests.
Float32List packMagicTouch(Uint8List rgba512, int tx, int ty) {
  const n = touchSize;
  final t = Float32List(n * n * 4);
  const r2 = touchRadius * touchRadius;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final i = y * n + x, o = i * 4;
      t[o] = rgba512[o] / 255;
      t[o + 1] = rgba512[o + 1] / 255;
      t[o + 2] = rgba512[o + 2] / 255;
      final dx = x - tx, dy = y - ty;
      t[o + 3] = (dx * dx + dy * dy <= r2) ? 1.0 : 0.0;
    }
  }
  return t;
}

/// Tap-to-select: the object under ([tapX],[tapY]) (image pixels) as a w×h mask.
/// Empty when nothing is found there.
Uint8List magicTouchMask(Uint8List rgba, int w, int h, int tapX, int tapY, SegRun run) {
  final small = resizeRgba(rgba, w, h, touchSize, touchSize);
  final tx = (tapX * touchSize / w).round().clamp(0, touchSize - 1);
  final ty = (tapY * touchSize / h).round().clamp(0, touchSize - 1);
  final p = run(packMagicTouch(small, tx, ty));
  final m = Uint8List(touchSize * touchSize);
  for (var i = 0; i < m.length; i++) {
    m[i] = p[i] > 0.5 ? 255 : 0;
  }
  final blob = connectedComponent(m, touchSize, touchSize, tx, ty);
  final big = resizeMask(blob, touchSize, touchSize, w, h);
  return refineMask(blurMask(big, w, h, 1));
}
