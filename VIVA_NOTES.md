# Viva notes (likely questions, short answers)

**1. What does PixelFix do?**
An offline Android photo editor. Six small neural networks run on the phone: object removal (MI-GAN), tap-to-select (MediaPipe MagicTouch), background removal (Selfie Segmenter), super-resolution (Real-ESRGAN), art styles (Magenta) and image expansion (MI-GAN again).

**2. Why on-device and not a server?**
Privacy (photos never leave the phone), no network latency or cost, works in airplane mode, and nothing to host. Trade-off: models must be small and the phone's CPU/GPU limits speed.

**3. What is TensorFlow Lite / LiteRT?**
A runtime that executes a trained network on a phone. A `.tflite` file is a compact FlatBuffer holding the graph and weights. `tflite_flutter` calls it from Dart through FFI.

**4. What is inpainting? Outpainting?**
Inpainting fills a hole in an image so it looks natural (removing an object = painting a hole and inpainting it). Outpainting extends an image past its borders; I reuse the same network with the *new border* as the hole.

**5. What is a GAN? What is MI-GAN?**
A Generative Adversarial Network trains a generator against a discriminator that tries to tell real from fake. MI-GAN (Picsart, ICCV 2023) is a *mobile-sized* inpainting generator: depthwise-separable convolutions and no normalisation layers, so it is fast on phones. The bundled file is the fp16 version (16 MB).

**6. How do you feed MI-GAN?**
The input is a 4-channel `[1,4,512,512]` tensor: channel 0 = mask − 0.5 (1 = keep, 0 = hole), channels 1-3 = RGB in [-1,1] multiplied by the mask. Output is RGB in [-1,1]; only the hole pixels are blended back. (The layout was read from the real file and the model card, then checked in Python.)

**7. Why not resize the whole photo to 512×512?**
That would blur everything. I crop a square window around the hole (about 2× its size), run the network on that, and paste back only the masked pixels with a feathered edge. Big holes use overlapping windows.

**8. Why tiling for upscaling?**
Real-ESRGAN expects a fixed 128×128 input. I cut the photo into 128 px tiles with 16 px overlap, upscale each ×4 and cross-fade the overlaps so no grid appears. It also bounds memory.

**9. GPU delegate vs CPU?**
The GPU delegate runs the graph on the phone GPU (often faster). It can fail on some devices/ops, so a worker tries GPU first, validates a warm-up run (also checks for NaN) and falls back to the CPU with 4 threads. Settings lets you force either.

**10. What is quantization? Which models use it?**
Storing weights with fewer bits: fp16 (MI-GAN, selfie) halves the size, int8 (Magenta) quarters it, at a small accuracy cost. Inputs/outputs of all bundled models are still float32.

**11. How does style transfer work here?**
Two networks: *predict* turns a style image into a 100-number "style bottleneck"; *transfer* repaints the content image given that vector. Strength = mix of the style vector and the photo's own vector.

**12. How do you keep the UI smooth?**
Every model lives in its own long-lived worker isolate (Dart thread) which also does the pixel loops. The UI isolate only draws. The mask is stored as vector paths and drawn by a `CustomPainter` that repaints through a `Listenable`, not through widget rebuilds.

**13. Memory management?**
Models load lazily; at most two stay loaded (LRU). Photos are capped at 3000 px; undo steps are PNG files in the temp folder (max 20), not RAM.

**14. Limitations?**
Large holes and complex backgrounds look artificial (a 512 px network); outpainting works best on sky/sand/water; the selfie model is for people; Real-ESRGAN may invent texture; MagicTouch needs a clear object under the tap; no HD (LaMa) model.

**15. Future scope?**
LaMa HD eraser as an optional download, NPU delegates, video, batch processing, text-guided editing with a small diffusion model.
