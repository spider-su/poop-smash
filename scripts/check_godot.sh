#!/usr/bin/env bash
# Godot can report a GDScript/import error while still returning status zero.
set -uo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi
if grep -Eq '(^ERROR:|SCRIPT ERROR:|Parse Error:)' "$log"; then
  exit 1
fi
