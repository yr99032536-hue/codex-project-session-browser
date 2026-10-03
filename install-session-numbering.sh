#!/usr/bin/env bash
set -euo pipefail

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${CODEX_PROJECT_SESSION_BROWSER_ROOT:-$HOME/.local/share/codex-project-session-browser}"
unit_dir="$HOME/.config/systemd/user"

command -v python3 >/dev/null
command -v systemctl >/dev/null
[[ -x "$root/bin/codex-current" ]] || { printf 'install the project browser first\n' >&2; exit 1; }
mkdir -p "$root/manager" "$unit_dir"
install -m 0644 "$source_root/manager/session_numbering.py" "$root/manager/session_numbering.py"
install -m 0644 "$source_root/manager/codex_rpc.py" "$root/manager/codex_rpc.py"
sed "s|%h/.local/share/codex-project-session-browser|$root|g" \
  "$source_root/systemd/codex-project-session-browser-numbering.service" \
  > "$unit_dir/codex-project-session-browser-numbering.service"
systemctl --user daemon-reload
systemctl --user enable --now codex-project-session-browser-numbering.service
systemctl --user restart codex-project-session-browser-numbering.service
systemctl --user status codex-project-session-browser-numbering.service --no-pager
