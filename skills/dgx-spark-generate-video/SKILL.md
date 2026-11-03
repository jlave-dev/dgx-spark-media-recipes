---
name: dgx-spark-generate-video
description: Generate local images with MOSS Image and text-to-video or image-to-video with Pika H3 on the configured DGX Spark. Use for requests to generate images or video using this local recipe.
---

# Generate images and videos on DGX Spark

Resolve the recipe repository from this skill's real location: `REPO="$(cd "$(dirname "$(readlink -f "$HOME/.codex/skills/dgx-spark-generate-video/SKILL.md")")/../.." && pwd)"`. Run `"$REPO/scripts/media" doctor` first. The recipe uses a single local ComfyUI backend and records each run under `~/media/runs/`. Do not interrupt existing work or replace an occupied backend. If the backend is unavailable, inspect the installation and start its guarded launcher only when doing so will not disrupt another workload. See the repository README.

Use the user's prompt and requested settings. `--set` values are JSON, so serialize arbitrary text with a JSON encoder; do not interpolate unescaped user text into shell commands. Prepare first using `--prepare-only`, then inspect `show RUN_ID`. Investigate provenance gaps; do not silently bypass them. Submit a new run with `--wait` when ready. Verify success with `verify RUN_ID` and report the run ID and canonical output path.

- Image: `workflows/moss-image.json` uses MOSS Image SFT INT8. Set `5.text`, `12.seed`, and optionally `6.width` and `6.height`. It creates images from text, not edits.
- Text-to-video: `workflows/pika-text-to-video.json` uses Pika H3 Flex with MiniMax H3. Set `6.prompt`, `8.noise_seed`, and optionally node 6 dimensions and length. Defaults are 832×480, 124 frames, 24 fps, and audio.
- Image-to-video: `workflows/pika-image-to-video.json` uses the same settings; pass `--input '50.image=/absolute/path/to/image.png'`. Match the aspect ratio of the input; the graph stretches it to fit.

To continue a video, use FFmpeg to extract its last decoded frame as a PNG and supply that image to the image-to-video graph. Record the source video path and hash along with the new run. The single frame carries the final composition, not the prior motion or sound. If a combined video is requested, inspect both clips' dimensions, frame rates, and audio streams, join compatible streams with FFmpeg, and check the result. Do not promise seamless continuity without inspecting it.

Keep TensorFold node 22 sparsity at zero. The patched engine supports dense inference for this model. Changing model combinations can cause a load or adapter merge; never evict another user's workload. A timed-out wait does not cancel the backend job, so check status before retrying. A seed and matching software stack do not guarantee identical pixels.
