# PixelFix build plan

Confirmed model I/O is in `assets/models/MODELS.md`. Decisions in `DECISIONS.md`.

| # | Phase | Status | Note |
|---|---|---|---|
| 1 | Setup: project, design system, router, fetch scripts, models verified | done | Models downloaded and their real tensors read with the LiteRT interpreter. UI UX Pro Max skill installed and used (`DESIGN.md`). |
| 2 | ML core: registry, isolate workers, delegate fallback, warm-up, tests | done | `lib/ml/`: one worker isolate per model, GPU first with NaN check, CPU (4 threads) fallback, LRU of 2. |
| 3 | Editor shell: import, canvas, brush, undo/redo, compare, export | done | Path-based mask, custom pointer gestures, file-based history (20). |
| 4 | Magic Eraser (MI-GAN crop → run → feathered composite) | done | Window planner + overlap for big holes; unit-tested with a fake model; polarity/layout checked in Python on a real photo. |
| 5 | Tap-to-Select (MagicTouch) | done | Direct TFLite, tap = disk channel (r=20/512). No DeepLab fallback needed. |
| 6 | Background Studio | done | Selfie 256² mask → blur + soft threshold → transparent / blur / colour / gradient / photo. |
| 7 | Expand | done | Mirror prefill, overlapping windows, 50 % cap per side. |
| 8 | Upscale | done | 128 px tiles, 16 px overlap, cross-fade, progress + cancel, 4096 px cap. |
| 9 | Art styles | done | 6 bundled styles (+ gallery), bottleneck cache, strength blend, preview 384² / full tiled. |
| 10 | Combos, My Edits, Settings, AI Models page, onboarding | done | |
| 11 | Hardening, release build, size report | partly | Release APKs built. arm64 is 54.0 MB (target 45 MB missed). No on-device run of the AI tools yet; no DevTools memory/fps pass. |
| 12 | Docs | done | README, VIVA_NOTES, BENCHMARKS (blanks for the real phone), MODELS, DESIGN, DECISIONS. |

Tests: `flutter test` (pixel ops, tensor packing, tiling/blending, pipelines with fake models, widget smoke tests).
