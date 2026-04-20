#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <release-dir-or-zip>" >&2
  exit 2
fi

INPUT="$1"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -d "$INPUT" ]]; then
  cp -R "$INPUT" "$TMP_DIR/"
  PACKAGE_DIR="$TMP_DIR/$(basename "$INPUT")"
elif [[ -f "$INPUT" ]]; then
  ditto -x -k "$INPUT" "$TMP_DIR/"
  PACKAGE_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
else
  echo "input does not exist: $INPUT" >&2
  exit 2
fi

if [[ -z "${PACKAGE_DIR:-}" || ! -d "$PACKAGE_DIR" ]]; then
  echo "failed to discover extracted package directory" >&2
  exit 1
fi

LAUNCHER="$PACKAGE_DIR/run-centralbanker"
if [[ ! -x "$LAUNCHER" ]]; then
  echo "missing launcher script: $LAUNCHER" >&2
  exit 1
fi

for required in README.md PLAYER_GUIDE.md CHANGELOG.md VERSION BUILD_INFO.txt Config; do
  if [[ ! -e "$PACKAGE_DIR/$required" ]]; then
    echo "missing packaged release artifact: $PACKAGE_DIR/$required" >&2
    exit 1
  fi
done

SANDBOX_CWD="$TMP_DIR/run-from-here"
mkdir -p "$SANDBOX_CWD"

(
  cd "$SANDBOX_CWD"
  "$LAUNCHER" --help >/dev/null
  "$LAUNCHER" --balance --mode h --length s --difficulty g --bot passive --runs 1 >/dev/null
)

echo "Smoke test passed for $PACKAGE_DIR"
