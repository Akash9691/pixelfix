import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/image_io.dart';
import '../../../ml/background_composer.dart';
import '../../../ml/handlers.dart';
import '../../../ml/inference_worker.dart';
import '../../../ml/model_spec.dart';
import '../domain/editor_state.dart';
import '../domain/style_catalog.dart';
import 'editor_controller.dart';

final aiProvider = Provider<AiActions>((ref) {
  final a = AiActions(ref);
  ref.listen(editorProvider.select((s) => s.tool), (_, __) => a.releaseCache());
  return a;
});

/// Orchestrates every AI tool: rasterize inputs, call the model workers, turn the
/// result into a pending preview. UI widgets only call these methods.
class AiActions {
  AiActions(this._ref);
  final Ref _ref;

  EditorController get _c => _ref.read(editorProvider.notifier);
  EditorState get _s => _ref.read(editorProvider);

  // Per-tool caches, released when the tool changes.
  ui.Image? _cacheFor;
  Uint8List? _rgba;
  Uint8List? _personMask;
  final _styleVectors = <String, Float32List>{};

  void releaseCache() {
    _cacheFor = null;
    _rgba = null;
    _personMask = null;
  }

  Future<Uint8List> _rgbaOf(ui.Image img) async {
    if (!identical(_cacheFor, img) || _rgba == null) {
      _rgba = await imageToRgba(img);
      _cacheFor = img;
      _personMask = null;
    }
    return _rgba!;
  }

  /// Loads the model if needed ("Preparing AI…"), then runs [op].
  Future<Map> _call(
    ModelId id,
    String op,
    Map<String, Object?> args,
    CancelToken token,
    ProgressFn progress, {
    String label = 'Working',
  }) async {
    final reg = _ref.read(registryProvider);
    if (!reg.stats[id]!.loaded) progress('Preparing AI…', null);
    await reg.acquire(id);
    return reg.call<Map>(id, op, args, token: token, onProgress: (v) {
      final l = v as List;
      progress('$label ${l[0]}/${l[1]}', (l[0] as int) / (l[1] as int));
    });
  }

  Future<ui.Image> _image(Map r) => imageFromRgba(unpack(r['rgba'] as Object), r['w'] as int, r['h'] as int);

  // ---- Magic Eraser --------------------------------------------------------

  Future<void> erase() async {
    final img = _s.image;
    if (img == null) return;
    if (_c.mask.isEmpty) {
      _c.toast('Paint over what you want to remove first');
      return;
    }
    await _c.runJob<void>('Erasing…', (token, progress) async {
      final rgba = await _rgbaOf(img);
      final mask = await _c.mask.rasterize(img.width, img.height);
      final r = await _call(
        ModelId.migan,
        'inpaint',
        {'rgba': pack(rgba), 'w': img.width, 'h': img.height, 'maskRgba': pack(mask)},
        token,
        progress,
        label: 'Erasing',
      );
      _c.setPending(await _image(r), 'erase');
      if (r['large'] == true) _c.setHint('Large areas work best in small strokes.');
    });
  }

  // ---- Tap-to-Select -------------------------------------------------------

  Future<void> selectAt(Offset imagePoint) async {
    final img = _s.image;
    if (img == null) return;
    await _c.runJob<void>('Finding object…', (token, progress) async {
      final rgba = await _rgbaOf(img);
      final r = await _call(
        ModelId.magicTouch,
        'select',
        {
          'rgba': pack(rgba),
          'w': img.width,
          'h': img.height,
          'x': imagePoint.dx.round().clamp(0, img.width - 1),
          'y': imagePoint.dy.round().clamp(0, img.height - 1),
        },
        token,
        progress,
      );
      if ((r['count'] as int) < 20) {
        _c.toast('Nothing found there. Tap the middle of the object, or paint it.');
        return;
      }
      await _c.mask.mergeBase(await imageFromRgba(unpack(r['rgba'] as Object), img.width, img.height));
      HapticFeedback.lightImpact();
    });
  }

  // ---- Expand --------------------------------------------------------------

