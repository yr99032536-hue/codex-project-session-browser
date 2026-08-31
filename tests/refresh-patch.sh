#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
fixture_root="$test_root/fixture"
installed_root="$test_root/installed"
manager="$installed_root/manager"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$fixture_root/patches/9.9.9" "$manager"
install -m 0755 "$project_root/manager/refresh-patch.sh" "$manager/refresh-patch.sh"
printf 'old patch\n' > "$manager/project-browser.patch"
printf 'new patch\n' > "$fixture_root/patches/9.9.9/project-browser.patch"
patch_sha="$(sha256sum "$fixture_root/patches/9.9.9/project-browser.patch" | awk '{print $1}')"
printf '9.9.9\t%s\tpatches/9.9.9/project-browser.patch\n' "$patch_sha" > "$fixture_root/patches/manifest.tsv"

CODEX_PROJECT_SESSION_BROWSER_ROOT="$installed_root" \
CODEX_PROJECT_SESSION_BROWSER_PATCH_BASE_URL="file://$fixture_root" \
CODEX_PROJECT_SESSION_BROWSER_ALLOW_FILE_URL=1 \
  "$manager/refresh-patch.sh" 9.9.9

cmp "$fixture_root/patches/9.9.9/project-browser.patch" "$manager/project-browser.patch"

printf '9.9.9\t%s\tpatches/9.9.9/project-browser.patch\n' "$(printf '0%.0s' {1..64})" > "$fixture_root/patches/manifest.tsv"
if CODEX_PROJECT_SESSION_BROWSER_ROOT="$installed_root" \
  CODEX_PROJECT_SESSION_BROWSER_PATCH_BASE_URL="file://$fixture_root" \
  CODEX_PROJECT_SESSION_BROWSER_ALLOW_FILE_URL=1 \
  "$manager/refresh-patch.sh" 9.9.9; then
  printf 'checksum mismatch unexpectedly succeeded\n' >&2
  exit 1
fi

printf 'refresh patch tests passed\n'
