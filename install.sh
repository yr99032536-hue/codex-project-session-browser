#!/usr/bin/env bash
set -euo pipefail

root="$HOME/.local/share/codex-project-session-browser"
repo="$root/repo"
manager="$root/manager"
bin_dir="$HOME/.local/bin"
launcher="$bin_dir/codex"
upstream="$bin_dir/codex-upstream"
source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for command_name in bash git node npm flock sha256sum strip cargo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'required command is missing: %s\n' "$command_name" >&2
    exit 1
  fi
done

official_package="$(npm root -g)/@openai/codex"
if [[ ! -f "$official_package/package.json" ]]; then
  printf 'global @openai/codex installation not found under %s\n' "$official_package" >&2
  exit 1
fi

mkdir -p "$manager" "$bin_dir"
install -m 0755 "$source_root/manager/dispatch.sh" "$manager/dispatch.sh"
install -m 0755 "$source_root/manager/rebuild.sh" "$manager/rebuild.sh"
install -m 0644 "$source_root/patches/project-browser.patch" "$manager/project-browser.patch"
install -m 0644 "$source_root/README.md" "$manager/README.md"

if [[ ! -e "$upstream" ]]; then
  current_codex="$(command -v codex 2>/dev/null || true)"
  if [[ -z "$current_codex" ]]; then
    printf 'official codex launcher was not found in PATH\n' >&2
    exit 1
  fi
  current_target="$(readlink -f "$current_codex")"
  if [[ "$current_target" == "$manager/dispatch.sh" ]]; then
    printf 'codex already points to this manager, but codex-upstream is missing\n' >&2
    exit 1
  fi
  ln -s "$current_target" "$upstream"
fi

if [[ ! -x "$upstream" ]]; then
  printf 'official codex launcher is not executable: %s\n' "$upstream" >&2
  exit 1
fi

if [[ ! -d "$repo/.git" ]]; then
  git clone --filter=blob:none --no-checkout https://github.com/openai/codex.git "$repo"
fi

ln -sfn "$manager/dispatch.sh" "$launcher"
"$manager/rebuild.sh"

printf 'installed Codex Project Session Browser\n'
printf 'launcher: %s\n' "$launcher"
printf 'version: '
"$launcher" --version
