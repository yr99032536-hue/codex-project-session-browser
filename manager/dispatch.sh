#!/usr/bin/env bash
set -uo pipefail

manager="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$manager")"
manager="$root/manager"
upstream="$HOME/.local/bin/codex-upstream"
launcher="$HOME/.local/bin/codex"

restore_launcher() {
  ln -sfn "$manager/dispatch.sh" "$launcher"
}

official_package() {
  if [[ -n "${CODEX_PROJECT_SESSION_BROWSER_OFFICIAL_PACKAGE:-}" ]]; then
    printf '%s\n' "$CODEX_PROJECT_SESSION_BROWSER_OFFICIAL_PACKAGE"
  else
    printf '%s/@openai/codex\n' "$(npm root -g)"
  fi
}

upstream_version() {
  local package
  package="$(official_package)"
  node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).version" "$package/package.json"
}

custom_runtime_ready() {
  local current real_target package_dir expected_patch_sha installed_patch_sha
  current="$root/bin/codex-current"
  [[ -x "$current" ]] || return 1
  real_target="$(readlink -f "$current")" || return 1
  package_dir="$(dirname "$(dirname "$real_target")")"
  expected_patch_sha="$(sha256sum "$manager/project-browser.patch" 2>/dev/null | awk '{print $1}')"
  installed_patch_sha="$(cat "$package_dir/project-browser-patch.sha256" 2>/dev/null || true)"
  [[ -n "$expected_patch_sha" && "$installed_patch_sha" == "$expected_patch_sha" ]] || return 1
  [[ -x "$(dirname "$real_target")/codex-code-mode-host" ]] &&
    [[ -f "$package_dir/codex-package.json" ]] &&
    [[ -x "$package_dir/codex-path/rg" ]] &&
    [[ -x "$package_dir/codex-resources/bwrap" ]]
}

if [[ "${1:-}" == "update" ]]; then
  mkdir -p "$root"
  exec 8>"$root/update.lock"
  flock 8

  "$upstream" "$@"
  update_status=$?
  restore_launcher
  if (( update_status != 0 )); then
    exit "$update_status"
  fi

  version="$(upstream_version)"
  CODEX_PROJECT_SESSION_BROWSER_FORCE_REBUILD=1 "$manager/rebuild.sh" "$version"
  rebuild_status=$?
  if (( rebuild_status != 0 )); then
    printf 'warning: project session browser could not be rebuilt for Codex %s; using the official binary\n' "$version" >&2
  fi
  restore_launcher
  exit "$rebuild_status"
fi

version="$(upstream_version 2>/dev/null || true)"
current_version="$(cat "$root/current-version" 2>/dev/null || true)"
if [[ -n "$version" ]] && { [[ "$version" != "$current_version" ]] || ! custom_runtime_ready; }; then
  if ! "$manager/rebuild.sh" "$version"; then
    printf 'warning: project session browser is unavailable for Codex %s; using the official binary\n' "$version" >&2
    exec "$upstream" "$@"
  fi
fi

if custom_runtime_ready; then
  exec "$root/bin/codex-current" "$@"
fi

exec "$upstream" "$@"
