import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'handlers.dart';
import 'inference_worker.dart';
import 'model_spec.dart';

class ModelStats {
  bool loaded = false;
  String delegate = '-';
  double lastMs = 0;
}

/// Lazy model loading with an LRU of [maxLoaded] workers. Models are opened only
/// when their tool is first used; the least recently used one is closed first.
class ModelRegistry extends ChangeNotifier {
  ModelRegistry({this.mode = ProcessingMode.auto});

  static const maxLoaded = 2;
  ProcessingMode mode;

  final _workers = <ModelId, InferenceWorker>{}; // insertion order = LRU order
  final _loading = <ModelId, Future<InferenceWorker>>{};
  final stats = {for (final id in ModelId.values) id: ModelStats()};

  Future<List<String>> _extract(ModelSpec spec) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/models');
    await dir.create(recursive: true);
    final paths = <String>[];
    for (final name in spec.assets) {
      final f = File('${dir.path}/$name');
      final data = await rootBundle.load('assets/models/$name');
      if (!await f.exists() || await f.length() != data.lengthInBytes) {
        await f.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      paths.add(f.path);
    }
    return paths;
  }

  /// Returns the loaded worker for [id], loading (and warming up) it if needed.
  Future<InferenceWorker> acquire(ModelId id) {
    final w = _workers.remove(id);
    if (w != null) {
      _workers[id] = w; // mark most recently used
      return Future.value(w);
    }
    return _loading[id] ??= _load(id).whenComplete(() => _loading.remove(id));
  }

  Future<InferenceWorker> _load(ModelId id) async {
    final spec = modelSpecs[id]!;
    final paths = await _extract(spec);
    final sw = Stopwatch()..start();
    final w = await InferenceWorker.spawn(id, paths, mode, factoryFor(id));
    debugPrint('[ML] ${spec.name} ready on ${w.delegate} in ${sw.elapsedMilliseconds} ms');
    _workers[id] = w;
    stats[id]!
      ..loaded = true
      ..delegate = w.delegate;
    while (_workers.length > maxLoaded) {
      final oldest = _workers.keys.firstWhere((k) => k != id);
      _workers.remove(oldest)!.close();
      stats[oldest]!.loaded = false;
    }
    notifyListeners();
    return w;
  }

  /// Convenience: acquire + call + record timing.
  Future<T> call<T>(
    ModelId id,
    String op,
    Object? args, {
    void Function(Object)? onProgress,
    CancelToken? token,
  }) async {
    final w = await acquire(id);
    try {
      return await w.call<T>(op, args, onProgress: onProgress, token: token);
    } finally {
      stats[id]!.lastMs = w.lastMs;
      notifyListeners();
    }
  }

  /// Changes the delegate policy and drops loaded models so they reload with it.
  void setMode(ProcessingMode m) {
    if (m == mode) return;
    mode = m;
    unloadAll();
  }

  void unloadAll() {
    for (final w in _workers.values) {
      w.close();
    }
    _workers.clear();
    for (final s in stats.values) {
      s.loaded = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unloadAll();
    super.dispose();
  }
}
