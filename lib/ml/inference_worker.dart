import 'dart:async';
import 'dart:isolate';

import 'model_spec.dart';
import 'tf_session.dart';

class CancelledException implements Exception {
  @override
  String toString() => 'Cancelled';
}

class WorkerException implements Exception {
  WorkerException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs inside the worker isolate. Heavy pixel work and inference live here.
abstract class WorkerHandler {
  Future<Object?> handle(String op, Object? args, WorkerContext ctx);
}

class WorkerContext {
  WorkerContext(this._progress, this._cancelled);
  final void Function(Object) _progress;
  final bool Function() _cancelled;

  void progress(Object payload) => _progress(payload);

  /// Lets the isolate process incoming cancel messages, then throws if cancelled.
  /// Call between work units (tiles, passes).
  Future<void> checkpoint() async {
    await Future<void>.delayed(Duration.zero);
    if (_cancelled()) throw CancelledException();
  }
}

/// Must be a top-level / static function so it can be sent to the isolate.
typedef HandlerFactory = WorkerHandler Function(List<TfSession> sessions);

class _Init {
  _Init(this.port, this.paths, this.mode, this.factory);
  final SendPort port;
  final List<String> paths;
  final ProcessingMode mode;
  final HandlerFactory factory;
}

class CancelToken {
  void Function()? _hook;
  bool cancelled = false;

  void _bind(void Function() h) {
    _hook = h;
    if (cancelled) h();
  }

  void cancel() {
    cancelled = true;
    _hook?.call();
  }
}

/// Main-isolate side of a model worker.
class InferenceWorker {
  InferenceWorker._(this.id, this._isolate, this._send, this._rx, this.delegate);

  final ModelId id;
  final Isolate _isolate;
  final SendPort _send;
  final ReceivePort _rx;

  /// Which delegate the worker ended up with (e.g. "GPU").
  final String delegate;

  int _next = 0;
  final _pending = <int, Completer<Object?>>{};
  final _progress = <int, void Function(Object)>{};
  bool _closed = false;

  /// Last call duration in ms (shown on the AI Models page).
  double lastMs = 0;

  static Future<InferenceWorker> spawn(
    ModelId id,
    List<String> paths,
    ProcessingMode mode,
    HandlerFactory factory,
  ) async {
    final boot = ReceivePort();
    final iso = await Isolate.spawn(
      _entry,
      _Init(boot.sendPort, paths, mode, factory),
      debugName: 'worker-${id.name}',
    );
    final first = await boot.first;
    boot.close();
    if (first is! List || first[0] != 'ready') {
      iso.kill(priority: Isolate.immediate);
      throw WorkerException('Model failed to load: ${first is List ? first[1] : first}');
    }
    final rx = ReceivePort();
    (first[1] as SendPort).send([rx.sendPort]);
    final w = InferenceWorker._(id, iso, first[1] as SendPort, rx, first[2] as String);
    rx.listen(w._onMessage);
    return w;
  }

  void _onMessage(dynamic m) {
    final l = m as List;
    final jobId = l[1] as int;
    switch (l[0]) {
      case 'prog':
        _progress[jobId]?.call(l[2] as Object);
      case 'ok':
        _progress.remove(jobId);
        _pending.remove(jobId)?.complete(l[2]);
      case 'err':
        _progress.remove(jobId);
        _pending.remove(jobId)?.completeError(
              l[3] == true ? CancelledException() : WorkerException(l[2] as String),
            );
    }
  }

  /// Runs [op] in the worker. Cancel through [token].
  Future<T> call<T>(String op, Object? args, {void Function(Object)? onProgress, CancelToken? token}) {
    if (_closed) return Future.error(WorkerException('Model was unloaded'));
    final jobId = _next++;
    final c = Completer<Object?>();
    _pending[jobId] = c;
    if (onProgress != null) _progress[jobId] = onProgress;
    token?._bind(() => _send.send(['cancel', jobId]));
    final sw = Stopwatch()..start();
    _send.send(['run', jobId, op, args]);
    return c.future.then((v) {
      lastMs = sw.elapsedMicroseconds / 1000;
      return v as T;
    });
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final c in _pending.values) {
      c.completeError(WorkerException('Model was unloaded'));
    }
    _pending.clear();
    _send.send(['close']);
    _rx.close();
    Future<void>.delayed(const Duration(milliseconds: 500), () => _isolate.kill(priority: Isolate.immediate));
  }
}

Future<void> _entry(_Init init) async {
  final sessions = <TfSession>[];
  final WorkerHandler handler;
  try {
    for (final p in init.paths) {
      sessions.add(TfSession.open(p, init.mode));
    }
    handler = init.factory(sessions);
  } catch (e) {
    init.port.send(['error', e.toString()]);
    return;
  }
  final rx = ReceivePort();
  init.port.send(['ready', rx.sendPort, sessions.map((s) => s.delegate).toSet().join('+')]);
  late final SendPort out;
  final cancelled = <int>{};
  await for (final m in rx) {
    final l = m as List;
    if (l[0] is SendPort) {
      out = l[0] as SendPort;
    } else if (l[0] == 'cancel') {
      cancelled.add(l[1] as int);
    } else if (l[0] == 'close') {
      for (final s in sessions) {
        s.close();
      }
      rx.close();
    } else if (l[0] == 'run') {
      final jobId = l[1] as int;
      // Not awaited, so this loop keeps receiving cancel messages.
      unawaited(() async {
        try {
          final ctx = WorkerContext((p) => out.send(['prog', jobId, p]), () => cancelled.contains(jobId));
          final r = await handler.handle(l[2] as String, l[3], ctx);
          out.send(['ok', jobId, r]);
        } on CancelledException {
          out.send(['err', jobId, 'cancelled', true]);
        } catch (e, st) {
          out.send(['err', jobId, '$e\n$st', false]);
        } finally {
          cancelled.remove(jobId);
        }
      }());
    }
  }
}
