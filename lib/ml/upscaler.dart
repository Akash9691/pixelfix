import 'dart:math' as math;
import 'dart:typed_data';

import '../core/utils/pixel_ops.dart';
import '../core/utils/tiling.dart';

/// Real-ESRGAN General x4v3: input `[1,128,128,3]` (0..1), output `[1,512,512,3]`.
typedef EsrganRun = Float32List Function(Float32List input);

const int esrganTile = 128;
const int esrganOverlap = 16;
const int esrganScale = 4;
const int maxOutputEdge = 4096;

class UpscalePlan {
  UpscalePlan(this.inW, this.inH, this.outW, this.outH);

  /// Size of the image fed to the network (its output is 4× this).
  final int inW, inH;

  /// Final size after the optional down-step.
  final int outW, outH;
}

/// The network always enlarges 4×. To honour [scale] (2 or 4) and the 4096 px
/// output cap we pick the input size so quality is kept: the network runs on the
/// full image when possible and the 4× result is shrunk for 2×.
UpscalePlan planUpscale(int w, int h, int scale) {
  final longEdge = math.max(w, h);
  final lin = math.min(longEdge, maxOutputEdge ~/ esrganScale);
  final f = lin / longEdge;
  final inW = math.max(1, (w * f).round()), inH = math.max(1, (h * f).round());
  final target = math.min(longEdge * scale, math.max(inW, inH) * esrganScale);
  final g = target / (longEdge * 1.0);
  return UpscalePlan(inW, inH, math.max(1, (w * g).round()), math.max(1, (h * g).round()));
}

Future<Uint8List> upscale(
  Uint8List rgba,
  int w,
  int h,
  int scale,
  EsrganRun run, {
  Future<void> Function(int done, int total)? onTile,
}) async {
  final plan = planUpscale(w, h, scale);
  final src = (plan.inW == w && plan.inH == h) ? rgba : resizeRgba(rgba, w, h, plan.inW, plan.inH);
  final big = await runTiled(
    src: src,
    w: plan.inW,
    h: plan.inH,
    size: esrganTile,
    overlap: esrganOverlap,
    scale: esrganScale,
    model: (tile) {
      final out = run(rgbaToNhwc(tile, esrganTile));
      return nhwcToRgba(out, esrganTile * esrganScale);
    },
    onTile: onTile,
  );
  final bw = plan.inW * esrganScale, bh = plan.inH * esrganScale;
  if (bw == plan.outW && bh == plan.outH) return big;
  return resizeRgba(big, bw, bh, plan.outW, plan.outH);
}
