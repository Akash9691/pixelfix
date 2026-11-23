import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Zoom / pan state of the editor canvas (screen ↔ image coordinates).
class CanvasView extends ChangeNotifier {
  double scale = 1;
  Offset offset = Offset.zero;
  Size viewport = Size.zero;
  Size image = Size.zero;

  double get fitScale => (viewport.isEmpty || image.isEmpty)
      ? 1
      : math.min(viewport.width / image.width, viewport.height / image.height);

  bool _touched = false;

  void configure(Size viewport, Size image) {
    final imageChanged = image != this.image;
    final viewportChanged = viewport != this.viewport;
    this.viewport = viewport;
    this.image = image;
    if (imageChanged || (viewportChanged && !_touched)) fit(notify: false);
  }

  void fit({bool notify = true}) {
    _touched = false;
    scale = fitScale;
    offset = Offset((viewport.width - image.width * scale) / 2, (viewport.height - image.height * scale) / 2);
    if (notify) notifyListeners();
  }

  Offset toImage(Offset screen) => (screen - offset) / scale;

  /// Zoom by [factor] around [focal] (screen coordinates), plus a pan of [pan].
  void zoom(double factor, Offset focal, Offset pan) {
    final newScale = (scale * factor).clamp(fitScale * 0.8, fitScale * 12);
    _touched = true;
    final f = newScale / scale;
    offset = focal - (focal - offset) * f + pan;
    scale = newScale;
    notifyListeners();
  }
}
