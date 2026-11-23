import 'dart:math' as math;
import 'dart:typed_data';

import '../core/utils/pixel_ops.dart';
import '../core/utils/tiling.dart';

/// Magenta arbitrary stylization (int8 weights, float I/O).
/// predict: style `[1,256,256,3]` (0..1) → bottleneck `[1,1,1,100]`
/// transfer: content `[1,384,384,3]` (0..1) + bottleneck → `[1,384,384,3]` (0..1)
typedef PredictRun = Float32List Function(Float32List style);
typedef TransferRun = Float32List Function(Float32List content, Float32List bottleneck);

const int stylePredictSize = 256;
const int styleContentSize = 384;
const int styleBottleneck = 100;

/// Bottleneck vector of an image. A non-square image is centre-cropped first so
/// the style is not distorted.
Float32List styleVector(Uint8List rgba, int w, int h, PredictRun predict) {
  final s = math.min(w, h);
  final sq = cropChannels(rgba, w, 4, IntRect((w - s) ~/ 2, (h - s) ~/ 2, s, s));
  final small = resizeRgba(sq, s, s, stylePredictSize, stylePredictSize);
  return predict(rgbaToNhwc(small, stylePredictSize));
}

/// style × s + content × (1 − s), the strength blend from the Magenta paper.
Float32List blendBottleneck(Float32List style, Float32List content, double strength) {
  final out = Float32List(style.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = style[i] * strength + content[i] * (1 - strength);
  }
  return out;
}

/// Preview: the whole picture is squeezed to 384² (cheap, one network call),
/// stylized and stretched back to w×h.
Uint8List stylizePreview(Uint8List rgba, int w, int h, Float32List bottleneck, TransferRun transfer) {
  final small = resizeRgba(rgba, w, h, styleContentSize, styleContentSize);
  final out = nhwcToRgba(transfer(rgbaToNhwc(small, styleContentSize), bottleneck), styleContentSize);
  return resizeRgba(out, styleContentSize, styleContentSize, w, h);
}

/// Full quality: work at up to [maxEdge] px with overlapping 384² tiles, then
/// resize to the original size.
Future<Uint8List> stylizeFull(
  Uint8List rgba,
  int w,
  int h,
  Float32List bottleneck,
  TransferRun transfer, {
  int maxEdge = 1152,
  Future<void> Function(int done, int total)? onTile,
}) async {
  final f = math.min(1.0, maxEdge / math.max(w, h));
  final ww = math.max(1, (w * f).round()), hh = math.max(1, (h * f).round());
  final src = f == 1.0 ? rgba : resizeRgba(rgba, w, h, ww, hh);
  final out = await runTiled(
    src: src,
    w: ww,
    h: hh,
    size: styleContentSize,
    overlap: 48,
    scale: 1,
    model: (tile) => nhwcToRgba(transfer(rgbaToNhwc(tile, styleContentSize), bottleneck), styleContentSize),
    onTile: onTile,
  );
  return f == 1.0 ? out : resizeRgba(out, ww, hh, w, h);
}
