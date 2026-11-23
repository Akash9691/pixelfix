import 'dart:isolate';
import 'dart:typed_data';

import '../core/utils/tiling.dart';
import 'background_composer.dart';
import 'inference_worker.dart';
import 'inpainter.dart';
import 'model_spec.dart';
import 'outpainter.dart';
import 'segmenters.dart';
import 'style_transfer.dart';
import 'tf_session.dart';
import 'upscaler.dart';

/// Helpers to move big byte buffers between isolates without extra copies.
TransferableTypedData pack(Uint8List bytes) => TransferableTypedData.fromList([bytes]);
Uint8List unpack(Object t) => (t as TransferableTypedData).materialize().asUint8List();

/// Top-level functions (required so they can be sent to a new isolate).
HandlerFactory factoryFor(ModelId id) => switch (id) {
      ModelId.migan => _migan,
      ModelId.magicTouch => _touch,
      ModelId.selfie => _selfie,
      ModelId.upscale => _upscale,
      ModelId.style => _style,
    };

WorkerHandler _migan(List<TfSession> s) => MiganHandler(s[0]);
WorkerHandler _touch(List<TfSession> s) => TouchHandler(s[0]);
WorkerHandler _selfie(List<TfSession> s) => SelfieHandler(s[0]);
WorkerHandler _upscale(List<TfSession> s) => UpscaleHandler(s[0]);
WorkerHandler _style(List<TfSession> s) => StyleHandler(s[0], s[1]);

Future<void> Function(int, int) _progressAndCancel(WorkerContext ctx) => (done, total) async {
      ctx.progress([done, total]);
      await ctx.checkpoint();
    };

/// ops: `inpaint` {rgba,w,h,maskRgba (alpha = mask),[dilate],[feather],[windowSide]}
///      `expand`  {rgba,w,h,left,top,right,bottom}
class MiganHandler implements WorkerHandler {
  MiganHandler(this.session);
  final TfSession session;

  @override
  Future<Object?> handle(String op, Object? args, WorkerContext ctx) async {
    final a = args as Map;
    Float32List run(Float32List input) => session.run([input]).first;
    switch (op) {
      case 'inpaint':
        final w = a['w'] as int, h = a['h'] as int;
        final r = await Inpainter(run).inpaint(
          unpack(a['rgba'] as Object),
          w,
          h,
          alphaPlane(unpack(a['maskRgba'] as Object)),
          dilate: a['dilate'] as int?,
          feather: (a['feather'] as int?) ?? 4,
          windowSide: a['windowSide'] as int?,
          onWindow: _progressAndCancel(ctx),
        );
        return {'rgba': pack(r.rgba), 'w': w, 'h': h, 'large': r.largeMask};
      case 'expand':
        final r = await expandImage(
          unpack(a['rgba'] as Object),
          a['w'] as int,
          a['h'] as int,
          ExpandPlan(a['left'] as int, a['top'] as int, a['right'] as int, a['bottom'] as int),
          run,
          onWindow: _progressAndCancel(ctx),
        );
        return {'rgba': pack(r.rgba), 'w': r.w, 'h': r.h, 'large': r.large};
    }
    throw ArgumentError('Unknown op $op');
  }
}

/// op `select` {rgba,w,h,x,y} → {mask}
class TouchHandler implements WorkerHandler {
  TouchHandler(this.session);
  final TfSession session;

  @override
  Future<Object?> handle(String op, Object? args, WorkerContext ctx) async {
    final a = args as Map;
    final m = magicTouchMask(
      unpack(a['rgba'] as Object),
      a['w'] as int,
      a['h'] as int,
      a['x'] as int,
      a['y'] as int,
      (i) => session.run([i]).first,
    );
    return {'rgba': pack(maskToRgba(m)), 'count': m.where((v) => v > 127).length};
  }
}

/// ops: `segment` {rgba,w,h} → {mask};
///      `compose` {rgba,w,h,mask,mode,[blur],[color1],[color2],[image,imageW,imageH]} → {rgba}
class SelfieHandler implements WorkerHandler {
  SelfieHandler(this.session);
  final TfSession session;

  @override
  Future<Object?> handle(String op, Object? args, WorkerContext ctx) async {
    final a = args as Map;
    final w = a['w'] as int, h = a['h'] as int;
    switch (op) {
      case 'segment':
        final m = selfieMask(unpack(a['rgba'] as Object), w, h, (i) => session.run([i]).first);
        return {
          'mask': pack(m),
          if (a['rgbaMask'] == true) 'maskRgba': pack(maskToRgba(m)),
        };
      case 'compose':
        final img = a['image'];
        final out = composeBackground(
          fg: unpack(a['rgba'] as Object),
          w: w,
          h: h,
          mask: unpack(a['mask'] as Object),
          mode: BgMode.values.byName(a['mode'] as String),
          blurRadius: (a['blur'] as int?) ?? 24,
          color1: (a['color1'] as int?) ?? 0xFFFFFFFF,
          color2: (a['color2'] as int?) ?? 0xFF000000,
          image: img == null ? null : unpack(img as Object),
          imageW: (a['imageW'] as int?) ?? 0,
          imageH: (a['imageH'] as int?) ?? 0,
        );
        return {'rgba': pack(out)};
    }
    throw ArgumentError('Unknown op $op');
  }
}

/// op `upscale` {rgba,w,h,scale} → {rgba,w,h}
class UpscaleHandler implements WorkerHandler {
  UpscaleHandler(this.session);
  final TfSession session;

  @override
  Future<Object?> handle(String op, Object? args, WorkerContext ctx) async {
    final a = args as Map;
    final w = a['w'] as int, h = a['h'] as int, scale = a['scale'] as int;
    final out = await upscale(
      unpack(a['rgba'] as Object),
      w,
      h,
      scale,
      (i) => session.run([i]).first,
      onTile: _progressAndCancel(ctx),
    );
    final plan = planUpscale(w, h, scale);
    return {'rgba': pack(out), 'w': plan.outW, 'h': plan.outH};
  }
}

/// ops: `predict` {rgba,w,h} → Float32List(100);
///      `stylize` {rgba,w,h,style,strength,full} → {rgba}
class StyleHandler implements WorkerHandler {
  StyleHandler(this.predict, this.transfer);
  final TfSession predict, transfer;

  @override
  Future<Object?> handle(String op, Object? args, WorkerContext ctx) async {
    final a = args as Map;
    final rgba = unpack(a['rgba'] as Object);
    final w = a['w'] as int, h = a['h'] as int;
    Float32List pred(Float32List i) => predict.run([i]).first;
    switch (op) {
      case 'predict':
        return styleVector(rgba, w, h, pred);
      case 'stylize':
        final strength = (a['strength'] as num).toDouble();
        var b = a['style'] as Float32List;
        if (strength < 0.999) {
          b = blendBottleneck(b, styleVector(rgba, w, h, pred), strength);
        }
        Float32List xfer(Float32List c, Float32List bn) => transfer.run([c, bn]).first;
        final out = (a['full'] == true)
            ? await stylizeFull(rgba, w, h, b, xfer, onTile: _progressAndCancel(ctx))
            : stylizePreview(rgba, w, h, b, xfer);
        return {'rgba': pack(out)};
    }
    throw ArgumentError('Unknown op $op');
  }
}
