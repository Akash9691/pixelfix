import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart pixel helpers. They are meant to run inside worker isolates, never
/// on the UI isolate. Images are interleaved: RGBA (4 ch) or masks (1 ch, 0..255).

class IntRect {
  const IntRect(this.x, this.y, this.w, this.h);
  final int x, y, w, h;
  int get right => x + w;
  int get bottom => y + h;
  bool get isEmpty => w <= 0 || h <= 0;
  @override
  String toString() => 'IntRect($x,$y,$w,$h)';
  @override
  bool operator ==(Object other) => other is IntRect && other.x == x && other.y == y && other.w == w && other.h == h;
  @override
  int get hashCode => Object.hash(x, y, w, h);
}

/// Resizes [ch]-channel 8-bit data. Averages several bilinear taps when
/// shrinking (area-like), plain bilinear when enlarging.
Uint8List resizeChannels(Uint8List src, int sw, int sh, int dw, int dh, int ch) {
  if (sw == dw && sh == dh) return Uint8List.fromList(src);
  final dst = Uint8List(dw * dh * ch);
  final sx = sw / dw, sy = sh / dh;
  final tx = math.max(1, math.min(4, sx.ceil())), ty = math.max(1, math.min(4, sy.ceil()));
  final inv = 1.0 / (tx * ty);
  final acc = List<double>.filled(ch, 0);
  for (var y = 0; y < dh; y++) {
    for (var x = 0; x < dw; x++) {
      for (var c = 0; c < ch; c++) {
        acc[c] = 0;
      }
      for (var jy = 0; jy < ty; jy++) {
        final fy = math.max(0.0, math.min(sh - 1.0, (y + (jy + 0.5) / ty) * sy - 0.5));
        final y0 = fy.floor(), y1 = math.min(sh - 1, y0 + 1);
        final wy = fy - y0;
        for (var jx = 0; jx < tx; jx++) {
          final fx = math.max(0.0, math.min(sw - 1.0, (x + (jx + 0.5) / tx) * sx - 0.5));
          final x0 = fx.floor(), x1 = math.min(sw - 1, x0 + 1);
          final wx = fx - x0;
          final w00 = (1 - wx) * (1 - wy), w10 = wx * (1 - wy), w01 = (1 - wx) * wy, w11 = wx * wy;
          final i00 = (y0 * sw + x0) * ch, i10 = (y0 * sw + x1) * ch;
          final i01 = (y1 * sw + x0) * ch, i11 = (y1 * sw + x1) * ch;
          for (var c = 0; c < ch; c++) {
            acc[c] += src[i00 + c] * w00 + src[i10 + c] * w10 + src[i01 + c] * w01 + src[i11 + c] * w11;
          }
        }
      }
      final o = (y * dw + x) * ch;
      for (var c = 0; c < ch; c++) {
        dst[o + c] = (acc[c] * inv + 0.5).floor().clamp(0, 255);
      }
    }
  }
  return dst;
}

Uint8List resizeRgba(Uint8List src, int sw, int sh, int dw, int dh) => resizeChannels(src, sw, sh, dw, dh, 4);
Uint8List resizeMask(Uint8List src, int sw, int sh, int dw, int dh) => resizeChannels(src, sw, sh, dw, dh, 1);

/// Copies the rectangle [r] (must lie inside the image).
Uint8List cropChannels(Uint8List src, int sw, int ch, IntRect r) {
  final out = Uint8List(r.w * r.h * ch);
  final rowBytes = r.w * ch;
  for (var y = 0; y < r.h; y++) {
    final s = ((r.y + y) * sw + r.x) * ch;
    out.setRange(y * rowBytes, (y + 1) * rowBytes, src, s);
  }
  return out;
}

/// Writes [patch] (size [r]) into [dst] at [r].
void pasteChannels(Uint8List dst, int dw, int ch, IntRect r, Uint8List patch) {
  final rowBytes = r.w * ch;
  for (var y = 0; y < r.h; y++) {
    dst.setRange(((r.y + y) * dw + r.x) * ch, ((r.y + y) * dw + r.x) * ch + rowBytes, patch, y * rowBytes);
  }
}

