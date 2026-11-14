#!/usr/bin/env zsh
# Offline regression tests for yt-whisper-docker (host wrapper) and
# yt-whisper (image entrypoint). yt-dlp, docker, ffmpeg and whisper-cli are
# replaced by stubs; nothing touches the network, Docker or a GPU.
#
#   ./tests/run.sh            run every test
#   YT_WHISPER_TEST_SH=dash ./tests/run.sh   run the entrypoint with another sh
emulate -L zsh
setopt no_unset pipe_fail

ROOT_DIR="${0:A:h:h}"
TEST_SH="${YT_WHISPER_TEST_SH:-sh}"
work="$(mktemp -d "$ROOT_DIR/tests/.tmp.XXXXXX")" || exit 1
trap 'rm -rf -- "$work"' EXIT
stubs="$work/stubs"
mkdir -p "$stubs"
pass=0
fail=0
failed=()

# --- stubs -------------------------------------------------------------------

# yt-dlp: logs every call (one NUL-separated record per call), answers the
# language probe with $STUB_LANG and "downloads" a file. Download location
# follows yt-dlp rules: intermediate files go to -P temp:DIR (else the final
# dir), the final file to -P home:DIR joined with a relative -o, or the
# directory of an absolute -o.
cat >"$stubs/yt-dlp" <<'EOF'
#!/usr/bin/env zsh
{ print -rn -- "CALL"; for a in "$@"; do print -rn -- $'\0'"$a"; done; print; } >>"$STUB_LOG"
home="" temp="" tmpl="" probe=0
while (( $# )); do
  case "$1" in
    -P) case "$2" in home:*) home="${2#home:}" ;; temp:*) temp="${2#temp:}" ;; esac; shift ;;
    -o) tmpl="$2"; shift ;;
    --skip-download) probe=1 ;;
    --cookies-from-browser) [[ -n "$2" ]] || { print -u2 "yt-dlp stub: empty browser"; exit 2; }; shift ;;
    --cookies) [[ -f "$2" ]] || exit 2; shift ;;
  esac
  shift
done
if (( probe )); then
  [[ -n "${STUB_PROBE_FAIL:-}" ]] && exit 1
  print -r -- "${STUB_LANG:-en}"
  exit 0
