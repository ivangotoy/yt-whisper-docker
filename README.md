# yt-whisper-docker

MAIN REPOSITORY: https://git.digtvbg.com/ivangotoy/yt-whisper-docker

READ-ONLY MIRROR: https://github.com/ivangotoy/yt-whisper-docker.git

YouTube audio transcription with host `yt-dlp`, browser-cookie support, Docker, `ffmpeg`, and `whisper.cpp`.

The host wrapper downloads YouTube audio with `yt-dlp`, then Docker converts/transcribes it with the selected `whisper.cpp` backend.

## Images

- `digtvbg.com:6000/yt-whisper-docker:cpu` - Ubuntu 26.04 CPU backend
- `digtvbg.com:6000/yt-whisper-docker:amd` - Ubuntu 26.04 Vulkan backend
- `digtvbg.com:6000/yt-whisper-docker:nvidia` - NVIDIA CUDA Ubuntu 26.04 backend

## Requirements

- Linux or WSL2
- Docker
- `yt-dlp` installed on the host
- For AMD / Vulkan: `/dev/dri`
- For NVIDIA / CUDA: NVIDIA driver and NVIDIA Container Toolkit

## Build

    ./scripts/build.sh cpu
    ./scripts/build.sh amd
    ./scripts/build.sh nvidia

Build all three serially:

    ./scripts/build.sh all

## Run

    ./scripts/run.sh cpu 'https://www.youtube.com/watch?v=VIDEO_ID'
    ./scripts/run.sh amd 'https://www.youtube.com/watch?v=VIDEO_ID'
    ./scripts/run.sh nvidia 'https://www.youtube.com/watch?v=VIDEO_ID'

## Cookies

Use a cookies file:

    YT_WHISPER_COOKIES="$HOME/Downloads/www.youtube.com_cookies.txt" ./scripts/run.sh cpu URL

Use browser cookies:

    YT_WHISPER_COOKIES_FROM_BROWSER=firefox ./scripts/run.sh cpu URL
    YT_WHISPER_COOKIES_FROM_BROWSER=chrome ./scripts/run.sh cpu URL
    YT_WHISPER_COOKIES_FROM_BROWSER='chromium:/home/user/.config/chromium/Default' ./scripts/run.sh cpu URL

## Output

Default output directory:

    ./output

Override it:

    YT_WHISPER_OUTPUT_DIR="$HOME/Downloads/yt-whisper-output" ./scripts/run.sh amd URL

Generated files are under:

    audio/
    wav/
    transcripts/
    logs/

## Language

Default is automatic language detection.

Force language:

    YT_WHISPER_LANG=en ./scripts/run.sh cpu URL
    YT_WHISPER_LANG=bg ./scripts/run.sh amd URL

Long audio uses `YT_WHISPER_MAX_CONTEXT=0` by default unless overridden.