  Future<void> expand(double aspect) async {
    final img = _s.image;
    if (img == null) return;
    final plan = planOf(img, aspect);
    if (plan == null) {
      _c.toast('The photo already has this shape');
      return;
    }
    await _c.runJob<void>('Expanding…', (token, progress) async {
      final r = await _call(
        ModelId.migan,
        'expand',
        {
          'rgba': pack(await _rgbaOf(img)),
          'w': img.width,
          'h': img.height,
          'left': plan[0],
          'top': plan[1],
          'right': plan[2],
          'bottom': plan[3],
        },
        token,
        progress,
        label: 'Filling',
      );
      _c.setPending(await _image(r), 'expand');
    });
  }

  /// [left, top, right, bottom] needed for [aspect], capped to 50 % per side.
  static List<int>? planOf(ui.Image img, double aspect) {
    final w = img.width, h = img.height;
    final cur = w / h;
    var addW = 0, addH = 0;
    if (cur < aspect) addW = (h * aspect).round() - w;
    if (cur > aspect) addH = (w / aspect).round() - h;
    final mw = w ~/ 2, mh = h ~/ 2;
    final p = [
      math.min(mw, addW ~/ 2),
      math.min(mh, addH ~/ 2),
      math.min(mw, addW - addW ~/ 2),
      math.min(mh, addH - addH ~/ 2),
    ];
    return p.every((v) => v == 0) ? null : p;
  }

  // ---- Background Studio ---------------------------------------------------

  /// Segments the person (cached) and composites [mode] over the result.
  Future<void> background(BgMode mode, {int blur = 24, int color1 = 0xFFFFFFFF, int color2 = 0xFF000000, ui.Image? picture}) async {
    final img = _s.image;
    if (img == null) return;
    await _c.runJob<void>('Cutting out…', (token, progress) async {
      final rgba = await _rgbaOf(img);
      if (_personMask == null) {
        final r = await _call(
          ModelId.selfie,
          'segment',
          {'rgba': pack(rgba), 'w': img.width, 'h': img.height},
          token,
          progress,
        );
        _personMask = unpack(r['mask'] as Object);
      }
      Uint8List? pic;
      if (picture != null) pic = await imageToRgba(picture);
      final r = await _call(
        ModelId.selfie,
        'compose',
        {
          'rgba': pack(rgba),
          'w': img.width,
          'h': img.height,
          'mask': pack(_personMask!),
          'mode': mode.name,
          'blur': blur,
          'color1': color1,
          'color2': color2,
          if (pic != null) 'image': pack(pic),
          'imageW': picture?.width ?? 0,
          'imageH': picture?.height ?? 0,
        },
        token,
        progress,
      );
      _c.setPending(await imageFromRgba(unpack(r['rgba'] as Object), img.width, img.height), 'background');
    }, timing: _personMask == null);
  }

  // ---- Upscale -------------------------------------------------------------

  Future<void> upscale(int scale) async {
    final img = _s.image;
    if (img == null) return;
    await _c.runJob<void>('Upscaling…', (token, progress) async {
      final r = await _call(
        ModelId.upscale,
        'upscale',
        {'rgba': pack(await _rgbaOf(img)), 'w': img.width, 'h': img.height, 'scale': scale},
        token,
        progress,
        label: 'Tile',
      );
      _c.setPending(await _image(r), 'upscale');
    });
  }

  // ---- Art styles ----------------------------------------------------------

  /// Style bottleneck of [src]; bundled styles are cached on disk.
  Future<Float32List> _styleVector(StyleSource src, CancelToken token, ProgressFn progress) async {
    final hit = _styleVectors[src.id];
    if (hit != null) return hit;
    File? cache;
    if (src.asset != null) {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/style_cache');
      await dir.create(recursive: true);
      cache = File('${dir.path}/${src.id}.f32');
      if (await cache.exists()) {
        final v = (await cache.readAsBytes()).buffer.asFloat32List();
        return _styleVectors[src.id] = v;
      }
    }
    final bytes = src.bytes ?? (await rootBundle.load(src.asset!)).buffer.asUint8List();
    final im = await decodeBytesCapped(bytes, maxEdge: 512);
    final rgba = await imageToRgba(im);
    final r = await _ref.read(registryProvider).acquire(ModelId.style).then((w) => w.call<Float32List>(
          'predict',
          {'rgba': pack(rgba), 'w': im.width, 'h': im.height},
          token: token,
        ));
    im.dispose();
    final v = Float32List.fromList(r);
    await cache?.writeAsBytes(v.buffer.asUint8List());
    return _styleVectors[src.id] = v;
  }

