#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
manager="$test_root/manager"
package="$test_root/packages/9.9.9"
official="$test_root/official"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$manager" "$package/bin" "$package/codex-path" "$package/codex-resources" "$test_root/bin" "$official"
install -m 0755 "$project_root/manager/doctor.sh" "$manager/doctor.sh"
touch "$test_root/bin/codex-upstream"
chmod +x "$test_root/bin/codex-upstream"
ln -s "$manager/dispatch.sh" "$test_root/bin/codex"
printf 'patch\n' > "$manager/project-browser.patch"
patch_sha="$(sha256sum "$manager/project-browser.patch" | awk '{print $1}')"
printf '{"version":"9.9.9"}\n' > "$official/package.json"
printf '{"version":"9.9.9"}\n' > "$package/codex-package.json"
printf '#!/usr/bin/env bash\nprintf "codex-cli 9.9.9\\n"\n' > "$package/bin/codex"
chmod +x "$package/bin/codex"
touch "$package/bin/codex-code-mode-host" "$package/codex-path/rg" "$package/codex-resources/bwrap"
chmod +x "$package/bin/codex-code-mode-host" "$package/codex-path/rg" "$package/codex-resources/bwrap"
printf '%s\n' "$patch_sha" > "$package/project-browser-patch.sha256"
printf '9.9.9\n' > "$test_root/current-version"
ln -s "$package/bin/codex" "$test_root/bin/codex-current"

CODEX_PROJECT_SESSION_BROWSER_ROOT="$test_root" \
CODEX_PROJECT_SESSION_BROWSER_OFFICIAL_PACKAGE="$official" \
CODEX_PROJECT_SESSION_BROWSER_LAUNCHER="$test_root/bin/codex" \
CODEX_PROJECT_SESSION_BROWSER_UPSTREAM="$test_root/bin/codex-upstream" \
  "$manager/doctor.sh"

printf 'invalid\n' > "$package/project-browser-patch.sha256"
if CODEX_PROJECT_SESSION_BROWSER_ROOT="$test_root" \
  CODEX_PROJECT_SESSION_BROWSER_OFFICIAL_PACKAGE="$official" \
  CODEX_PROJECT_SESSION_BROWSER_LAUNCHER="$test_root/bin/codex" \
  CODEX_PROJECT_SESSION_BROWSER_UPSTREAM="$test_root/bin/codex-upstream" \
  "$manager/doctor.sh"; then
  printf 'doctor unexpectedly accepted an invalid patch marker\n' >&2
  exit 1
fi

printf 'doctor tests passed\n'
