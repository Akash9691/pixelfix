#!/usr/bin/env bash
# Downloads every bundled TFLite model into assets/models/ and prints size + SHA-256.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=assets/models
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

get() { # name url
  echo "-> $1"; curl -fsSL --retry 3 -o "$OUT/$1" "$2"
}
get migan_fp16.tflite "https://huggingface.co/litert-community/MI-GAN-512-Places2-LiteRT/resolve/main/migan_fp16.tflite"
get selfie_segmenter.tflite "https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite"
get magic_touch.tflite "https://storage.googleapis.com/mediapipe-models/interactive_segmenter/magic_touch/float32/latest/magic_touch.tflite"
get style_predict_int8.tflite "https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/int8/prediction/1?lite-format=tflite"
get style_transfer_int8.tflite "https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/int8/transfer/1?lite-format=tflite"
echo "-> real_esrgan_general_x4v3.tflite"
curl -fsSL --retry 3 -o "$TMP/r.zip" "https://qaihub-public-assets.s3.us-west-2.amazonaws.com/qai-hub-models/models/real_esrgan_general_x4v3/releases/v0.67.0/real_esrgan_general_x4v3-tflite-float.zip"
unzip -o -q "$TMP/r.zip" -d "$TMP/r"
cp "$TMP"/r/*/real_esrgan_general_x4v3.tflite "$OUT/"

total=0; fail=0
for f in migan_fp16 selfie_segmenter magic_touch style_predict_int8 style_transfer_int8 real_esrgan_general_x4v3; do
  p="$OUT/$f.tflite"
  if [ ! -s "$p" ]; then echo "MISSING: $p" >&2; fail=1; continue; fi
  s=$(wc -c < "$p"); total=$((total+s))
  printf '%-34s %10d bytes  %s\n' "$f.tflite" "$s" "$(sha256sum "$p" | cut -d' ' -f1)"
done
echo "TOTAL: $((total/1024/1024)) MiB"
[ "$fail" = 0 ] || { echo "Some models are missing" >&2; exit 1; }