fi
name="Test_Title-abc123.m4a"
if [[ "$tmpl" == /* ]]; then final_dir="${tmpl:h}"; else final_dir="${home:-$PWD}"; fi
part_dir="${temp:-$final_dir}"
mkdir -p "$part_dir" "$final_dir"
print -r -- "partial" >"$part_dir/$name.part"
if [[ -n "${STUB_DOWNLOAD_SLEEP:-}" ]]; then
  : >"$STUB_READY"
  sleep "$STUB_DOWNLOAD_SLEEP"
  exit 1
fi
mv -- "$part_dir/$name.part" "$final_dir/$name"
print -r -- "$final_dir/$name"
EOF

# docker: "run" emulates the container: it reads -v SRC:/out and the -e
# variables, writes the transcript and log, and records what it saw.
cat >"$stubs/docker" <<'EOF'
#!/usr/bin/env zsh
case "$1" in
  kill) exit 0 ;;
  run) ;;
  *) exit 0 ;;
esac
shift
src="" ; typeset -A env
while (( $# )); do
  case "$1" in
    -v) src="${2%%:/out}"; shift ;;
    -e) env[${2%%=*}]="${2#*=}"; shift ;;
    --name|--user|--device|--group-add|--gpus|--entrypoint) shift ;;
    -*) ;;
    *) break ;;
  esac
  shift
done
{
  print -r -- "WHISPER_LANG=${env[WHISPER_LANG]:-}"
  cookies=("$src"/.yt-whisper-cookies.*(N))
  print -r -- "COOKIE_FILES=${#cookies}"
} >>"$STUB_DOCKER_LOG"
stem="${env[STEM]}"
mkdir -p "$src/transcripts" "$src/logs" "$src/wav"
print -r -- "hello" >"$src/transcripts/$stem.txt"
: >"$src/transcripts/$stem.srt"
print -r -- "whisper_backend_init_gpu: using Vulkan0 backend" >"$src/logs/$stem.log"
EOF

# ffmpeg and whisper-cli for the image entrypoint.
cat >"$stubs/ffmpeg" <<'EOF'
#!/usr/bin/env sh
for a; do last="$a"; done
printf 'wav\n' >"$last"
EOF
cat >"$stubs/whisper-cli" <<'EOF'
#!/usr/bin/env sh
lang="" of=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -l) lang="$2"; shift ;;
    -of) of="$2"; shift ;;
  esac
  shift
done
printf 'LANG=%s\n' "$lang" >>"$STUB_WHISPER_LOG"
if [ -n "${STUB_WHISPER_SLEEP:-}" ]; then
  : >"$STUB_READY"
  sleep "$STUB_WHISPER_SLEEP"
fi
printf 'text\n' >"$of.txt"
: >"$of.srt"
EOF
chmod +x "$stubs"/*

# --- helpers -----------------------------------------------------------------

# new_case NAME: fresh HOME, output dir and logs for one test.
new_case() {
  case_dir="$work/$1"
  mkdir -p "$case_dir/home" "$case_dir/out"
  export HOME="$case_dir/home"
  export STUB_LOG="$case_dir/yt-dlp.calls" STUB_DOCKER_LOG="$case_dir/docker.calls"
  export STUB_WHISPER_LOG="$case_dir/whisper.calls" STUB_READY="$case_dir/ready"
  : >"$STUB_LOG"; : >"$STUB_DOCKER_LOG"; : >"$STUB_WHISPER_LOG"
  unset STUB_LANG STUB_PROBE_FAIL STUB_DOWNLOAD_SLEEP STUB_WHISPER_SLEEP \
    YT_WHISPER_LANG YT_WHISPER_COOKIES YT_WHISPER_COOKIES_FROM_BROWSER YT_WHISPER_KEEP_TEMP
  export PATH="$stubs:$ORIG_PATH"
}

ok() { pass=$((pass + 1)); print -r -- "ok   $current"; }
bad() { fail=$((fail + 1)); failed+=("$current"); print -r -- "FAIL $current: $*"; }

run_wrapper() { YT_WHISPER_OUTPUT_DIR="$case_dir/out" "$ROOT_DIR/yt-whisper-docker" "$@" >"$case_dir/stdout" 2>"$case_dir/stderr"; }
run_entry() { YT_WHISPER_OUTPUT_DIR="$case_dir/out" YT_WHISPER_MODEL_FILE="$case_dir/model.bin" "$TEST_SH" "$ROOT_DIR/yt-whisper" "$@" >"$case_dir/stdout" 2>"$case_dir/stderr"; }

# wait_ready: wait up to 10 s for a stub to signal that it is running.
wait_ready() {
  local i
  for i in {1..100}; do [[ -e "$STUB_READY" ]] && return 0; sleep 0.1; done
  return 1
}

ORIG_PATH="$PATH"
URL='https://www.youtube.com/watch?v=abc123'

# --- tests -------------------------------------------------------------------

current="wrapper: no browser profile means no --cookies-from-browser call"
new_case no-browser
run_wrapper cpu "$URL"
rc=$?
if (( rc != 0 )); then bad "rc=$rc $(<$case_dir/stderr)"
elif grep -q -- '--cookies-from-browser' "$STUB_LOG"; then bad "called: $(tr '\0' ' ' <"$STUB_LOG")"
elif (( $(grep -c '^CALL' "$STUB_LOG") != 2 )); then bad "expected 2 yt-dlp calls, got $(grep -c '^CALL' "$STUB_LOG")"
else ok; fi


current="wrapper: Javanese (jv/jw) reaches whisper as jw"
new_case wrapper-jv
STUB_LANG=jv run_wrapper cpu "$URL"
rc=$?
if (( rc != 0 )); then bad "rc=$rc"
elif ! grep -qx 'WHISPER_LANG=jw' "$STUB_DOCKER_LOG"; then bad "$(<$STUB_DOCKER_LOG)"
else ok; fi


current="wrapper: detected language whisper does not know falls back to auto"
new_case wrapper-unknown
STUB_LANG=zxx run_wrapper cpu "$URL"
rc=$?
if (( rc != 0 )); then bad "rc=$rc"
elif ! grep -qx 'WHISPER_LANG=auto' "$STUB_DOCKER_LOG"; then bad "$(<$STUB_DOCKER_LOG)"
else ok; fi


current="wrapper: forced unsupported language fails before the download"
new_case wrapper-forced-unknown
YT_WHISPER_LANG=zxx STUB_LANG=zxx run_wrapper cpu "$URL"
rc=$?
if (( rc != 2 )); then bad "rc=$rc"
elif grep -q -- 'after_move' "$STUB_LOG"; then bad "download ran"
else ok; fi


current="wrapper: cookie copy is gone before the container starts"
new_case wrapper-cookie
print -r -- "# Netscape HTTP Cookie File" >"$case_dir/cookies.txt"
YT_WHISPER_COOKIES="$case_dir/cookies.txt" run_wrapper cpu "$URL"
rc=$?
if (( rc != 0 )); then bad "rc=$rc $(<$case_dir/stderr)"
elif ! grep -qx 'COOKIE_FILES=0' "$STUB_DOCKER_LOG"; then bad "cookie copy visible in /out: $(<$STUB_DOCKER_LOG)"
elif [[ -n "$(print -rl -- "$case_dir"/out/.yt-whisper-cookies.*(N))" ]]; then bad "cookie copy left"
else ok; fi


current="entrypoint: Javanese (jv) reaches whisper as jw"
new_case entry-jv
: >"$case_dir/model.bin"
STUB_LANG=jv run_entry "$URL"
rc=$?
if (( rc != 0 )); then bad "rc=$rc $(<$case_dir/stderr)"
elif ! grep -qx 'LANG=jw' "$STUB_WHISPER_LOG"; then bad "$(<$STUB_WHISPER_LOG)"
else ok; fi


current="entrypoint: detected language whisper does not know falls back to auto"
new_case entry-unknown
: >"$case_dir/model.bin"
STUB_LANG=fil run_entry "$URL"
rc=$?
if (( rc != 0 )); then bad "rc=$rc $(<$case_dir/stderr)"
elif ! grep -qx 'LANG=auto' "$STUB_WHISPER_LOG"; then bad "$(<$STUB_WHISPER_LOG)"
else ok; fi


current="entrypoint: forced unsupported language fails before the download"
new_case entry-forced-unknown
: >"$case_dir/model.bin"
YT_WHISPER_LANG=fil STUB_LANG=fil run_entry "$URL"
rc=$?
if (( rc != 2 )); then bad "rc=$rc"
elif grep -q -- 'after_move' "$STUB_LOG"; then bad "download ran"
else ok; fi


print -r -- "passed=$pass failed=$fail"
(( fail == 0 ))
