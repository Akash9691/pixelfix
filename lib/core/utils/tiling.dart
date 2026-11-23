import 'dart:math' as math;
import 'dart:typed_data';

import 'pixel_ops.dart';

/// One tile of a regular grid with overlap.
class Tile {
  const Tile(this.x, this.y, this.col, this.row);
  final int x, y, col, row;
}

/// Tile origins along one axis: step = [size] - [overlap]; the last tile is
/// shifted back so it ends exactly at [dim] (images smaller than a tile get one).
List<int> tileOrigins(int dim, int size, int overlap) {
  if (dim <= size) return [0];
  final step = size - overlap;
  final out = <int>[];
  var p = 0;
  while (true) {
    if (p + size >= dim) {
      out.add(dim - size);
      break;
    }
    out.add(p);
    p += step;
  }
  return out;
}

List<Tile> planTiles(int w, int h, int size, int overlap) {
  final xs = tileOrigins(w, size, overlap), ys = tileOrigins(h, size, overlap);
  return [
    for (var r = 0; r < ys.length; r++)
      for (var c = 0; c < xs.length; c++) Tile(xs[c], ys[r], c, r),
  ];
}

/// Extracts a [size]x[size] RGBA tile with edge clamping (works past the borders).
Uint8List extractTile(Uint8List src, int w, int h, int x, int y, int size) {
  final out = Uint8List(size * size * 4);
  for (var ty = 0; ty < size; ty++) {
    final sy = math.min(h - 1, y + ty);
    for (var tx = 0; tx < size; tx++) {
      final sx = math.min(w - 1, x + tx);
      final s = (sy * w + sx) * 4, d = (ty * size + tx) * 4;
      out[d] = src[s];
      out[d + 1] = src[s + 1];
      out[d + 2] = src[s + 2];
      out[d + 3] = 255;
    }
  }
  return out;
}

/// Writes processed tiles into one output image. Tiles must be fed in the order
/// of [planTiles]; the left/top overlap with already-written neighbours is
/// cross-faded linearly, which removes visible tile grids.
class TileBlender {
  TileBlender(this.outW, this.outH) : rgba = Uint8List(outW * outH * 4);
  final int outW, outH;
  final Uint8List rgba;

  /// [tile] is [tw]x[th] RGBA placed at ([ox],[oy]); [fadeLeft]/[fadeTop] give the
  /// overlap width (in output pixels) with the previous column / row (0 = none).
  void put(Uint8List tile, int tw, int th, int ox, int oy, {int fadeLeft = 0, int fadeTop = 0}) {
    for (var y = 0; y < th; y++) {
      final oyy = oy + y;
      if (oyy >= outH) break;
      final ay = (fadeTop > 0 && y < fadeTop) ? (y + 0.5) / fadeTop : 1.0;
      for (var x = 0; x < tw; x++) {
        final oxx = ox + x;
        if (oxx >= outW) break;
        final ax = (fadeLeft > 0 && x < fadeLeft) ? (x + 0.5) / fadeLeft : 1.0;
        final a = math.min(ax, ay);
        final s = (y * tw + x) * 4, d = (oyy * outW + oxx) * 4;
        if (a >= 1.0) {
          rgba[d] = tile[s];
          rgba[d + 1] = tile[s + 1];
          rgba[d + 2] = tile[s + 2];
        } else {
          rgba[d] = (rgba[d] * (1 - a) + tile[s] * a).round();
          rgba[d + 1] = (rgba[d + 1] * (1 - a) + tile[s + 1] * a).round();
          rgba[d + 2] = (rgba[d + 2] * (1 - a) + tile[s + 2] * a).round();
        }
        rgba[d + 3] = 255;
      }
    }
  }
}

/// Runs [model] over every tile of [src] (tile [size] -> [size]*[scale]) and
/// stitches the results into a (w*scale)x(h*scale) image.
/// [model] maps an RGBA tile to an RGBA tile of size*scale.
Future<Uint8List> runTiled({
  required Uint8List src,
  required int w,
  required int h,
  required int size,
  required int overlap,
  required int scale,
  required Uint8List Function(Uint8List tile) model,
  Future<void> Function(int done, int total)? onTile,
}) async {
  final tiles = planTiles(w, h, size, overlap);
  final blender = TileBlender(w * scale, h * scale);
  final xs = tileOrigins(w, size, overlap), ys = tileOrigins(h, size, overlap);
  var done = 0;
  for (final t in tiles) {
    final out = model(extractTile(src, w, h, t.x, t.y, size));
    final ts = size * scale;
    final fadeL = t.col > 0 ? math.max(0, (xs[t.col - 1] + size - t.x) * scale) : 0;
    final fadeT = t.row > 0 ? math.max(0, (ys[t.row - 1] + size - t.y) * scale) : 0;
    blender.put(out, ts, ts, t.x * scale, t.y * scale, fadeLeft: fadeL, fadeTop: fadeT);
    done++;
    await onTile?.call(done, tiles.length);
  }
  return blender.rgba;
}

/// RGBA 8-bit -> NHWC float32 (rgb only), scaled by [mul] (1/255 -> 0..1).
Float32List rgbaToNhwc(Uint8List rgba, int n, {double mul = 1 / 255}) {
  final f = Float32List(n * n * 3);
  for (var i = 0, j = 0; i < n * n; i++, j += 3) {
    f[j] = rgba[i * 4] * mul;
    f[j + 1] = rgba[i * 4 + 1] * mul;
    f[j + 2] = rgba[i * 4 + 2] * mul;
  }
  return f;
}

/// NHWC float rgb (0..1) -> RGBA 8-bit.
Uint8List nhwcToRgba(Float32List f, int n) {
  final o = Uint8List(n * n * 4);
  for (var i = 0, j = 0; i < n * n; i++, j += 3) {
    o[i * 4] = (f[j] * 255 + 0.5).floor().clamp(0, 255);
    o[i * 4 + 1] = (f[j + 1] * 255 + 0.5).floor().clamp(0, 255);
    o[i * 4 + 2] = (f[j + 2] * 255 + 0.5).floor().clamp(0, 255);
    o[i * 4 + 3] = 255;
  }
  return o;
}

/// Extracts the alpha plane of an RGBA image as a 1-channel mask.
Uint8List alphaPlane(Uint8List rgba) {
  final m = Uint8List(rgba.length ~/ 4);
  for (var i = 0; i < m.length; i++) {
    m[i] = rgba[i * 4 + 3];
  }
  return m;
}

/// 1-channel mask -> RGBA whose alpha is the mask (colour [rgb], default violet).
Uint8List maskToRgba(Uint8List mask, {int rgb = 0x7C5CFF}) {
  final o = Uint8List(mask.length * 4);
  final r = (rgb >> 16) & 255, g = (rgb >> 8) & 255, b = rgb & 255;
  for (var i = 0; i < mask.length; i++) {
    o[i * 4] = r;
    o[i * 4 + 1] = g;
    o[i * 4 + 2] = b;
    o[i * 4 + 3] = mask[i];
  }
  return o;
}

/// Convenience: crop a rect from RGBA.
Uint8List cropRgba(Uint8List src, int sw, IntRect r) => cropChannels(src, sw, 4, r);
