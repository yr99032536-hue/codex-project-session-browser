#!/usr/bin/env bash
set -euo pipefail

bin_dir="$HOME/.local/bin"
launcher="$bin_dir/codex"
upstream="$bin_dir/codex-upstream"
unit_dir="$HOME/.config/systemd/user"

if [[ ! -e "$upstream" ]]; then
  printf 'official launcher is missing: %s\n' "$upstream" >&2
  exit 1
fi

ln -sfn "$upstream" "$launcher"

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now codex-project-session-browser-update.timer >/dev/null 2>&1 || true
  rm -f \
    "$unit_dir/codex-project-session-browser-update.service" \
    "$unit_dir/codex-project-session-browser-update.timer"
  systemctl --user daemon-reload
fi

printf 'restored official Codex launcher: %s -> %s\n' "$launcher" "$upstream"
