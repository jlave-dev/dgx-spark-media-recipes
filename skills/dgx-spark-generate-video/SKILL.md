---
name: dgx-spark-generate-video
description: Generate local images with MOSS Image and text-to-video or image-to-video with Pika H3 on the configured DGX Spark. Use for requests to generate images or video using this local recipe.
---

# Generate images and videos on DGX Spark

Resolve the recipe repository from this skill's real location: `REPO="$(cd "$(dirname "$(readlink -f "$HOME/.codex/skills/dgx-spark-generate-video/SKILL.md")")/../.." && pwd)"`. Run `"$REPO/scripts/media" doctor` first. The recipe uses one local ComfyUI server. It saves each run under `~/media/runs/`. Do not stop other work or replace a server in use. If the server is down, check the setup. Start its guarded launcher only if it will not disrupt other work. See the repo README.

Use the user's prompt and settings. `--set` values are JSON. Encode text as JSON; do not put raw user text into shell commands. First, use `--prepare-only`. Then check the run with `show RUN_ID`. Review any gaps in the saved run details. Do not skip them. When ready, submit a new run with `--wait`. Check it with `verify RUN_ID`. Report the run ID and the path to its saved output.

- Image: `workflows/moss-image.json` uses MOSS Image SFT INT8. Set `5.text`, `12.seed`, and optionally `6.width` and `6.height`. It creates images from text, not edits.
- Text-to-video: `workflows/pika-text-to-video.json` uses Pika H3 Flex with MiniMax H3. Set `6.prompt`, `8.noise_seed`, and optionally node 6 dimensions and length. Defaults are 832×480, 124 frames, 24 fps, and audio.
- Image-to-video: `workflows/pika-image-to-video.json` uses the same settings; pass `--input '50.image=/absolute/path/to/image.png'`. Match the aspect ratio of the input; the graph stretches it to fit.

To continue a video, use FFmpeg to save its last frame as a PNG. Give that image to the image-to-video graph. Record the source video path and hash with the new run. The frame keeps the final scene, but not its motion or sound. To join clips, check both clips' size, frame rate, and audio. Use FFmpeg to join matching streams. Check the result before you claim it is seamless.

Keep TensorFold node 22 sparsity at zero. The patched engine supports dense runs for this model. A model change may load files or merge an adapter. Do not displace another user's work. A timed-out wait does not cancel the job. Check its status before you retry. The same seed and software may not give the same pixels.
