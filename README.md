> 🏠 **Home:** [git.digtvbg.com/ivangotoy/yt-whisper-docker](https://git.digtvbg.com/ivangotoy/yt-whisper-docker)\
> 🔄 **Mirror:** [github.com/ivangotoy/yt-whisper-docker](https://github.com/ivangotoy/yt-whisper-docker) (read-only)

# yt-whisper-docker

YouTube audio transcription with host `yt-dlp`, Docker, `ffmpeg`, and `whisper.cpp`.

The host wrapper downloads YouTube audio with host `yt-dlp`, including browser-cookie support, then runs Docker only for WAV conversion and transcription with the selected `whisper.cpp` backend.

## Images

Default local image names:

- `yt-whisper-docker:cpu` - CPU backend
- `yt-whisper-docker:amd` - Vulkan backend for AMD / Mesa / `/dev/dri`
- `yt-whisper-docker:nvidia` - CUDA backend for NVIDIA

Optional registry builds are supported with:

    REGISTRY=registry.example.com ./scripts/build.sh amd

## Requirements

- Linux or WSL2
- Docker with Buildx
- `yt-dlp` installed on the host
- For AMD / Vulkan: `/dev/dri` (the wrapper adds the owning group of each `/dev/dri` node to the container, because `--user` drops supplementary groups)
- For NVIDIA / CUDA: NVIDIA driver and NVIDIA Container Toolkit

## Build

Build CPU:

    ./scripts/build.sh cpu

Build AMD / Vulkan:

    ./scripts/build.sh amd

Build NVIDIA / CUDA:

    ./scripts/build.sh nvidia

Build all three serially:

    ./scripts/build.sh all

Useful build variables:

| Variable | Default | Used by |
| --- | --- | --- |
| `REGISTRY` | empty | all |
| `IMAGE_NAME` | `yt-whisper-docker` | all |
| `UBUNTU_IMAGE` | `ubuntu:26.04` | cpu, amd (base image, for example a local mirror) |
| `UBUNTU_VERSION` | `26.04` | nvidia (`nvidia/cuda` tag suffix) |
| `CUDA_VERSION` | `13.3.0` | nvidia |
| `WHISPER_CPP_REF` | pinned commit `5922450fbce1` | all |
| `YT_DLP_URL` | pinned yt-dlp nightly `2026.11.04.232659` `yt-dlp_linux` | all |
| `YT_DLP_SHA256` | sha256 of the pinned yt-dlp | all |
| `YT_WHISPER_MODEL_SHA256` | sha256 of `ggml-large-v3.bin`; empty for any other model unless set | all |
| `YT_WHISPER_MODEL` | `large-v3` | all |
| `BUILD_JOBS` | `nproc` | cpu, amd |
| `NVIDIA_BUILD_JOBS` | `24` | nvidia |
| `CMAKE_CUDA_ARCHITECTURES` | `75;80;86;90` | nvidia |

whisper.cpp, yt-dlp and the model are pinned for reproducible builds, and the yt-dlp binary and the model are checked against their sha256. An empty `*_SHA256` skips that check. To build from the latest versions instead:

    WHISPER_CPP_REF=master \
    YT_DLP_URL=https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp_linux YT_DLP_SHA256= \
    ./scripts/build.sh amd

## Run

Run CPU:

    ./scripts/run.sh cpu 'https://www.youtube.com/watch?v=VIDEO_ID'

Run AMD / Vulkan:

    ./scripts/run.sh amd 'https://www.youtube.com/watch?v=VIDEO_ID'

Run NVIDIA / CUDA:

    ./scripts/run.sh nvidia 'https://www.youtube.com/watch?v=VIDEO_ID'

Use a custom image tag:

    YT_WHISPER_IMAGE=registry.example.com/yt-whisper-docker:amd ./scripts/run.sh amd URL

The wrapper checks the image before downloading: a tag that is neither local nor pullable exits 1 without downloading anything.

## Cookies

The normal workflow uses host `yt-dlp`, so browser cookies stay on the host and are not baked into images.

Use a cookies file:

    YT_WHISPER_COOKIES="$HOME/Downloads/www.youtube.com_cookies.txt" ./scripts/run.sh amd URL

The wrapper passes `yt-dlp` a mode 600 temporary copy of that file (created with `mktemp` in the output directory, never in `/tmp`, removed as soon as the download ends, before the container starts, and on exit or interrupt), so `yt-dlp` does not rewrite the original export.

Use browser cookies:

    YT_WHISPER_COOKIES_FROM_BROWSER=firefox ./scripts/run.sh cpu URL
    YT_WHISPER_COOKIES_FROM_BROWSER=chrome ./scripts/run.sh cpu URL
    YT_WHISPER_COOKIES_FROM_BROWSER='chromium:/home/user/.config/chromium/Default' ./scripts/run.sh amd URL

If no cookie variable is set, the wrapper tries common local browser profiles automatically.

## Runtime variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `YT_WHISPER_OUTPUT_DIR` | `./output` | Host output directory |
| `YT_WHISPER_LANG` | auto-detected | Force language, for example `bg`, `en`, `de`; a code whisper.cpp does not support exits with 2 before the download. An auto-detected code whisper.cpp does not support falls back to whisper's own detection (`auto`) |
| `YT_WHISPER_THREADS` | `nproc` inside the container | Inference threads passed to `whisper-cli -t` |
| `YT_WHISPER_MAX_CONTEXT` | `0` | Value passed to `whisper-cli -mc` |
| `YT_WHISPER_KEEP_TEMP` | `0` | Keep downloaded audio and WAV when set to `1` |
| `YT_WHISPER_YTDLP_FORMAT` | `bestaudio/best` | Host `yt-dlp` format selector |
| `YT_WHISPER_ALLOW_LANG_MISMATCH` | `0` | Allow forced language mismatch when set to `1` |
| `YT_WHISPER_REQUIRE_GPU` | `1` for NVIDIA check | Require CUDA log verification for NVIDIA wrapper runs |
| `YT_WHISPER_IMAGE` | `yt-whisper-docker:BACKEND` | Image used by the wrapper |
| `YT_WHISPER_MODEL_FILE` | `/models/MODEL/ggml-MODEL.bin`, where `MODEL` is the image build value of `YT_WHISPER_MODEL` (default `large-v3`) | Override model path inside the container |

## Output

Default output directory:

    ./output

Generated paths:

    audio/
    wav/
    transcripts/
    logs/

By default, downloaded audio and temporary WAV are deleted after successful transcription. Use `YT_WHISPER_KEEP_TEMP=1` to keep them.

During the download `yt-dlp` keeps `.part` and fragment files in a per-run `audio/.yt-whisper-tmp.*` directory and moves only the finished file into `audio/`. That directory is removed when the download ends, fails or is interrupted.

Errors go to stderr; the `READY_*` result lines go to stdout.

Each run uses a uniquely named container (`yt-whisper-PID-RANDOM`). On Ctrl-C, `SIGTERM` or `SIGHUP` the wrapper kills that container, deletes the downloaded audio and partial WAV (unless `YT_WHISPER_KEEP_TEMP=1`), and exits with 130, 143 or 129.

## Direct image use

The image entrypoint `yt-whisper URL` runs the whole pipeline inside the container, including the download with the image's own `yt-dlp`:

    docker run --rm --user "$(id -u):$(id -g)" --device /dev/dri --group-add "$(stat -c %g /dev/dri/renderD128)" -v "$PWD/output:/out" yt-whisper-docker:amd 'https://www.youtube.com/watch?v=VIDEO_ID'

It writes to `/out` (`YT_WHISPER_OUTPUT_DIR`) and reads `YT_WHISPER_LANG`, `YT_WHISPER_THREADS`, `YT_WHISPER_MAX_CONTEXT`, `YT_WHISPER_KEEP_TEMP`, `YT_WHISPER_ALLOW_LANG_MISMATCH`, `YT_WHISPER_MODEL_FILE`, `YT_WHISPER_NO_GPU` (`1` adds `-ng`), `YT_WHISPER_YTDLP_FORMAT` (default `ba[ext=m4a]/ba`), `YT_WHISPER_COOKIES` (a cookie file path inside the container), `YT_WHISPER_COOKIES_FROM_BROWSER` and `YT_WHISPER_PROBE_ONLY` (`1` prints the detected language and exits). Each run writes a timestamped log under `logs/`. On `SIGINT`, `SIGTERM` or `SIGHUP` it deletes the downloaded audio and partial WAV (unless `YT_WHISPER_KEEP_TEMP=1`) and exits with 130, 143 or 129.

## Tests

    ./tests/run.sh

The tests run offline: `yt-dlp`, `docker`, `ffmpeg` and `whisper-cli` are replaced by stubs, so no network, image or GPU is needed. They need `zsh`, `sh` and `setsid`.
