# Bundled models

Shapes below were read from the real files with the LiteRT interpreter (`getInputTensors/getOutputTensors` equivalent), not copied from model cards. Run `tools/fetch_models.sh` (or `.ps1`) to download them.

| File | Task | Source | Licence | Input | Output | Size |
|---|---|---|---|---|---|---|
| `migan_fp16.tflite` | Inpainting / outpainting | HF `litert-community/MI-GAN-512-Places2-LiteRT` (Picsart MI-GAN, ICCV 2023) | MIT | **NCHW** `[1,4,512,512]` f32 = concat(mask−0.5, rgb·mask); rgb∈[−1,1]; mask **1 = keep, 0 = hole** | `[1,3,512,512]` rgb ∈[−1,1]; composite `rgb·m + out·(1−m)` | 16.3 MB |
| `magic_touch.tflite` | Tap-to-select | MediaPipe `interactive_segmenter/magic_touch` | Apache-2.0 | **NHWC** `[1,512,512,4]` f32: rgb∈[0,1] + tap channel (filled disk r≈20 px =1, else 0; verified empirically) | `[1,512,512,1]` mask prob 0..1 | 6.2 MB |
| `selfie_segmenter.tflite` | Person / background | MediaPipe `selfie_segmenter` (256) | Apache-2.0 | `[1,256,256,3]` rgb∈[0,1] | `[1,256,256,1]` person prob | 0.25 MB |
| `real_esrgan_general_x4v3.tflite` | Super-resolution ×4 | Qualcomm AI Hub release of xinntao Real-ESRGAN General x4v3 | BSD-3-Clause | `[1,128,128,3]` rgb∈[0,1] | `[1,512,512,3]` rgb∈[0,1] | 4.9 MB |
| `esrgan_tfhub.tflite` | SR fallback ×4 | TF Hub `captain-pool/esrgan-tf2` | Apache-2.0 | `[1,50,50,3]` f32 rgb 0..255 | `[1,200,200,3]` 0..255 | 5.0 MB |
| `style_predict_int8.tflite` | Style bottleneck | TF Hub Magenta arbitrary-image-stylization-v1-256 int8 | Apache-2.0 | `[1,256,256,3]` rgb∈[0,1] | `[1,1,1,100]` | 2.8 MB |
| `style_transfer_int8.tflite` | Style transfer | same | Apache-2.0 | content `[1,384,384,3]` rgb∈[0,1] + bottleneck `[1,1,1,100]` | `[1,384,384,3]` rgb∈[0,1] | 0.28 MB |

All I/O tensors are float32 (int8 refers to the weights).

Checked in Python on CPU: MI-GAN runs with XNNPACK (≈1.1 s on a PC); MagicTouch returns plausible masks (tap pixel = 1.0).

Total ≈ 36.9 MB decimal (34 MiB). See `DECISIONS.md` for how the 30 MB budget is met.
