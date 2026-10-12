#!/usr/bin/env bash
set -euo pipefail

REPO="${QWEN_MODEL_REPO:-abenzerps/Qwen-Image-2.1-Uncensored-Quantized}"
BASE_URL="https://huggingface.co/${REPO}/resolve/main"

mkdir -p \
  /runpod-volume/models/unet \
  /runpod-volume/models/clip \
  /runpod-volume/models/vae

download_model() {
  local relative_url="$1"
  local destination="$2"
  local expected_size="$3"
  local expected_sha256="$4"
  local marker="${destination}.sha256-ok"
  local partial="${destination}.part"

  if [[ -f "$destination" ]] \
    && [[ "$(stat -c '%s' "$destination")" == "$expected_size" ]] \
    && [[ -f "$marker" ]] \
    && [[ "$(tr -d '\n' < "$marker")" == "$expected_sha256" ]]; then
    echo "qwen-image-worker: cached $(basename "$destination")"
    return
  fi

  echo "qwen-image-worker: downloading $(basename "$destination")"
  curl --fail --location --retry 8 --retry-delay 5 --continue-at - \
    --output "$partial" "${BASE_URL}/${relative_url}"

  local actual_size
  actual_size="$(stat -c '%s' "$partial")"
  if [[ "$actual_size" != "$expected_size" ]]; then
    echo "qwen-image-worker: size mismatch for $(basename "$destination"): expected ${expected_size}, got ${actual_size}" >&2
    exit 1
  fi

  echo "${expected_sha256}  ${partial}" | sha256sum --check --status
  mv "$partial" "$destination"
  printf '%s' "$expected_sha256" > "$marker"
}

download_model \
  "qwen-image-2.1-UC-Q4_K_M.gguf" \
  "/runpod-volume/models/unet/qwen-image-2.1-UC-Q4_K_M.gguf" \
  "4604558112" \
  "e79c8a009f2ecbdb6c70fd663d9aea9ee304a0d91f347e4169a756b8ad141b41"

download_model \
  "text_encoders/qwen3vl_8b_int8_convrot.safetensors" \
  "/runpod-volume/models/clip/qwen3vl_8b_int8_convrot.safetensors" \
  "9350798360" \
  "8bfd0f6e12abf2d2d697ecc888e5e90b0d6741d6708f05799f53afa560452e8f"

download_model \
  "vae/qwen_image_2.1_vae_bf16.safetensors" \
  "/runpod-volume/models/vae/qwen_image_2.1_vae_bf16.safetensors" \
  "675509688" \
  "bb21f7473051e1ac368515dd3f2e15cd44d7a11748ee8823e1ddca3e4876b7c9"

exec /start.sh
