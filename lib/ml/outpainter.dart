import 'dart:math' as math;
import 'dart:typed_data';

import '../core/utils/pixel_ops.dart';
import 'inpainter.dart';

/// How much to add on each side of the photo.
class ExpandPlan {
  const ExpandPlan(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
  bool get isEmpty => left + top + right + bottom == 0;
}

/// Expansion needed so a [w]×[h] photo reaches [aspect] (= width / height),
/// split evenly and capped to 50 % of the size per side.
ExpandPlan planExpand(int w, int h, double aspect) {
  final cur = w / h;
  var addW = 0, addH = 0;
  if (cur < aspect) {
    addW = (h * aspect).round() - w;
  } else if (cur > aspect) {
    addH = (w / aspect).round() - h;
  }
  final maxW = w ~/ 2, maxH = h ~/ 2;
  final l = math.min(maxW, addW ~/ 2), r = math.min(maxW, addW - addW ~/ 2);
  final t = math.min(maxH, addH ~/ 2), b = math.min(maxH, addH - addH ~/ 2);
  return ExpandPlan(l, t, r, b);
}

int _reflect(int i, int n) {
  if (n == 1) return 0;
  final p = 2 * (n - 1);
  var m = i % p;
  if (m < 0) m += p;
  return m < n ? m : p - m;
}

class ExpandResult {
  ExpandResult(this.rgba, this.w, this.h, this.large);
  final Uint8List rgba;
  final int w, h;
  final bool large;
}

/// Builds the enlarged canvas (mirror-filled border = better starting point than
/// black, and it is what the feathered seam blends with) and lets MI-GAN fill the
/// new border in overlapping windows.
Future<ExpandResult> expandImage(
  Uint8List rgba,
  int w,
  int h,
  ExpandPlan plan,
  MiganRun run, {
  Future<void> Function(int done, int total)? onWindow,
}) async {
  var src = rgba, sw = w, sh = h;
  var l = plan.left, t = plan.top, r = plan.right, b = plan.bottom;
  final longEdge = math.max(w + l + r, h + t + b);
  if (longEdge > 4096) {
    final f = 4096 / longEdge;
    sw = math.max(1, (w * f).round());
    sh = math.max(1, (h * f).round());
    src = resizeRgba(rgba, w, h, sw, sh);
    l = (l * f).round();
    t = (t * f).round();
    r = (r * f).round();
    b = (b * f).round();
  }
  final nw = sw + l + r, nh = sh + t + b;
  final canvas = Uint8List(nw * nh * 4);
  final mask = Uint8List(nw * nh);
  for (var y = 0; y < nh; y++) {
    final sy = _reflect(y - t, sh);
    final inY = y >= t && y < t + sh;
    for (var x = 0; x < nw; x++) {
      final sx = _reflect(x - l, sw);
      final s = (sy * sw + sx) * 4, d = (y * nw + x) * 4;
      canvas[d] = src[s];
      canvas[d + 1] = src[s + 1];
      canvas[d + 2] = src[s + 2];
      canvas[d + 3] = 255;
      if (!(inY && x >= l && x < l + sw)) mask[y * nw + x] = 255;
    }
  }
  final side = math.max(nw, nh) > 2048 ? 768 : miganSize;
  final res = await Inpainter(run).inpaint(
    canvas,
    nw,
    nh,
    mask,
    dilate: 0,
    feather: 4,
    windowSide: math.min(side, math.min(nw, nh)),
    onWindow: onWindow,
  );
  return ExpandResult(res.rgba, nw, nh, res.largeMask);
}