/// Bounding box of mask pixels > [threshold]; empty rect if none.
IntRect maskBounds(Uint8List mask, int w, int h, {int threshold = 127}) {
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      if (mask[row + x] > threshold) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        maxY = y;
      }
    }
  }
  if (maxX < 0) return const IntRect(0, 0, 0, 0);
  return IntRect(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

int maskCount(Uint8List mask, {int threshold = 127}) {
  var n = 0;
  for (final v in mask) {
    if (v > threshold) n++;
  }
  return n;
}

IntRect clampRect(IntRect r, int w, int h) {
  final x0 = r.x.clamp(0, w), y0 = r.y.clamp(0, h);
  final x1 = r.right.clamp(0, w), y1 = r.bottom.clamp(0, h);
  return IntRect(x0, y0, x1 - x0, y1 - y0);
}

IntRect inflateRect(IntRect r, int d) => IntRect(r.x - d, r.y - d, r.w + 2 * d, r.h + 2 * d);

/// Binary dilation with a square window of radius [r] (separable running max).
/// Works on the full mask but only touches [bounds] inflated by [r].
Uint8List dilateMask(Uint8List mask, int w, int h, int r, {IntRect? bounds}) {
  if (r <= 0) return Uint8List.fromList(mask);
  final b = clampRect(inflateRect(bounds ?? maskBounds(mask, w, h), r), w, h);
  final out = Uint8List.fromList(mask);
  if (b.isEmpty) return out;
  final tmp = Uint8List(b.w * b.h);
  // horizontal
  for (var y = 0; y < b.h; y++) {
    final row = (b.y + y) * w + b.x;
    var last = -1000000; // last x with a set pixel
    // forward pass: distance to last set pixel on the left
    final fwd = Uint8List(b.w);
    for (var x = 0; x < b.w; x++) {
      if (mask[row + x] > 127) last = x;
      fwd[x] = (x - last <= r) ? 255 : 0;
    }
    last = 1000000;
    for (var x = b.w - 1; x >= 0; x--) {
      if (mask[row + x] > 127) last = x;
      tmp[y * b.w + x] = (fwd[x] == 255 || last - x <= r) ? 255 : 0;
    }
  }
  // vertical
  for (var x = 0; x < b.w; x++) {
    var last = -1000000;
    final fwd = Uint8List(b.h);
    for (var y = 0; y < b.h; y++) {
      if (tmp[y * b.w + x] > 127) last = y;
      fwd[y] = (y - last <= r) ? 255 : 0;
    }
    last = 1000000;
    for (var y = b.h - 1; y >= 0; y--) {
      if (tmp[y * b.w + x] > 127) last = y;
      out[(b.y + y) * w + b.x + x] = (fwd[y] == 255 || last - y <= r) ? 255 : 0;
    }
  }
  return out;
}

/// Approximate Gaussian blur of a 1-channel image: three box-blur passes.
Uint8List blurMask(Uint8List src, int w, int h, int radius) {
  if (radius <= 0) return Uint8List.fromList(src);
  // Box width so that three passes approximate sigma ~ radius/2.
  final r = math.max(1, (radius / 1.7).round());
  var a = Float32List.fromList(src.map((v) => v.toDouble()).toList());
  var b = Float32List(a.length);
  for (var pass = 0; pass < 3; pass++) {
    _boxH(a, b, w, h, r);
    _boxV(b, a, w, h, r);
  }
  final out = Uint8List(src.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = (a[i] + 0.5).floor().clamp(0, 255);
  }
  return out;
}

void _boxH(Float32List s, Float32List d, int w, int h, int r) {
  final inv = 1.0 / (2 * r + 1);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var sum = 0.0;
    for (var x = -r; x <= r; x++) {
      sum += s[row + x.clamp(0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      d[row + x] = sum * inv;
      sum += s[row + math.min(w - 1, x + r + 1)] - s[row + math.max(0, x - r)];
    }
  }
}

void _boxV(Float32List s, Float32List d, int w, int h, int r) {
  final inv = 1.0 / (2 * r + 1);
  for (var x = 0; x < w; x++) {
    var sum = 0.0;
    for (var y = -r; y <= r; y++) {
      sum += s[y.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      d[y * w + x] = sum * inv;
      sum += s[math.min(h - 1, y + r + 1) * w + x] - s[math.max(0, y - r) * w + x];
    }
  }
}

/// dst = dst*(1-a) + src*a for RGBA images of equal size, alpha from [alpha] (0..255).
void blendRgba(Uint8List dst, Uint8List src, Uint8List alpha) {
  for (var i = 0, p = 0; i < alpha.length; i++, p += 4) {
    final a = alpha[i];
    if (a == 0) continue;
    if (a == 255) {
      dst[p] = src[p];
      dst[p + 1] = src[p + 1];
      dst[p + 2] = src[p + 2];
      continue;
    }
    final ia = 255 - a;
    dst[p] = (dst[p] * ia + src[p] * a + 127) ~/ 255;
    dst[p + 1] = (dst[p + 1] * ia + src[p + 1] * a + 127) ~/ 255;
    dst[p + 2] = (dst[p + 2] * ia + src[p + 2] * a + 127) ~/ 255;
  }
}

/// Keeps only the connected component (4-neighbourhood) containing ([sx],[sy]).
/// If the seed pixel is not set, the nearest set pixel within 12 px is used.
Uint8List connectedComponent(Uint8List mask, int w, int h, int sx, int sy) {
  var seed = -1;
  if (mask[sy * w + sx] > 127) {
    seed = sy * w + sx;
  } else {
    var best = 1 << 30;
    for (var y = math.max(0, sy - 12); y <= math.min(h - 1, sy + 12); y++) {
      for (var x = math.max(0, sx - 12); x <= math.min(w - 1, sx + 12); x++) {
        if (mask[y * w + x] > 127) {
          final d = (x - sx) * (x - sx) + (y - sy) * (y - sy);
          if (d < best) {
            best = d;
            seed = y * w + x;
          }
        }
      }
    }
  }
  final out = Uint8List(w * h);
  if (seed < 0) return out;
  final stack = <int>[seed];
  out[seed] = 255;
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final x = p % w, y = p ~/ w;
    void tryAdd(int q) {
      if (mask[q] > 127 && out[q] == 0) {
        out[q] = 255;
        stack.add(q);
      }
    }

    if (x > 0) tryAdd(p - 1);
    if (x < w - 1) tryAdd(p + 1);
    if (y > 0) tryAdd(p - w);
    if (y < h - 1) tryAdd(p + w);
  }
  return out;
}
