import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfix/core/utils/pixel_ops.dart';
import 'package:pixelfix/core/utils/tiling.dart';
import 'package:pixelfix/ml/background_composer.dart';
import 'package:pixelfix/ml/inpainter.dart';
import 'package:pixelfix/ml/outpainter.dart';
import 'package:pixelfix/ml/segmenters.dart';
import 'package:pixelfix/ml/style_transfer.dart';
import 'package:pixelfix/ml/upscaler.dart';

Uint8List gradientImg(int w, int h) {
  final o = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      o[i] = (x * 255 ~/ w);
      o[i + 1] = (y * 255 ~/ h);
      o[i + 2] = 100;
      o[i + 3] = 255;
    }
  }
  return o;
}

Float32List filled(int n, double v) => Float32List(n)..fillRange(0, n, v);

void main() {
  group('tiling', () {
    test('origins cover the dimension with overlap and end flush', () {
      final xs = tileOrigins(300, 128, 16);
      expect(xs.first, 0);
      expect(xs.last, 300 - 128);
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], lessThanOrEqualTo(112));
      }
      expect(tileOrigins(50, 128, 16), [0]);
    });

    test('tiled identity (scale 1) reproduces the image exactly', () async {
      const w = 300, h = 250;
      final img = gradientImg(w, h);
      final out = await runTiled(src: img, w: w, h: h, size: 128, overlap: 16, scale: 1, model: (t) => t);
      expect(out, img);
    });

    test('tiled 4x nearest upscale has no seams (matches direct upscale)', () async {
      const w = 200, h = 150;
      final img = gradientImg(w, h);
      Uint8List nn(Uint8List t) {
        final o = Uint8List(512 * 512 * 4);
        for (var y = 0; y < 512; y++) {
          for (var x = 0; x < 512; x++) {
            final s = ((y ~/ 4) * 128 + x ~/ 4) * 4, d = (y * 512 + x) * 4;
            o.setRange(d, d + 4, t, s);
          }
        }
        return o;
      }

      final out = await runTiled(src: img, w: w, h: h, size: 128, overlap: 16, scale: 4, model: nn);
      expect(out.length, w * 4 * h * 4 * 4);
      for (final p in [
        [3, 5],
        [400, 300],
        [799, 599],
        [450, 100]
      ]) {
        final o = (p[1] * w * 4 + p[0]) * 4, s = ((p[1] ~/ 4) * w + p[0] ~/ 4) * 4;
        expect(out[o], img[s]);
        expect(out[o + 1], img[s + 1]);
      }
    });
  });

  group('upscale plan', () {
    test('4x of a small image', () {
      final p = planUpscale(500, 300, 4);
      expect((p.outW, p.outH), (2000, 1200));
      expect((p.inW, p.inH), (500, 300));
    });
    test('2x runs the network on the full image and shrinks', () {
      final p = planUpscale(500, 300, 2);
      expect((p.outW, p.outH), (1000, 600));
    });
    test('output long edge is capped at 4096', () {
      final p = planUpscale(3000, 2000, 4);
      expect(p.outW, 4096);
      expect(p.outH, closeTo(2731, 2));
    });
    test('upscale pipeline with a fake network returns plan size', () async {
      final img = gradientImg(100, 80);
      final out = await upscale(img, 100, 80, 2, (i) => filled(512 * 512 * 3, 0.5));
      expect(out.length, 200 * 160 * 4);
      expect(out[0], 128);
    });
  });

  group('style transfer', () {
    test('strength blend interpolates the bottleneck', () {
      final s = Float32List.fromList([1, 1]);
      final c = Float32List.fromList([0, 2]);
      expect(blendBottleneck(s, c, 0.25), [0.25, 1.75]);
      expect(blendBottleneck(s, c, 1.0), [1, 1]);
    });
    test('preview keeps the original size', () {
      final img = gradientImg(160, 90);
      final out = stylizePreview(img, 160, 90, Float32List(100), (c, b) => c);
      expect(out.length, img.length);
    });
  });

  group('segmenters', () {
    test('MagicTouch packing: rgb 0..1 and a disk at the tap', () {
      final rgba = Uint8List(512 * 512 * 4)..fillRange(0, 512 * 512 * 4, 255);
      final t = packMagicTouch(rgba, 100, 200);
      int at(int x, int y, int c) => (y * 512 + x) * 4 + c;
      expect(t[at(100, 200, 3)], 1.0);
      expect(t[at(120, 200, 3)], 1.0);
      expect(t[at(121, 200, 3)], 0.0);
      expect(t[at(0, 0, 3)], 0.0);
      expect(t[at(5, 5, 0)], 1.0);
    });

    test('selfie mask is upscaled to image size', () {
      final img = gradientImg(300, 200);
      final m = selfieMask(img, 300, 200, (i) {
        final o = Float32List(256 * 256);
        for (var y = 0; y < 256; y++) {
          for (var x = 0; x < 256; x++) {
            o[y * 256 + x] = x > 128 ? 1.0 : 0.0;
          }
        }
        return o;
      });
      expect(m.length, 300 * 200);
      expect(m[100 * 300 + 10], 0);
      expect(m[100 * 300 + 290], 255);
    });

    test('MagicTouch keeps only the tapped blob', () {
      final img = gradientImg(512, 512);
      final m = magicTouchMask(img, 512, 512, 100, 100, (i) {
        final o = Float32List(512 * 512);
        for (final r in [80, 300]) {
          for (var y = r; y < r + 40; y++) {
            for (var x = r; x < r + 40; x++) {
              o[y * 512 + x] = 0.9;
            }
          }
        }
        return o;
      });
      expect(m[100 * 512 + 100], 255);
      expect(m[320 * 512 + 320], 0);
    });
  });

  group('background composer', () {
    test('colour replaces background, keeps foreground', () {
      const w = 20, h = 10;
      final fg = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 200);
      final mask = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 10; x < w; x++) {
          mask[y * w + x] = 255;
        }
      }
      final o = composeBackground(fg: fg, w: w, h: h, mask: mask, mode: BgMode.color, color1: 0xFF102030);
      expect(o.sublist(0, 4), [0x10, 0x20, 0x30, 255]);
      expect(o[15 * 4], 200);
    });
    test('transparent writes the mask into alpha', () {
      final fg = Uint8List(16)..fillRange(0, 16, 255);
      final o = composeBackground(
        fg: fg,
        w: 2,
        h: 2,
        mask: Uint8List.fromList([0, 128, 255, 10]),
        mode: BgMode.transparent,
      );
      expect([o[3], o[7], o[11], o[15]], [0, 128, 255, 10]);
    });
  });

  group('expand', () {
    test('plan: 4:3 photo to 16:9 adds width only; capped to 50 % per side', () {
      final p = planExpand(1200, 900, 16 / 9);
      expect(p.top + p.bottom, 0);
      expect(p.left + p.right, 1600 - 1200);
      final cap = planExpand(1000, 1000, 5.0);
      expect(cap.left, 500);
      expect(cap.right, 500);
    });

    test('expand fills the border and keeps the original pixels', () async {
      const w = 300, h = 200;
      final img = gradientImg(w, h);
      final r = await expandImage(
        img,
        w,
        h,
        const ExpandPlan(100, 0, 100, 0),
        (i) => filled(3 * miganSize * miganSize, 1.0),
      );
      expect((r.w, r.h), (500, 200));
      expect(r.rgba[(100 * 500 + 250) * 4], img[(100 * w + 150) * 4]);
      expect(r.rgba[(100 * 500 + 10) * 4], 255);
    });
  });

  test('crop/paste round trip', () {
    final img = gradientImg(50, 40);
    final c = cropRgba(img, 50, const IntRect(5, 6, 10, 10));
    final dst = Uint8List(50 * 40 * 4);
    pasteChannels(dst, 50, 4, const IntRect(5, 6, 10, 10), c);
    expect(dst[(6 * 50 + 5) * 4], img[(6 * 50 + 5) * 4]);
  });
}
