#!/usr/bin/env bash
set -euo pipefail

bin_dir="$HOME/.local/bin"
launcher="$bin_dir/codex"
upstream="$bin_dir/codex-upstream"

if [[ ! -e "$upstream" ]]; then
  printf 'official launcher is missing: %s\n' "$upstream" >&2
  exit 1
fi

ln -sfn "$upstream" "$launcher"
printf 'restored official Codex launcher: %s -> %s\n' "$launcher" "$upstream"
