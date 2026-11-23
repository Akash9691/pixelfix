import 'dart:io';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'model_spec.dart';

/// One interpreter living inside a worker isolate. Never used on the UI isolate.
class TfSession {
  TfSession._(this.interpreter, this.delegate);

  final Interpreter interpreter;

  /// "GPU" or "CPU (4 threads)".
  final String delegate;

  /// Opens [path] with the requested [mode]. In auto/gpu mode the GPU delegate is
  /// tried first and validated with a warm-up run; any failure (or NaN output)
  /// falls back to the CPU.
  static TfSession open(String path, ProcessingMode mode) {
    if (mode != ProcessingMode.cpu) {
      try {
        final o = InterpreterOptions()..addDelegate(GpuDelegateV2());
        final s = TfSession._(Interpreter.fromFile(File(path), options: o), 'GPU');
        if (s._warmUp()) return s;
        s.close();
      } catch (_) {
        // fall through to the CPU
      }
    }
    final o = InterpreterOptions()..threads = 4;
    final s = TfSession._(Interpreter.fromFile(File(path), options: o), 'CPU (4 threads)');
    s._warmUp();
    return s;
  }

  /// One dummy run so the first real call is fast. Returns false on NaN output.
  bool _warmUp() {
    interpreter.allocateTensors();
    for (final t in interpreter.getInputTensors()) {
      t.data = Uint8List(t.data.length);
    }
    interpreter.invoke();
    for (final t in interpreter.getOutputTensors()) {
      final f = Uint8List.fromList(t.data).buffer.asFloat32List();
      for (var i = 0; i < f.length; i += 97) {
        if (f[i].isNaN) return false;
      }
    }
    return true;
  }

  /// Runs the model with raw float32 [inputs]; returns copies of all outputs.
  /// Every input/output tensor of the bundled models is float32.
  List<Float32List> run(List<Float32List> inputs) {
    final ins = interpreter.getInputTensors();
    for (var i = 0; i < inputs.length; i++) {
      ins[i].data = inputs[i].buffer.asUint8List(inputs[i].offsetInBytes, inputs[i].lengthInBytes);
    }
    interpreter.invoke();
    return [
      for (final t in interpreter.getOutputTensors()) Uint8List.fromList(t.data).buffer.asFloat32List(),
    ];
  }

  void close() => interpreter.close();
}
