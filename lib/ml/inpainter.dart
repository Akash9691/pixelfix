import 'dart:math' as math;
import 'dart:typed_data';

import '../core/utils/pixel_ops.dart';

/// Runs the MI-GAN network: input `[1,4,512,512]` floats, output `[1,3,512,512]`.
typedef MiganRun = Float32List Function(Float32List input);

const int miganSize = 512;

/// Packs one 512×512 window into the MI-GAN input tensor (NCHW).
///
/// [rgba] is the window as 8-bit RGBA, [hole] marks pixels to fill (255 = hole).
/// Channels: 0 = known − 0.5 (known = 1 keep / 0 hole, per the model card),
/// 1..3 = rgb in [-1,1] multiplied by known.
Float32List packMigan(Uint8List rgba, Uint8List hole) {
  const n = miganSize, plane = n * n;
  final t = Float32List(4 * plane);
  for (var i = 0; i < plane; i++) {
    final known = hole[i] > 127 ? 0.0 : 1.0;
    t[i] = known - 0.5;
    t[plane + i] = (rgba[i * 4] / 127.5 - 1) * known;
    t[2 * plane + i] = (rgba[i * 4 + 1] / 127.5 - 1) * known;
    t[3 * plane + i] = (rgba[i * 4 + 2] / 127.5 - 1) * known;
  }
  return t;
}

/// Converts the NCHW `[-1,1]` output back to 8-bit RGBA (alpha 255).
Uint8List unpackMigan(Float32List out) {
  const plane = miganSize * miganSize;
  final rgba = Uint8List(plane * 4);
  for (var i = 0; i < plane; i++) {
    for (var c = 0; c < 3; c++) {
      rgba[i * 4 + c] = ((out[c * plane + i] + 1) * 127.5 + 0.5).floor().clamp(0, 255);
    }
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}

class InpaintResult {
  InpaintResult(this.rgba, this.windows, this.largeMask);
  final Uint8List rgba;
  final int windows;

  /// True when a hole covered more than 40 % of a window (quality drops).
  final bool largeMask;
}

/// Crop → run → composite inpainting. Never resizes the whole photo: only a
/// square window around the hole goes through the 512×512 network, and only
/// masked pixels (feathered) are written back at full resolution.
class Inpainter {
  Inpainter(this.run);
  final MiganRun run;

  /// Window layout for a dilated mask with bounds [b] inside a [w]×[h] image.
  /// Public for tests. A single window is used when the hole fits; otherwise
  /// windows overlap by 50 %.
  static List<IntRect> planWindows(IntRect b, int w, int h, {int? side}) {
    final minDim = math.min(w, h);
    final s = math.min(minDim, side ?? math.min(1536, math.max(miganSize, (math.max(b.w, b.h) * 2.0).round())));
    List<int> axis(int start, int len, int dim) {
      if (len <= s * 0.7) {
        return [(start + len / 2 - s / 2).round().clamp(0, dim - s)];
      }
      final step = s ~/ 2;
      final pos = <int>[];
      var p = start - s ~/ 4;
      while (true) {
        pos.add(p.clamp(0, dim - s));
        if (p + s >= start + len) break;
        p += step;
      }
      return pos.toSet().toList();
    }

    return [
      for (final y in axis(b.y, b.h, h))
        for (final x in axis(b.x, b.w, w)) IntRect(x, y, s, s),
    ];
  }

  /// Fills the pixels where [mask] > 127 in [rgba] (w×h). [mask] is not modified.
  /// [onWindow] is awaited between windows (progress + cancellation).
  Future<InpaintResult> inpaint(
    Uint8List rgba,
    int w,
    int h,
    Uint8List mask, {
    int? dilate,
    int feather = 4,
    int? windowSide,
    Future<void> Function(int done, int total)? onWindow,
  }) async {
    final out = Uint8List.fromList(rgba);
    final raw = maskBounds(mask, w, h);
    if (raw.isEmpty) return InpaintResult(out, 0, false);
    final d = dilate ?? math.max(6, math.min(10, (math.max(w, h) / 300).round()));
    final md = dilateMask(mask, w, h, d, bounds: raw);
    final bounds = clampRect(inflateRect(raw, d), w, h);
    final wins = planWindows(bounds, w, h, side: windowSide);
    var large = false;
    var done = 0;
    for (final win in wins) {
      final sub = cropChannels(md, w, 1, win);
      final cnt = maskCount(sub);
      if (cnt > 0) {
        if (cnt > 0.4 * win.w * win.h) large = true;
        _fillWindow(out, w, win, sub, feather);
        // Pixels inside the window are now filled: drop them from the mask.
        pasteChannels(md, w, 1, win, Uint8List(win.w * win.h));
      }
      done++;
      await onWindow?.call(done, wins.length);
    }
    return InpaintResult(out, wins.length, large);
  }

  void _fillWindow(Uint8List img, int w, IntRect win, Uint8List holeCrop, int feather) {
    final s = win.w;
    final crop = cropChannels(img, w, 4, win);
    // Model-res hole: area-average then threshold low so thin strokes survive.
    final hole = resizeMask(holeCrop, s, s, miganSize, miganSize);
    for (var i = 0; i < hole.length; i++) {
      hole[i] = hole[i] > 32 ? 255 : 0;
    }
    final modelIn = resizeRgba(crop, s, s, miganSize, miganSize);
    final outRgb = unpackMigan(run(packMigan(modelIn, hole)));
    final up = resizeRgba(outRgb, miganSize, miganSize, s, s);
    final alpha = blurMask(dilateMask(holeCrop, s, s, feather), s, s, feather);
    blendRgba(crop, up, alpha);
    pasteChannels(img, w, 4, win, crop);
  }
}
