#!/usr/bin/env zsh
set -e
set -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT_DIR/yt-whisper-docker" "$@"
