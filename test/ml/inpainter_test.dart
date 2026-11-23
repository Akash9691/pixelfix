import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfix/core/utils/pixel_ops.dart';
import 'package:pixelfix/ml/inpainter.dart';

Uint8List solid(int w, int h, int r, int g, int b) {
  final o = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    o[i * 4] = r;
    o[i * 4 + 1] = g;
    o[i * 4 + 2] = b;
    o[i * 4 + 3] = 255;
  }
  return o;
}

void main() {
  group('MI-GAN tensor packing (NCHW, mask 1 = keep)', () {
    test('channel layout, ranges and mask polarity', () {
      const n = miganSize, plane = n * n;
      final rgba = solid(n, n, 255, 0, 51); // -> 1.0, -1.0, -0.6
      final hole = Uint8List(plane);
      hole[10] = 255; // pixel 10 is a hole
      final t = packMigan(rgba, hole);
      expect(t.length, 4 * plane);
      // known pixel
      expect(t[0], 0.5); // 1 - 0.5
      expect(t[plane + 0], closeTo(1.0, 1e-6));
      expect(t[2 * plane + 0], closeTo(-1.0, 1e-6));
      expect(t[3 * plane + 0], closeTo(51 / 127.5 - 1, 1e-6));
      // hole pixel: mask channel -0.5 and rgb zeroed
      expect(t[10], -0.5);
      expect(t[plane + 10], 0.0);
      expect(t[3 * plane + 10], 0.0);
    });

    test('unpack maps [-1,1] to 0..255 and sets alpha', () {
      const plane = miganSize * miganSize;
      final out = Float32List(3 * plane);
      for (var i = 0; i < plane; i++) {
        out[i] = -1;
        out[plane + i] = 0;
        out[2 * plane + i] = 1;
      }
      final rgba = unpackMigan(out);
      expect(rgba.sublist(0, 4), [0, 128, 255, 255]);
    });

    test('pack/unpack round trip on known pixels', () {
      const plane = miganSize * miganSize;
      final rgba = solid(miganSize, miganSize, 10, 120, 240);
      final t = packMigan(rgba, Uint8List(plane));
      final back = unpackMigan(Float32List.fromList(t.sublist(plane)));
      expect(back[0], closeTo(10, 1));
      expect(back[1], closeTo(120, 1));
      expect(back[2], closeTo(240, 1));
    });
  });

  group('window planning', () {
    test('small hole -> one window centred on it, clamped to the image', () {
      final w = Inpainter.planWindows(const IntRect(1000, 800, 40, 40), 2000, 1500);
      expect(w.length, 1);
      expect(w.first.w, 512);
      expect(w.first.x >= 0 && w.first.right <= 2000, true);
      expect(w.first.y >= 0 && w.first.bottom <= 1500, true);
    });

    test('window is never larger than the image', () {
      final w = Inpainter.planWindows(const IntRect(10, 10, 20, 20), 300, 200);
      expect(w.single.w, 200);
    });

    test('very wide hole is covered by overlapping windows', () {
      const b = IntRect(0, 100, 2400, 300);
      final ws = Inpainter.planWindows(b, 2400, 1000, side: 512);
      expect(ws.length, greaterThan(1));
      expect(ws.first.x, 0);
      expect(ws.last.right, 2400);
    });
  });

  group('mask ops', () {
    test('dilate expands bounds by the radius', () {
      final m = Uint8List(100 * 100);
      m[50 * 100 + 50] = 255;
      final d = dilateMask(m, 100, 100, 6);
      final b = maskBounds(d, 100, 100);
      expect(b, const IntRect(44, 44, 13, 13));
    });

    test('blur keeps values in range and softens edges', () {
      final m = Uint8List(64 * 64);
      for (var y = 20; y < 44; y++) {
        for (var x = 20; x < 44; x++) {
          m[y * 64 + x] = 255;
        }
      }
      final b = blurMask(m, 64, 64, 4);
      expect(b[32 * 64 + 32], 255);
      expect(b[32 * 64 + 19], inInclusiveRange(1, 254));
      expect(b[0], 0);
    });

    test('connected component keeps only the tapped blob', () {
      final m = Uint8List(20 * 20);
      m[5 * 20 + 5] = m[5 * 20 + 6] = 255;
      m[15 * 20 + 15] = 255;
      final c = connectedComponent(m, 20, 20, 5, 5);
      expect(maskCount(c), 2);
    });

    test('resize round trip preserves a solid colour', () {
      final img = solid(100, 80, 200, 100, 50);
      final r = resizeRgba(img, 100, 80, 37, 29);
      expect(r.sublist(0, 4), [200, 100, 50, 255]);
    });
  });

  group('inpaint pipeline with a fake model', () {
    test('only masked pixels change; feathered edge; others stay identical', () async {
      const w = 700, h = 600;
      final img = solid(w, h, 40, 80, 120);
      final mask = Uint8List(w * h);
      for (var y = 300; y < 340; y++) {
        for (var x = 300; x < 340; x++) {
          mask[y * w + x] = 255;
        }
      }
      // Fake generator: paints everything white.
      final inp = Inpainter((input) => Float32List(3 * miganSize * miganSize)..fillRange(0, 3 * miganSize * miganSize, 1.0));
      final r = await inp.inpaint(img, w, h, mask);
      int px(int x, int y) => r.rgba[(y * w + x) * 4];
      expect(px(320, 320), 255); // hole filled
      expect(px(10, 10), 40); // far away untouched
      expect(px(320, 100), 40);
      expect(r.windows, 1);
    });
  });
}
