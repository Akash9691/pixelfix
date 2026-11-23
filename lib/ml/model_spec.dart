/// Static metadata for every bundled model (shown on the "AI Models" page).
enum ModelId { migan, magicTouch, selfie, upscale, style }

enum ProcessingMode { auto, gpu, cpu }

class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.name,
    required this.task,
    required this.assets,
    required this.inputSize,
    required this.sizeMb,
  });

  final ModelId id;
  final String name;
  final String task;

  /// One or more asset files; the worker opens one interpreter per file.
  final List<String> assets;
  final String inputSize;
  final double sizeMb;
}

const modelSpecs = <ModelId, ModelSpec>{
  ModelId.migan: ModelSpec(
    id: ModelId.migan,
    name: 'MI-GAN 512 (fp16)',
    task: 'Magic Eraser + Expand (inpainting)',
    assets: ['migan_fp16.tflite'],
    inputSize: '512×512×4',
    sizeMb: 16.3,
  ),
  ModelId.magicTouch: ModelSpec(
    id: ModelId.magicTouch,
    name: 'MediaPipe MagicTouch',
    task: 'Tap-to-Select (interactive segmentation)',
    assets: ['magic_touch.tflite'],
    inputSize: '512×512×4',
    sizeMb: 6.2,
  ),
  ModelId.selfie: ModelSpec(
    id: ModelId.selfie,
    name: 'MediaPipe Selfie Segmenter',
    task: 'Background Studio (person mask)',
    assets: ['selfie_segmenter.tflite'],
    inputSize: '256×256×3',
    sizeMb: 0.25,
  ),
  ModelId.upscale: ModelSpec(
    id: ModelId.upscale,
    name: 'Real-ESRGAN General x4v3',
    task: 'AI Upscale (super-resolution)',
    assets: ['real_esrgan_general_x4v3.tflite'],
    inputSize: '128×128×3 tiles',
    sizeMb: 4.9,
  ),
  ModelId.style: ModelSpec(
    id: ModelId.style,
    name: 'Magenta Arbitrary Stylization (int8)',
    task: 'Art Styles (predict + transfer)',
    assets: ['style_predict_int8.tflite', 'style_transfer_int8.tflite'],
    inputSize: '256² style / 384² content',
    sizeMb: 3.1,
  ),
};
