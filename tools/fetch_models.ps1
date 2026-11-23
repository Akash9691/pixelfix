# Downloads every bundled TFLite model into assets/models/ and prints size + SHA-256.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'assets/models'
New-Item -ItemType Directory -Force $out | Out-Null
$tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
$ProgressPreference = 'SilentlyContinue'

$files = [ordered]@{
  'migan_fp16.tflite'          = 'https://huggingface.co/litert-community/MI-GAN-512-Places2-LiteRT/resolve/main/migan_fp16.tflite'
  'selfie_segmenter.tflite'    = 'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/latest/selfie_segmenter.tflite'
  'magic_touch.tflite'         = 'https://storage.googleapis.com/mediapipe-models/interactive_segmenter/magic_touch/float32/latest/magic_touch.tflite'
  'style_predict_int8.tflite'  = 'https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/int8/prediction/1?lite-format=tflite'
  'style_transfer_int8.tflite' = 'https://tfhub.dev/google/lite-model/magenta/arbitrary-image-stylization-v1-256/int8/transfer/1?lite-format=tflite'
}
foreach ($k in $files.Keys) { Write-Host "-> $k"; Invoke-WebRequest $files[$k] -OutFile (Join-Path $out $k) }
Write-Host '-> real_esrgan_general_x4v3.tflite'
Invoke-WebRequest 'https://qaihub-public-assets.s3.us-west-2.amazonaws.com/qai-hub-models/models/real_esrgan_general_x4v3/releases/v0.67.0/real_esrgan_general_x4v3-tflite-float.zip' -OutFile "$tmp/r.zip"
Expand-Archive "$tmp/r.zip" "$tmp/r" -Force
Copy-Item (Get-ChildItem "$tmp/r" -Recurse -Filter real_esrgan_general_x4v3.tflite).FullName $out -Force

$names = @('migan_fp16','selfie_segmenter','magic_touch','style_predict_int8','style_transfer_int8','real_esrgan_general_x4v3')
$total = 0; $fail = $false
foreach ($n in $names) {
  $p = Join-Path $out "$n.tflite"
  if (-not (Test-Path $p) -or (Get-Item $p).Length -eq 0) { Write-Error "MISSING: $p" -ErrorAction Continue; $fail = $true; continue }
  $len = (Get-Item $p).Length; $total += $len
  '{0,-34} {1,10} bytes  {2}' -f "$n.tflite", $len, (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
}
"TOTAL: $([int]($total/1MB)) MiB"
Remove-Item $tmp -Recurse -Force
if ($fail) { throw 'Some models are missing' }
