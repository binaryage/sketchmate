#!/usr/bin/env bash

set -e -o pipefail

pushd() {
  command pushd "$@" >/dev/null
}

popd() {
  command popd >/dev/null
}

pushd .
cd "$(dirname "${BASH_SOURCE[0]}")"
ROOT=$(pwd)
SCRIPTS="$ROOT/scripts"
popd

APP_NAME=${SKETCHMATE_APP_NAME:-SketchUp}
BACKEND_LAUNCHER=${SKETCHMATE_BACKEND_LAUNCHER:-$ROOT/projects/sketchmate-backend/launch.rb}
SKETCHUP_OUT_FILE=${SKETCHMATE_SKETCHUP_OUT_FILE:-"$ROOT/.tmp/sketchup_out.txt"}
SKETCHUP_ERR_FILE=${SKETCHMATE_SKETCHUP_ERR_FILE:-"$ROOT/.tmp/sketchup_err.txt"}

OUT_FILE_DIR=$(dirname "$SKETCHUP_OUT_FILE")
if [[ ! -d "$OUT_FILE_DIR" ]]; then
  mkdir -p "$OUT_FILE_DIR"
fi

ERR_FILE_DIR=$(dirname "$SKETCHUP_ERR_FILE")
if [[ ! -d "$ERR_FILE_DIR" ]]; then
  mkdir -p "$ERR_FILE_DIR"
fi

if [[ -e "$SKETCHUP_OUT_FILE" ]]; then
  rm "$SKETCHUP_OUT_FILE"
fi

if [[ -e "$SKETCHUP_ERR_FILE" ]]; then
  rm "$SKETCHUP_ERR_FILE"
fi

sigterm_handler() {
  echo "Shutdown signal received."
  set -x
  osascript "$SCRIPTS/shutdown.applescript"
  exit 1
}

trap 'trap " " SIGINT SIGTERM SIGHUP; kill 0; wait; sigterm_handler' SIGINT SIGTERM SIGHUP

args=()
args+=(--stdout "$SKETCHUP_OUT_FILE" --stderr "$SKETCHUP_ERR_FILE")
args+=(-a "$APP_NAME")
args+=(--args)
if [[ -n "$SKETCHMATE_RDEBUG" ]]; then
  args+=(-rdebug "$SKETCHMATE_RDEBUG")
fi
args+=(-RubyStartup "$BACKEND_LAUNCHER")

# Sketchup output is quite busy, display only errors

touch "$SKETCHUP_ERR_FILE"
tail -f "$SKETCHUP_ERR_FILE" &

set -x
open -W "${args[@]}" "$@"
set +x

