# DGX Spark Media Recipes

Set up local image and video generation on one NVIDIA DGX Spark. The recipe uses **MOSS Image SFT** for images and **Pika H3 Flex** on MiniMax H3 for text-to-video and image-to-video. A bundled recorder saves each run's graph, inputs, model hashes, and outputs.

**Early release:** the model workflows were tested on a DGX Spark, but the new clean-machine installer has not yet been validated end to end. Treat the setup as experimental and report failures rather than assuming it is ready.

## Install with an agent

On the Spark, paste this into your coding agent:

```text
Set up https://github.com/jlave-dev/dgx-spark-media-recipes on this DGX Spark.
Read the README and follow it to install and verify the MOSS image and Pika H3
video recipes. Use the included setup script, resolve ordinary prerequisites,
and run both smoke tests. Respect existing workloads and do not overwrite or
stop an existing service. Tell me the output paths and anything that failed.
```

The install downloads and runs third-party code and large model weights. It builds a patched TensorFold engine and starts a local ComfyUI backend. It requires internet access and substantial disk space: allow **at least 220 GB free** for models, build files, and environment. The upstream installer also downloads Qwen and FastH3 assets; the recipes here use MOSS and Pika. Actual requirements can be higher as dependencies change.

Requires a 128 GB DGX Spark running Linux, the NVIDIA driver and CUDA toolkit with `nvcc`, Python 3.9+, Git, curl, FFmpeg, and a free localhost port 8188. You may need to accept model terms or authenticate with Hugging Face if a download requires it. The upstream installer may install `uv` in your user environment. Review the model terms: [MOSS Image](https://huggingface.co/Comfy-Org/MOSS-Image), [MiniMax H3](https://huggingface.co/Comfy-Org/MiniMax-H3), [FastH3](https://huggingface.co/FastVideo/FastVideo-FastH3-Comfy), and [Qwen Image 2.1](https://huggingface.co/Comfy-Org/Qwen-Image-2.1).

## Manual setup

```sh
git clone https://github.com/jlave-dev/dgx-spark-media-recipes.git
cd dgx-spark-media-recipes
./scripts/setup.sh
```

Setup installs its backend under `~/.local/share/dgx-spark-media/` and links the skill into `~/.codex/skills/`. Set `DGX_MEDIA_HOME` before setup to use another backend directory. It installs the skill only if the target does not already belong to another installation. The guarded server runs on `127.0.0.1:8188`. If that port is already occupied, setup stops instead of replacing it. Runs are recorded in `~/media/runs/`.

The setup script starts the guarded backend and runs `scripts/smoke.py`: it prepares and submits one MOSS image and one Pika H3 video, checks their recorded outputs, and prints the paths. A run may take several minutes on a cold start. If a step fails, read its output; do not assume the install succeeded. `scripts/media doctor` inspects the backend without starting or stopping it. To start the installed backend later, after checking other workloads and port 8188:

```sh
PREFIX="${DGX_MEDIA_HOME:-$HOME/.local/share/dgx-spark-media}/studio" \
SPARK_COMFY_PORT=8188 SPARK_COMFY_ARGS='--use-ck-attention --cache-ram 12 16' \
bash "${DGX_MEDIA_HOME:-$HOME/.local/share/dgx-spark-media}/studio-source/spark/comfy.sh" start
```

## Generate

After setup, ask your agent to use the `dgx-spark-generate-video` skill. It supports MOSS text-to-image and Pika H3 text-to-video or first-frame image-to-video. The skill uses the recorder and reports the run ID and output path. The agent must have access to this checkout and the skill; restart it if newly installed skills are not visible.

For direct use, `scripts/media` invokes the bundled recorder locally:

```sh
./scripts/media doctor
./scripts/media submit workflows/moss-image.json --project images --title 'Image' --prepare-only
./scripts/media show RUN_ID
./scripts/media list
```

Use `--set NODE.FIELD=JSON_VALUE` for prompts, seeds, and dimensions; see the skill for graph bindings. Review provenance gaps before submitting. `--wait` waits for a render, but a timeout does not cancel it. Use `status`, `show`, and `verify` to inspect runs; `--allow-incomplete` accepts known gaps and should not be used without reviewing them.

## How this fits together

The recipes use [ComfyUI](https://github.com/Comfy-Org/ComfyUI), [Imagination Studio](https://github.com/drowzeys/Imagination-Studio-by-keys-Wasserman), and [TensorFold](https://github.com/drowzeys/TensorFold). The included patch enables dense Pika H3 inference without a sparse gate; keep TensorFold sparsity at zero. The bundled [render-media](https://github.com/jlave-dev/render-media) recorder is adapted for single-machine use. It archives model hashes, not the model files, and matching seeds do not guarantee identical pixels. It cannot capture every custom node's external dependencies. Archives are not backups.
