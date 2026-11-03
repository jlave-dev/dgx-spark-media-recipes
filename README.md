# DGX Spark Media Recipes

Make images and videos on one NVIDIA DGX Spark. This recipe uses **MOSS Image SFT** for images. It uses **Pika H3 Flex** on MiniMax H3 for videos. You can make a video from text or from an image. The built-in recorder saves each run's graph, inputs, model hashes, and outputs.

**Early release:** the model workflows were tested on a DGX Spark. The new setup script has not been tested from start to finish on a clean machine. Please report any failures.

## Install with an agent

On the Spark, paste this into your coding agent:

```text
Set up https://github.com/jlave-dev/dgx-spark-media-recipes on this DGX Spark.
Read the README and follow it to install and verify the MOSS image and Pika H3
video recipes. Use the included setup script, resolve ordinary prerequisites,
and run both smoke tests. Respect existing workloads and do not overwrite or
stop an existing service. Tell me the output paths and anything that failed.
```

The setup downloads and runs code from other projects. It also downloads large model files. It builds a patched TensorFold engine and starts ComfyUI on your Spark. You need internet access and enough free disk space for the models and build. The recipe downloads MOSS and MiniMax H3 weights, plus the H3 text encoder and decoders from FastH3.

Requires a 128 GB DGX Spark running Linux, the NVIDIA driver and CUDA toolkit with `nvcc`, Python 3.9+, Git, curl, FFmpeg, [uv](https://docs.astral.sh/uv/getting-started/installation/), and a free localhost port 8188. You may need to accept model terms or authenticate with Hugging Face if a download requires it. Review the model terms: [MOSS Image](https://huggingface.co/Comfy-Org/MOSS-Image), [MiniMax H3](https://huggingface.co/Comfy-Org/MiniMax-H3), and [FastH3](https://huggingface.co/FastVideo/FastVideo-FastH3-Comfy).

## Manual setup

```sh
git clone https://github.com/jlave-dev/dgx-spark-media-recipes.git
cd dgx-spark-media-recipes
./scripts/setup.sh
```

Setup installs its backend under `~/.local/share/dgx-spark-media/` and links the skill into `~/.codex/skills/`. Set `DGX_MEDIA_HOME` before setup to use another backend directory. It installs the skill only if the target does not already belong to another installation. The guarded server runs on `127.0.0.1:8188`. If that port is already occupied, setup stops instead of replacing it. Runs are recorded in `~/media/runs/`.

The setup script starts the server with a memory guard. It then runs `scripts/smoke.py`. This makes one MOSS image and one Pika H3 video. It checks the saved results and prints their paths. The first run may take several minutes. If a step fails, read the error. Do not assume that setup worked. Run `scripts/media doctor` to check the server. This command does not start or stop it. To start the server later, check for other work and check port 8188 first. Then run:

```sh
PREFIX="${DGX_MEDIA_HOME:-$HOME/.local/share/dgx-spark-media}/studio" \
SPARK_COMFY_PORT=8188 \
SPARK_COMFY_ARGS="--use-ck-attention --cache-ram 12 16 --extra-model-paths-config ${DGX_MEDIA_HOME:-$HOME/.local/share/dgx-spark-media}/studio/model-paths.yaml" \
bash vendor/imagination-studio/spark/comfy.sh start
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

The recipes use [ComfyUI](https://github.com/Comfy-Org/ComfyUI) and [TensorFold](https://github.com/drowzeys/TensorFold). They include support scripts from [Imagination Studio](https://github.com/drowzeys/Imagination-Studio-by-keys-Wasserman), created by Keys (github.com/drowzeys) and Sam Wasserman / Wasserman Productions (wassermanproductions.com). Their license and notice are in `vendor/imagination-studio/`. The patch lets Pika H3 run with dense attention. Keep TensorFold sparsity at zero. This repo has a copy of [render-media](https://github.com/jlave-dev/render-media) for use on one machine. It saves model hashes, not the model files. The same seed may not give the same pixels. The recorder may miss files used by custom nodes. Saved runs are not backups.
