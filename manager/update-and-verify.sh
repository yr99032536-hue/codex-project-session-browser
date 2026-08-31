#!/usr/bin/env bash
set -uo pipefail

manager="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf 'Codex project session browser update started at %s\n' "$(date --iso-8601=seconds)"
"$manager/dispatch.sh" update
update_status=$?

"$manager/doctor.sh"
doctor_status=$?

if (( update_status != 0 )); then
  exit "$update_status"
fi
exit "$doctor_status"
