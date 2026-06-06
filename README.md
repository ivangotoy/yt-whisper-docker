# yt-whisper-docker

MAIN REPOSITORY: https://git.digtvbg.com/ivangotoy/yt-whisper-docker

READ-ONLY MIRROR: https://github.com/ivangotoy/yt-whisper-docker.git

YouTube audio transcription with yt-dlp, whisper.cpp, and Docker.

The project downloads audio from a YouTube URL, converts it to WAV, transcribes it with whisper.cpp, and writes TXT, SRT, and log files.

## Supported backends

- cpu: CPU-only whisper.cpp image
- amd: AMD / Intel GPU acceleration through Vulkan
- nvidia: NVIDIA GPU acceleration through CUDA

## Requirements

- Linux or WSL2
- Docker
- Internet access during image build
- For AMD / Vulkan: /dev/dri must be available on the Linux host
- For NVIDIA / CUDA: NVIDIA driver and NVIDIA Container Toolkit must be installed

## Building

Build the CPU image:

    ./scripts/build.sh cpu

Build the AMD / Vulkan image:

    ./scripts/build.sh amd

Build the NVIDIA / CUDA image:

    ./scripts/build.sh nvidia

The large-v3 model is downloaded and baked into the image during build.

## Running

Run with CPU:

    ./scripts/run.sh cpu 'https://www.youtube.com/watch?v=VIDEO_ID'

Run with AMD / Vulkan:

    ./scripts/run.sh amd 'https://www.youtube.com/watch?v=VIDEO_ID'

Run with NVIDIA / CUDA:

    ./scripts/run.sh nvidia 'https://www.youtube.com/watch?v=VIDEO_ID'

## Language selection

Language detection is automatic by default.

Force Bulgarian:

    YT_WHISPER_LANG=bg ./scripts/run.sh cpu 'https://www.youtube.com/watch?v=VIDEO_ID'

Force English:

    YT_WHISPER_LANG=en ./scripts/run.sh amd 'https://www.youtube.com/watch?v=VIDEO_ID'

Force German:

    YT_WHISPER_LANG=de ./scripts/run.sh nvidia 'https://www.youtube.com/watch?v=VIDEO_ID'

## Output

Transcript text:

    output/transcripts/*.txt

Subtitles:

    output/transcripts/*.srt

Logs:

    output/logs/*.log

Temporary downloaded audio and WAV files:

    output/audio/
    output/wav/

After transcription, the script asks whether to delete the downloaded audio and temporary WAV file.

## Long audio stability

The default max context is set to `0` to avoid Whisper long-form repetition loops on long videos.

Override it only if needed:

    YT_WHISPER_MAX_CONTEXT=-1 ./scripts/run.sh cpu 'https://www.youtube.com/watch?v=VIDEO_ID'

