#!/usr/bin/env bash
set -euo pipefail

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="$HOME/.config/systemd/user"

if ! command -v systemctl >/dev/null 2>&1; then
  printf 'systemctl is required to install the daily update timer\n' >&2
  exit 1
fi

mkdir -p "$unit_dir"
install -m 0644 \
  "$source_root/systemd/codex-project-session-browser-update.service" \
  "$unit_dir/codex-project-session-browser-update.service"
install -m 0644 \
  "$source_root/systemd/codex-project-session-browser-update.timer" \
  "$unit_dir/codex-project-session-browser-update.timer"

systemctl --user daemon-reload
systemctl --user enable --now codex-project-session-browser-update.timer
systemctl --user status codex-project-session-browser-update.timer --no-pager
