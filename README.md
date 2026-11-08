# yt-whisper-docker

MAIN REPOSITORY: https://git.digtvbg.com/ivangotoy/yt-whisper-docker

READ-ONLY MIRROR: https://github.com/ivangotoy/yt-whisper-docker.git

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
- For AMD / Vulkan: `/dev/dri`
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
| `UBUNTU_IMAGE` | `registry.example.com/home/ubuntu:latest` | cpu, amd |
| `UBUNTU_VERSION` | `26.04` | nvidia (`nvidia/cuda` tag suffix) |
| `CUDA_VERSION` | `13.3.0` | nvidia |
| `WHISPER_CPP_REF` | `master` | all |
| `YT_WHISPER_MODEL` | `large-v3` | all |
| `BUILD_JOBS` | `nproc` | cpu, amd |
| `NVIDIA_BUILD_JOBS` | `24` | nvidia |
| `CMAKE_CUDA_ARCHITECTURES` | `75;80;86;90` | nvidia |

## Run

Run CPU:

    ./scripts/run.sh cpu 'https://www.youtube.com/watch?v=VIDEO_ID'

Run AMD / Vulkan:

    ./scripts/run.sh amd 'https://www.youtube.com/watch?v=VIDEO_ID'

Run NVIDIA / CUDA:

    ./scripts/run.sh nvidia 'https://www.youtube.com/watch?v=VIDEO_ID'

Use a custom image tag:

    YT_WHISPER_IMAGE=registry.example.com/yt-whisper-docker:amd ./scripts/run.sh amd URL

## Cookies

The normal workflow uses host `yt-dlp`, so browser cookies stay on the host and are not baked into images.

Use a cookies file:

    YT_WHISPER_COOKIES="$HOME/Downloads/www.youtube.com_cookies.txt" ./scripts/run.sh amd URL

The wrapper passes `yt-dlp` a mode 600 temporary copy of that file (created with `mktemp` in the output directory, never in `/tmp`, removed on exit and on interrupt), so `yt-dlp` does not rewrite the original export.

Use browser cookies:

    YT_WHISPER_COOKIES_FROM_BROWSER=firefox ./scripts/run.sh cpu URL
    YT_WHISPER_COOKIES_FROM_BROWSER=chrome ./scripts/run.sh cpu URL
    YT_WHISPER_COOKIES_FROM_BROWSER='chromium:/home/user/.config/chromium/Default' ./scripts/run.sh amd URL

If no cookie variable is set, the wrapper tries common local browser profiles automatically.

## Runtime variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `YT_WHISPER_OUTPUT_DIR` | `./output` | Host output directory |
| `YT_WHISPER_LANG` | auto-detected | Force language, for example `bg`, `en`, `de` |
| `YT_WHISPER_THREADS` | `nproc` inside the container | Inference threads passed to `whisper-cli -t` |
| `YT_WHISPER_MAX_CONTEXT` | `0` | Value passed to `whisper-cli -mc` |
| `YT_WHISPER_KEEP_TEMP` | `0` | Keep downloaded audio and WAV when set to `1` |
| `YT_WHISPER_YTDLP_FORMAT` | `bestaudio/best` | Host `yt-dlp` format selector |
| `YT_WHISPER_ALLOW_LANG_MISMATCH` | `0` | Allow forced language mismatch when set to `1` |
| `YT_WHISPER_REQUIRE_GPU` | `1` for NVIDIA check | Require CUDA log verification for NVIDIA wrapper runs |
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

Each run uses a uniquely named container (`yt-whisper-PID-RANDOM`). On Ctrl-C, `SIGTERM` or `SIGHUP` the wrapper kills that container, deletes the downloaded audio and partial WAV (unless `YT_WHISPER_KEEP_TEMP=1`), and exits with 130, 143 or 129.

## Verification status

CPU was built and runtime verified:

    use gpu = 0
    n_threads = 32 / 32

AMD / Vulkan was built and runtime verified on AMD Radeon RX 9070 XT:

    Vulkan0 backend
    n_threads = 32 / 32
    output files owned by the host user

NVIDIA / CUDA was built and static-image verified:

    yt-dlp present
    ffmpeg present
    whisper-cli present
    model present
    YT_WHISPER_THREADS support present
    WHISPER_BACKEND=cuda present

NVIDIA runtime inference requires a host with NVIDIA GPU and NVIDIA Container Toolkit.
