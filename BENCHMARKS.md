# Benchmarks

Fill the blank cells from your own phone (Settings → AI Models shows the delegate and last inference time; use `flutter run --profile` + DevTools for frame times and memory).

| Device | Android | SoC | Delegate (Auto) |
|---|---|---|---|
| _your phone_ | | | |

## Targets vs. measured

| Metric | Target | Measured on phone |
|---|---|---|
| Cold start to first frame | < 2 s | |
| Magic Eraser, one stroke region (512 window) | < 1.5 s | |
| Worst frame while brushing | ≤ 32 ms | |
| Selfie segmentation (256², whole op incl. resize) | – | |
| Tap-to-Select (MagicTouch, whole op) | – | |
| Expand 4:5 on a 1600 px photo | – | |
| Upscale 2× of a 1000 px photo (tiles × time) | – | |
| Style preview (384²) | – | |
| Style apply (tiled, ≤ 1152 px work size) | – | |
| Memory after 10 consecutive edits (DevTools) | no growth | |

## Reference numbers (not from a phone)

| Where | What | Result |
|---|---|---|
| Windows PC, Python LiteRT, CPU (XNNPACK) | MI-GAN fp16, one 512² window | ≈ 1.1 s |
| Model card (Pixel 8a, GPU) | MI-GAN fp16 | 6 ms (LiteRT CompiledModel) / 68 ms (classic GPU delegate) |
| Android emulator (x86_64, CPU) | see below | – |

## Build sizes
See the table in `README.md` (filled from the real release build).
