#!/usr/bin/env sh
set -eu

backend="${1:-}"
url="${2:-}"

if [ -z "$backend" ] || [ -z "$url" ]; then
  printf 'usage: ./scripts/run.sh cpu|amd|nvidia <youtube-url>\n'
  exit 1
fi

out_dir="$PWD/output"
mkdir -p "$out_dir"

case "$backend" in
  cpu)
    docker run --rm -it \
      --user "$(id -u):$(id -g)" \
      -e "YT_WHISPER_HOST_OUT=$out_dir" \
      -v "$out_dir:/out" \
      "yt-whisper-docker:cpu" \
      "$url"
    ;;
  amd|vulkan|amd-vulkan)
    render_gid="$(stat -c '%g' /dev/dri/renderD128 2>/dev/null || true)"
    if [ -n "$render_gid" ]; then
      docker run --rm -it \
        --device /dev/dri:/dev/dri \
        --group-add "$render_gid" \
        --user "$(id -u):$(id -g)" \
        -e "YT_WHISPER_HOST_OUT=$out_dir" \
        -v "$out_dir:/out" \
        "yt-whisper-docker:amd" \
        "$url"
    else
      docker run --rm -it \
        --device /dev/dri:/dev/dri \
        --user "$(id -u):$(id -g)" \
        -e "YT_WHISPER_HOST_OUT=$out_dir" \
        -v "$out_dir:/out" \
        "yt-whisper-docker:amd" \
        "$url"
    fi
    ;;
  nvidia|cuda|nvidia-cuda)
    docker run --rm -it \
      --gpus all \
      --user "$(id -u):$(id -g)" \
      -e "YT_WHISPER_HOST_OUT=$out_dir" \
      -v "$out_dir:/out" \
      "yt-whisper-docker:nvidia" \
      "$url"
    ;;
  *)
    printf 'usage: ./scripts/run.sh cpu|amd|nvidia <youtube-url>\n'
    exit 1
    ;;
esac
