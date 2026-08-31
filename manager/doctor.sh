#!/usr/bin/env bash
set -euo pipefail

manager="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${CODEX_PROJECT_SESSION_BROWSER_ROOT:-$(dirname "$manager")}"
official_package="${CODEX_PROJECT_SESSION_BROWSER_OFFICIAL_PACKAGE:-$(npm root -g)/@openai/codex}"
version="$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).version" "$official_package/package.json")"
current_version="$(cat "$root/current-version" 2>/dev/null || true)"
current="$root/bin/codex-current"
launcher="${CODEX_PROJECT_SESSION_BROWSER_LAUNCHER:-$HOME/.local/bin/codex}"
upstream="${CODEX_PROJECT_SESSION_BROWSER_UPSTREAM:-$HOME/.local/bin/codex-upstream}"
expected_patch_sha="$(sha256sum "$manager/project-browser.patch" | awk '{print $1}')"
status=0

check() {
  local label="$1"
  shift
  if "$@"; then
    printf '%s: OK\n' "$label"
  else
    printf '%s: FAILED\n' "$label" >&2
    status=1
  fi
}

check version test "$current_version" = "$version"
check public-launcher test "$(readlink -f "$launcher" 2>/dev/null || true)" = "$manager/dispatch.sh"
check upstream-launcher test -x "$upstream"
check runtime-launcher test -x "$current"

real_target="$(readlink -f "$current" 2>/dev/null || true)"
package_dir="$(dirname "$(dirname "$real_target")")"
installed_patch_sha="$(cat "$package_dir/project-browser-patch.sha256" 2>/dev/null || true)"

check patch test "$installed_patch_sha" = "$expected_patch_sha"
check codex test -x "$real_target"
check host test -x "$package_dir/bin/codex-code-mode-host"
check manifest test -f "$package_dir/codex-package.json"
check rg test -x "$package_dir/codex-path/rg"
check bwrap test -x "$package_dir/codex-resources/bwrap"

if [[ -x "$real_target" ]]; then
  binary_version="$("$real_target" --version 2>/dev/null || true)"
  check binary-version test "$binary_version" = "codex-cli $version"
fi

exit "$status"
