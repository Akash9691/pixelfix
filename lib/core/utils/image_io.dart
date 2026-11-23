import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Decoding / encoding through the engine (native threads, off the UI isolate).

/// Decodes [bytes], shrinking so the long edge is at most [maxEdge].
Future<ui.Image> decodeBytesCapped(Uint8List bytes, {int maxEdge = 3000}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final desc = await ui.ImageDescriptor.encoded(buffer);
    try {
      final long = math.max(desc.width, desc.height);
      final f = long > maxEdge ? maxEdge / long : 1.0;
      final codec = await desc.instantiateCodec(
        targetWidth: f < 1 ? math.max(1, (desc.width * f).round()) : null,
        targetHeight: f < 1 ? math.max(1, (desc.height * f).round()) : null,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } finally {
      desc.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

Future<ui.Image> imageFromRgba(Uint8List rgba, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

Future<Uint8List> imageToRgba(ui.Image image) async {
  final d = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
}

Future<Uint8List> imageToPng(ui.Image image) async {
  final d = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
}

/// Smaller copy for the canvas / thumbnails (GPU scaling, no pixel loops in Dart).
Future<ui.Image> scaledCopy(ui.Image src, int maxEdge) async {
  final long = math.max(src.width, src.height);
  if (long <= maxEdge) return src.clone();
  final f = maxEdge / long;
  final w = math.max(1, (src.width * f).round()), h = math.max(1, (src.height * f).round());
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawImageRect(
    src,
    ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final pic = rec.endRecording();
  final out = await pic.toImage(w, h);
  pic.dispose();
  return out;
}

/// Native JPG / WebP encoding (Android `Bitmap.compress`), see MainActivity.
class NativeCodec {
  static const _ch = MethodChannel('pixelfix/codec');

  /// [format]: `jpg`, `webp` or `png`. Input is PNG bytes (lossless hand-over).
  static Future<Uint8List> encode(Uint8List png, String format, int quality) async {
    if (format == 'png') return png;
    final r = await _ch.invokeMethod<Uint8List>('encode', {'png': png, 'format': format, 'quality': quality});
    return r!;
  }
}