  /// Preview at 384² (fast). [full] runs the tiled full-size version and applies it.
  Future<void> style(StyleSource src, double strength, {bool full = false}) async {
    final img = _s.image;
    if (img == null) return;
    await _c.runJob<void>(full ? 'Applying style…' : 'Styling…', (token, progress) async {
      if (!_ref.read(registryProvider).stats[ModelId.style]!.loaded) progress('Preparing AI…', null);
      await _ref.read(registryProvider).acquire(ModelId.style);
      final vec = await _styleVector(src, token, progress);
      final r = await _call(
        ModelId.style,
        'stylize',
        {
          'rgba': pack(await _rgbaOf(img)),
          'w': img.width,
          'h': img.height,
          'style': vec,
          'strength': strength,
          'full': full,
        },
        token,
        progress,
        label: 'Tile',
      );
      _c.setPending(await imageFromRgba(unpack(r['rgba'] as Object), img.width, img.height), 'style');
      if (full) await _c.applyPending();
    }, timing: full);
  }

  // ---- Smart combos --------------------------------------------------------

  /// Remove person (2 -> 1): person mask, then erase it.
  Future<void> removePerson() async {
    final img = _s.image;
    if (img == null) return;
    await _c.runJob<void>('Removing person…', (token, progress) async {
      final rgba = await _rgbaOf(img);
      final seg = await _call(
        ModelId.selfie,
        'segment',
        {'rgba': pack(rgba), 'w': img.width, 'h': img.height, 'rgbaMask': true},
        token,
        progress,
      );
      final r = await _call(
        ModelId.migan,
        'inpaint',
        {
          'rgba': pack(rgba),
          'w': img.width,
          'h': img.height,
          'maskRgba': seg['maskRgba'],
          'dilate': math.max(8, math.max(img.width, img.height) ~/ 70),
        },
        token,
        progress,
        label: 'Erasing',
      );
      _c.setPending(await _image(r), 'combo');
      _c.setHint('Large areas work best in small strokes. Use Erase for a second pass.');
    });
  }

  /// Old photo fix (1 -> 5): erase the brushed scratches, then 2x upscale.
  Future<void> oldPhotoFix() async {
    final img = _s.image;
    if (img == null) return;
    if (_c.mask.isEmpty) {
      _c.toast('Brush over the scratches first (Erase tool), then run this combo');
      return;
    }
    await _c.runJob<void>('Fixing photo…', (token, progress) async {
      final mask = await _c.mask.rasterize(img.width, img.height);
      final fixed = await _call(
        ModelId.migan,
        'inpaint',
        {'rgba': pack(await _rgbaOf(img)), 'w': img.width, 'h': img.height, 'maskRgba': pack(mask)},
        token,
        progress,
        label: 'Repairing',
      );
      final up = await _call(
        ModelId.upscale,
        'upscale',
        {'rgba': fixed['rgba'], 'w': img.width, 'h': img.height, 'scale': 2},
        token,
        progress,
        label: 'Tile',
      );
      _c.setPending(await _image(up), 'combo');
    });
  }

  /// Insta fit (3 -> 5): expand to 4:5, then 2x upscale.
  Future<void> instaFit() async {
    final img = _s.image;
    if (img == null) return;
    final plan = planOf(img, 4 / 5);
    if (plan == null) {
      _c.toast('The photo is already 4:5');
      return;
    }
    await _c.runJob<void>('Fitting for Instagram…', (token, progress) async {
      final e = await _call(
        ModelId.migan,
        'expand',
        {
          'rgba': pack(await _rgbaOf(img)),
          'w': img.width,
          'h': img.height,
          'left': plan[0],
          'top': plan[1],
          'right': plan[2],
          'bottom': plan[3],
        },
        token,
        progress,
        label: 'Filling',
      );
      final up = await _call(
        ModelId.upscale,
        'upscale',
        {'rgba': e['rgba'], 'w': e['w'], 'h': e['h'], 'scale': 2},
        token,
        progress,
        label: 'Tile',
      );
      _c.setPending(await _image(up), 'combo');
    });
  }
}
