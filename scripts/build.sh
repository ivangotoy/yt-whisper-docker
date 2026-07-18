#!/usr/bin/env zsh
set -e
set -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="${REGISTRY:-}"
IMAGE_NAME="${IMAGE_NAME:-yt-whisper-docker}"
UBUNTU_IMAGE="${UBUNTU_IMAGE:-digtvbg.com:6000/home/ubuntu:latest}"
UBUNTU_VERSION="${UBUNTU_VERSION:-26.04}"
CUDA_VERSION="${CUDA_VERSION:-13.3.0}"
WHISPER_CPP_REF="${WHISPER_CPP_REF:-master}"
YT_WHISPER_MODEL="${YT_WHISPER_MODEL:-large-v3}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc 2>/dev/null || printf 2)}"
NVIDIA_BUILD_JOBS="${NVIDIA_BUILD_JOBS:-24}"
CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES:-75;80;86;90}"
BACKEND="${1:-all}"

image_tag() {
  if [[ -n "$REGISTRY" ]]; then
    printf '%s/%s:%s\n' "$REGISTRY" "$IMAGE_NAME" "$1"
  else
    printf '%s:%s\n' "$IMAGE_NAME" "$1"
  fi
}

build_cpu() {
  docker buildx build --load \
    --build-arg UBUNTU_IMAGE="$UBUNTU_IMAGE" \
    --build-arg WHISPER_CPP_REF="$WHISPER_CPP_REF" \
    --build-arg YT_WHISPER_MODEL="$YT_WHISPER_MODEL" \
    --build-arg WHISPER_BACKEND=cpu \
    --build-arg YT_WHISPER_NO_GPU=1 \
    --build-arg BUILD_JOBS="$BUILD_JOBS" \
    -t "$(image_tag cpu)" \
    -f "$ROOT_DIR/Dockerfile" \
    "$ROOT_DIR"
}

build_amd() {
  docker buildx build --load \
    --build-arg UBUNTU_IMAGE="$UBUNTU_IMAGE" \
    --build-arg WHISPER_CPP_REF="$WHISPER_CPP_REF" \
    --build-arg YT_WHISPER_MODEL="$YT_WHISPER_MODEL" \
    --build-arg WHISPER_BACKEND=vulkan \
    --build-arg YT_WHISPER_NO_GPU=0 \
    --build-arg BUILD_JOBS="$BUILD_JOBS" \
    -t "$(image_tag amd)" \
    -f "$ROOT_DIR/Dockerfile" \
    "$ROOT_DIR"
}

build_nvidia() {
  docker buildx build --load \
    --build-arg CUDA_VERSION="$CUDA_VERSION" \
    --build-arg UBUNTU_VERSION="$UBUNTU_VERSION" \
    --build-arg BASE_CUDA_DEV_CONTAINER="nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}" \
    --build-arg BASE_CUDA_RUN_CONTAINER="nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}" \
    --build-arg WHISPER_CPP_REF="$WHISPER_CPP_REF" \
    --build-arg YT_WHISPER_MODEL="$YT_WHISPER_MODEL" \
    --build-arg BUILD_JOBS="$NVIDIA_BUILD_JOBS" \
    --build-arg CMAKE_CUDA_ARCHITECTURES="$CMAKE_CUDA_ARCHITECTURES" \
    -t "$(image_tag nvidia)" \
    -f "$ROOT_DIR/Dockerfile.nvidia" \
    "$ROOT_DIR"
}

case "$BACKEND" in
  cpu) build_cpu ;;
  amd) build_amd ;;
  nvidia) build_nvidia ;;
  all)
    build_cpu
    build_amd
    build_nvidia
    ;;
  *)
    printf 'usage: %s [cpu|amd|nvidia|all]\n' "$0" >&2
    exit 1
    ;;
esac
