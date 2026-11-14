ARG UBUNTU_IMAGE=registry.example.com/home/ubuntu:latest
ARG WHISPER_CPP_REF=master
ARG YT_WHISPER_MODEL=large-v3
ARG WHISPER_BACKEND=cpu
ARG YT_WHISPER_NO_GPU=0
ARG BUILD_JOBS=2
ARG YT_DLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"

FROM ${UBUNTU_IMAGE} AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl git bash cmake build-essential pkg-config libvulkan-dev glslang-tools glslc spirv-headers && \
    rm -rf /var/lib/apt/lists/*

# Source and model layers do not depend on the backend, so the cpu and amd
# builds share them (one clone and one model download for both flavors).
ARG WHISPER_CPP_REF
RUN git init -q /src && \
    cd /src && \
    git fetch -q --depth 1 https://github.com/ggml-org/whisper.cpp.git "$WHISPER_CPP_REF" && \
    git checkout -q --detach FETCH_HEAD && \
    git rev-parse HEAD > /whisper-cpp-revision.txt

ARG YT_WHISPER_MODEL
RUN mkdir -p "/models/$YT_WHISPER_MODEL" && \
    bash /src/models/download-ggml-model.sh "$YT_WHISPER_MODEL" "/models/$YT_WHISPER_MODEL"

ARG WHISPER_BACKEND
ARG BUILD_JOBS
RUN cd /src && \
    case "$WHISPER_BACKEND" in \
      cpu) cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF ;; \
      vulkan) cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF -DGGML_VULKAN=ON ;; \
      *) echo "invalid WHISPER_BACKEND=$WHISPER_BACKEND" >&2; exit 1 ;; \
    esac && \
    cmake --build build --target whisper-cli -j"$BUILD_JOBS" && \
    mkdir -p /whisper-libs && \
    find /src/build -type f \( -name "libwhisper.so*" -o -name "libggml*.so*" \) -exec cp -av {} /whisper-libs/ \;

FROM ${UBUNTU_IMAGE}

ARG YT_WHISPER_MODEL
ARG WHISPER_BACKEND
ARG YT_WHISPER_NO_GPU
ARG YT_DLP_URL

ENV DEBIAN_FRONTEND=noninteractive
ENV YT_WHISPER_MODEL="${YT_WHISPER_MODEL}"
ENV WHISPER_BACKEND="${WHISPER_BACKEND}"
ENV YT_WHISPER_LANG="auto"
ENV YT_WHISPER_NO_GPU="${YT_WHISPER_NO_GPU}"

# The Vulkan loader and Mesa drivers are only needed by the vulkan build.
RUN case "$WHISPER_BACKEND" in \
      vulkan) gpu_pkgs="libvulkan1 mesa-vulkan-drivers" ;; \
      *) gpu_pkgs="" ;; \
    esac && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl ffmpeg libgomp1 libstdc++6 $gpu_pkgs && \
    curl -fsSL "$YT_DLP_URL" -o /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /src/build/bin/whisper-cli /usr/local/bin/whisper-cli
COPY --from=build /whisper-libs/ /usr/local/lib/
COPY --from=build /models /models
COPY --from=build /whisper-cpp-revision.txt /usr/local/share/whisper-cpp-revision.txt
COPY yt-whisper /usr/local/bin/yt-whisper

RUN chmod +x /usr/local/bin/whisper-cli /usr/local/bin/yt-whisper && ldconfig

ENTRYPOINT ["/usr/local/bin/yt-whisper"]
