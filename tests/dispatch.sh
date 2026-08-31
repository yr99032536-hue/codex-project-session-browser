#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
test_home="$test_root/home"
manager="$test_home/manager-root/manager"
official="$test_root/official"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$manager" "$test_home/.local/bin" "$official"
install -m 0755 "$project_root/manager/dispatch.sh" "$manager/dispatch.sh"
printf 'patch\n' > "$manager/project-browser.patch"
printf '{"version":"9.9.9"}\n' > "$official/package.json"
printf '#!/usr/bin/env bash\nrm -f "$HOME/.local/bin/codex"\nexit 0\n' > "$test_home/.local/bin/codex-upstream"
printf '#!/usr/bin/env bash\nexit 42\n' > "$manager/rebuild.sh"
chmod +x "$test_home/.local/bin/codex-upstream" "$manager/rebuild.sh"
ln -s "$manager/dispatch.sh" "$test_home/.local/bin/codex"

if HOME="$test_home" \
  CODEX_PROJECT_SESSION_BROWSER_OFFICIAL_PACKAGE="$official" \
  "$test_home/.local/bin/codex" update; then
  printf 'dispatch unexpectedly hid a rebuild failure\n' >&2
  exit 1
else
  status=$?
fi

if [[ "$status" != "42" ]]; then
  printf 'dispatch returned %s instead of rebuild status 42\n' "$status" >&2
  exit 1
fi

expected_launcher="$manager/dispatch.sh"
actual_launcher="$(readlink -f "$test_home/.local/bin/codex")"
if [[ "$actual_launcher" != "$expected_launcher" ]]; then
  printf 'dispatch did not restore the managed launcher\n' >&2
  exit 1
fi

printf 'dispatch tests passed\n'
