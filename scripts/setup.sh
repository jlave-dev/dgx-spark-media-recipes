#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${DGX_MEDIA_HOME:-$HOME/.local/share/dgx-spark-media}"
PREFIX="$ROOT/studio"
SPARK_MODELS="$ROOT/models"
STUDIO="$ROOT/studio-source"
TF_SOURCE="$ROOT/tensorfold-source"
STUDIO_COMMIT=12d2e8005f8a78f3dea8e89d14864316cc86c04f
TF_COMMIT=1f7ecc75ded5df6da151d4d5eeee87b35161e3c2
export PREFIX SPARK_MODELS SPARK_COMFY_PORT=8188 PATH="$HOME/.local/bin:/usr/local/cuda/bin:$PATH"
export SPARK_COMFY_ARGS='--use-ck-attention --cache-ram 12 16'
for cmd in git python3 curl ffmpeg ffprobe nvidia-smi; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = aarch64 ] || { echo 'A Linux aarch64 DGX Spark is required.' >&2; exit 1; }
nvidia-smi --query-gpu=name --format=csv,noheader | grep -qi 'GB10\|Spark' || { echo 'A DGX Spark GPU was not detected.' >&2; exit 1; }
[ -x /usr/local/cuda/bin/nvcc ] || { echo 'CUDA toolkit nvcc is required at /usr/local/cuda/bin/nvcc.' >&2; exit 1; }
if python3 -c 'import socket; s=socket.socket(); s.settimeout(1); raise SystemExit(0 if s.connect_ex(("127.0.0.1",8188))==0 else 1)'; then
  echo 'Port 8188 is in use. Do not replace a running service; stop setup and inspect it.' >&2; exit 1
fi
mkdir -p "$ROOT"
if [ ! -d "$STUDIO/.git" ]; then git clone https://github.com/drowzeys/Imagination-Studio-by-keys-Wasserman.git "$STUDIO"; fi
[ -z "$(git -C "$STUDIO" status --porcelain)" ] || { echo "Studio source has local changes: $STUDIO" >&2; exit 1; }
git -C "$STUDIO" fetch origin "$STUDIO_COMMIT"
git -C "$STUDIO" checkout --detach "$STUDIO_COMMIT"
# The upstream setup uses an isolated PREFIX and models directory, and supplies ComfyUI,
# CUDA PyTorch, and the memory guard. It also downloads additional upstream models.
bash "$STUDIO/oneshot-setup-spark.sh" --yes --no-render --no-workflows --no-loras --no-graphics --no-finish --moss --h3-base
HF="$PREFIX/venv/bin/hf"
"$HF" download Comfy-Org/MOSS-Image diffusion_models/moss_image_sft_int8_convrot.safetensors text_encoders/qwen3.5_9b_w4a8_gptq.safetensors vae/flux2-vae_small.safetensors --local-dir "$SPARK_MODELS/MOSS-Image-Comfy"
"$HF" download Comfy-Org/MiniMax-H3 loras/pika_h3_flex_fl2va_v1_bf16.safetensors --local-dir "$SPARK_MODELS/MiniMax-H3-Comfy"
python3 - "$SPARK_MODELS" <<'PY'
from datetime import date
from pathlib import Path
import sys

root = Path(sys.argv[1])
sources = {'MOSS-Image-Comfy': 'https://huggingface.co/Comfy-Org/MOSS-Image',
           'MiniMax-H3-Comfy': 'https://huggingface.co/Comfy-Org/MiniMax-H3',
           'FastH3-Comfy': 'https://huggingface.co/FastVideo/FastVideo-FastH3-Comfy',
           'Qwen-Image-2.1-Comfy': 'https://huggingface.co/Comfy-Org/Qwen-Image-2.1'}
for model in root.rglob('*.safetensors'):
    sidecar = model.with_name(model.name + '.md')
    if not sidecar.exists():
        source = sources.get(model.relative_to(root).parts[0], 'Source not recorded by this setup.')
        sidecar.write_text(f'# {model.name}\n\nSource: {source}\nRecorded: {date.today()}\n'
                           'Downloaded for DGX Spark Media Recipes. Used by the recipe or its upstream setup.\n')
PY
# A patched dense engine is required for the Pika adapter; do not use the upstream prebuilt engine.
if [ ! -d "$TF_SOURCE/.git" ]; then git clone https://github.com/drowzeys/TensorFold.git "$TF_SOURCE"; fi
[ -z "$(git -C "$TF_SOURCE" status --porcelain)" ] || git -C "$TF_SOURCE" apply --reverse --check "$REPO/patches/tensorfold-h3.patch" || { echo 'TensorFold source has unexpected edits.' >&2; exit 1; }
git -C "$TF_SOURCE" fetch origin "$TF_COMMIT"
if ! git -C "$TF_SOURCE" apply --reverse --check "$REPO/patches/tensorfold-h3.patch" 2>/dev/null; then
  git -C "$TF_SOURCE" checkout --detach "$TF_COMMIT"
  git -C "$TF_SOURCE" apply "$REPO/patches/tensorfold-h3.patch"
fi
[ "$(git -C "$TF_SOURCE" rev-parse HEAD)" = "$TF_COMMIT" ] || { echo 'TensorFold revision mismatch.' >&2; exit 1; }
TF_SOURCE="$TF_SOURCE" ENGINE_FROM_SOURCE=1 bash "$STUDIO/spark/build-engine.sh"
mkdir -p "$HOME/.codex/skills"
SKILL="$HOME/.codex/skills/dgx-spark-generate-video"
if [ -e "$SKILL" ] || [ -L "$SKILL" ]; then
  [ "$(readlink -f "$SKILL")" = "$REPO/skills/dgx-spark-generate-video" ] || { echo "Skill destination already exists: $SKILL" >&2; exit 1; }
else
  ln -s "$REPO/skills/dgx-spark-generate-video" "$SKILL"
fi
SPARK_COMFY_PORT=8188 PREFIX="$PREFIX" bash "$STUDIO/spark/comfy.sh" start
for i in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:8188/system_stats >/dev/null; then
    "$REPO/scripts/media" doctor
    python3 "$REPO/scripts/smoke.py"
    echo 'Setup and both smoke tests completed.'
    exit 0
  fi
  sleep 2
done
echo "ComfyUI did not become ready; inspect $PREFIX/comfy-8188.log" >&2
exit 1
