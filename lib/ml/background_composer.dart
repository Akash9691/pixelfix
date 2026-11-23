import 'dart:math' as math;
import 'dart:typed_data';

import '../core/utils/pixel_ops.dart';

enum BgMode { transparent, blur, color, gradient, image }

/// Blurs the RGB channels (fast: works on a downscaled copy, then enlarges).
Uint8List blurredCopy(Uint8List rgba, int w, int h, int radius) {
  final k = math.max(1, math.max(w, h) ~/ 240);
  final sw = math.max(1, w ~/ k), sh = math.max(1, h ~/ k);
  final small = resizeRgba(rgba, w, h, sw, sh);
  final r = math.max(1, radius ~/ k);
  final out = Uint8List(sw * sh * 4);
  for (var c = 0; c < 3; c++) {
    final ch = Uint8List(sw * sh);
    for (var i = 0; i < ch.length; i++) {
      ch[i] = small[i * 4 + c];
    }
    final b = blurMask(ch, sw, sh, r);
    for (var i = 0; i < b.length; i++) {
      out[i * 4 + c] = b[i];
    }
  }
  for (var i = 3; i < out.length; i += 4) {
    out[i] = 255;
  }
  return resizeRgba(out, sw, sh, w, h);
}

Uint8List _solid(int w, int h, int argb) {
  final o = Uint8List(w * h * 4);
  final r = (argb >> 16) & 255, g = (argb >> 8) & 255, b = argb & 255;
  for (var i = 0; i < w * h; i++) {
    o[i * 4] = r;
    o[i * 4 + 1] = g;
    o[i * 4 + 2] = b;
    o[i * 4 + 3] = 255;
  }
  return o;
}

Uint8List _gradient(int w, int h, int c1, int c2) {
  final o = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    final t = h <= 1 ? 0.0 : y / (h - 1);
    for (var c = 0; c < 3; c++) {
      final a = (c1 >> (16 - 8 * c)) & 255, b = (c2 >> (16 - 8 * c)) & 255;
      final v = (a + (b - a) * t).round();
      for (var x = 0; x < w; x++) {
        o[(y * w + x) * 4 + c] = v;
      }
    }
    for (var x = 0; x < w; x++) {
      o[(y * w + x) * 4 + 3] = 255;
    }
  }
  return o;
}

/// Scales [src] to cover w×h and centre-crops it.
Uint8List coverFit(Uint8List src, int sw, int sh, int w, int h) {
  final s = math.max(w / sw, h / sh);
  final cw = math.max(1, math.min(sw, (w / s).round())), ch = math.max(1, math.min(sh, (h / s).round()));
  final crop = cropChannels(src, sw, 4, IntRect((sw - cw) ~/ 2, (sh - ch) ~/ 2, cw, ch));
  return resizeRgba(crop, cw, ch, w, h);
}

/// Composites the person ([mask] > 0 keeps the foreground) over a new backdrop.
/// transparent → same size RGBA whose alpha is the mask.
Uint8List composeBackground({
  required Uint8List fg,
  required int w,
  required int h,
  required Uint8List mask,
  required BgMode mode,
  int blurRadius = 24,
  int color1 = 0xFFFFFFFF,
  int color2 = 0xFF000000,
  Uint8List? image,
  int imageW = 0,
  int imageH = 0,
}) {
  if (mode == BgMode.transparent) {
    final o = Uint8List.fromList(fg);
    for (var i = 0; i < mask.length; i++) {
      o[i * 4 + 3] = mask[i];
    }
    return o;
  }
  final bg = switch (mode) {
    BgMode.blur => blurredCopy(fg, w, h, blurRadius),
    BgMode.color => _solid(w, h, color1),
    BgMode.gradient => _gradient(w, h, color1, color2),
    BgMode.image => coverFit(image!, imageW, imageH, w, h),
    BgMode.transparent => throw StateError('handled above'),
  };
  blendRgba(bg, fg, mask);
  return bg;
}
