#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
manager="$test_root/manager"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$manager"
install -m 0755 "$project_root/manager/update-and-verify.sh" "$manager/update-and-verify.sh"
printf '#!/usr/bin/env bash\n[[ "$1" == update ]]\n' > "$manager/dispatch.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$manager/doctor.sh"
chmod +x "$manager/dispatch.sh" "$manager/doctor.sh"

HOME="$test_root/home" "$manager/update-and-verify.sh"

printf 'update-and-verify tests passed\n'
