ARG WHISPER_IMAGE_TAG=main
FROM ghcr.io/ggml-org/whisper.cpp:${WHISPER_IMAGE_TAG}

ARG YT_DLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"
ARG YT_WHISPER_MODEL="large-v3"

ENV YT_WHISPER_MODEL="${YT_WHISPER_MODEL}"
ENV YT_WHISPER_LANG="auto"

RUN curl -fsSL "$YT_DLP_URL" -o /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp && \
    mkdir -p "/models/$YT_WHISPER_MODEL" /out && \
    /app/models/download-ggml-model.sh "$YT_WHISPER_MODEL" "/models/$YT_WHISPER_MODEL"

COPY yt-whisper /usr/local/bin/yt-whisper
RUN chmod +x /usr/local/bin/yt-whisper

ENTRYPOINT ["/usr/local/bin/yt-whisper"]
