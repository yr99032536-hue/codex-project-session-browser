#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
installed="$test_root/installed"
manager="$installed/manager"
official="$test_root/official"
fixture="$test_root/fixture"
source_repo="$test_root/source"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$manager" "$official/vendor/test/bin" "$official/vendor/test/codex-path" \
  "$official/vendor/test/codex-resources" "$fixture/patches" "$source_repo"
install -m 0755 "$project_root/manager/rebuild.sh" "$manager/rebuild.sh"
install -m 0755 "$project_root/manager/refresh-patch.sh" "$manager/refresh-patch.sh"
printf 'not a patch\n' > "$manager/project-browser.patch"
printf '# no published test patch\n' > "$fixture/patches/manifest.tsv"
printf '{"version":"9.9.9"}\n' > "$official/package.json"
printf '{"version":"9.9.9"}\n' > "$official/vendor/test/codex-package.json"
touch "$official/vendor/test/bin/codex-code-mode-host" \
  "$official/vendor/test/codex-path/rg" \
  "$official/vendor/test/codex-resources/bwrap"
chmod +x "$official/vendor/test/bin/codex-code-mode-host" \
  "$official/vendor/test/codex-path/rg" \
  "$official/vendor/test/codex-resources/bwrap"

git -C "$source_repo" init --quiet
git -C "$source_repo" config user.email test@example.com
git -C "$source_repo" config user.name test
printf 'source\n' > "$source_repo/source.txt"
git -C "$source_repo" add source.txt
git -C "$source_repo" commit --quiet -m source
git -C "$source_repo" tag rust-v9.9.9
git clone --quiet --no-checkout "$source_repo" "$installed/repo"

run_rebuild() {
  CODEX_PROJECT_SESSION_BROWSER_OFFICIAL_PACKAGE="$official" \
  CODEX_PROJECT_SESSION_BROWSER_PATCH_BASE_URL="file://$fixture" \
  CODEX_PROJECT_SESSION_BROWSER_ALLOW_FILE_URL=1 \
    "$manager/rebuild.sh" 9.9.9
}

if run_rebuild; then
  printf 'invalid patch unexpectedly rebuilt\n' >&2
  exit 1
fi

failure_count="$(find "$installed/failures" -maxdepth 1 -type f -name '9.9.9-*.failed' | wc -l)"
if [[ "$failure_count" != "1" ]]; then
  printf 'expected one cached rebuild failure, found %s\n' "$failure_count" >&2
  exit 1
fi

set +e
second_output="$(run_rebuild 2>&1)"
second_status=$?
set -e
if [[ "$second_status" == "0" || "$second_output" != *"recent rebuild failure is cached"* ]]; then
  printf 'cached rebuild failure was not used\n' >&2
  exit 1
fi

printf 'rebuild failure tests passed\n'
