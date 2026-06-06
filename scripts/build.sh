#!/usr/bin/env sh
set -eu

backend="${1:-cpu}"

case "$backend" in
  cpu)
    tag="main"
    image="yt-whisper-docker:cpu"
    ;;
  amd|vulkan|amd-vulkan)
    tag="main-vulkan"
    image="yt-whisper-docker:amd"
    ;;
  nvidia|cuda|nvidia-cuda)
    tag="main-cuda"
    image="yt-whisper-docker:nvidia"
    ;;
  *)
    printf 'usage: ./scripts/build.sh cpu|amd|nvidia\n'
    exit 1
    ;;
esac

docker build \
  --build-arg "WHISPER_IMAGE_TAG=$tag" \
  -t "$image" \
  .
