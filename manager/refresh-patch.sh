#!/usr/bin/env bash
set -euo pipefail

manager="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${CODEX_PROJECT_SESSION_BROWSER_ROOT:-$(dirname "$manager")}"
version="${1:-}"
base_url="${CODEX_PROJECT_SESSION_BROWSER_PATCH_BASE_URL:-https://raw.githubusercontent.com/yr99032536-hue/codex-project-session-browser/main}"
patch="$manager/project-browser.patch"
cache_dir="$root/compatibility"

if [[ -z "$version" ]]; then
  printf 'Codex version is required to refresh the compatibility patch\n' >&2
  exit 2
fi

if [[ "$base_url" != https://* ]]; then
  if [[ "$base_url" != file://* || "${CODEX_PROJECT_SESSION_BROWSER_ALLOW_FILE_URL:-0}" != "1" ]]; then
    printf 'unsupported compatibility patch URL: %s\n' "$base_url" >&2
    exit 2
  fi
fi

mkdir -p "$cache_dir"
manifest_tmp="$(mktemp "$cache_dir/manifest.XXXXXX")"
patch_tmp="$(mktemp "$cache_dir/patch.XXXXXX")"
cleanup() {
  rm -f "$manifest_tmp" "$patch_tmp"
}
trap cleanup EXIT

curl_args=(--fail --silent --show-error --location --connect-timeout 10 --max-time 30)
if [[ "$base_url" == https://* ]]; then
  curl_args+=(--proto '=https' --tlsv1.2)
fi

if ! curl "${curl_args[@]}" "$base_url/patches/manifest.tsv" --output "$manifest_tmp"; then
  printf 'warning: compatibility manifest could not be downloaded; keeping the local patch\n' >&2
  exit 0
fi

entry="$(awk -F '\t' -v version="$version" '$1 == version { print $2 "\t" $3; exit }' "$manifest_tmp")"
if [[ -z "$entry" ]]; then
  printf 'no published compatibility patch for Codex %s; trying the local patch\n' "$version" >&2
  exit 0
fi

IFS=$'\t' read -r expected_sha relative_path <<<"$entry"
if [[ ! "$expected_sha" =~ ^[0-9a-f]{64}$ ]]; then
  printf 'invalid compatibility patch checksum for Codex %s\n' "$version" >&2
  exit 2
fi
if [[ ! "$relative_path" =~ ^patches/[0-9A-Za-z._-]+/project-browser\.patch$ ]]; then
  printf 'invalid compatibility patch path for Codex %s: %s\n' "$version" "$relative_path" >&2
  exit 2
fi

curl "${curl_args[@]}" "$base_url/$relative_path" --output "$patch_tmp"
actual_sha="$(sha256sum "$patch_tmp" | awk '{print $1}')"
if [[ "$actual_sha" != "$expected_sha" ]]; then
  printf 'compatibility patch checksum mismatch for Codex %s\n' "$version" >&2
  exit 2
fi

local_sha="$(sha256sum "$patch" 2>/dev/null | awk '{print $1}')"
if [[ "$local_sha" == "$expected_sha" ]]; then
  install -m 0644 "$manifest_tmp" "$cache_dir/manifest.tsv"
  exit 0
fi

install -m 0644 "$patch_tmp" "$patch"
install -m 0644 "$manifest_tmp" "$cache_dir/manifest.tsv"
printf 'installed compatibility patch for Codex %s (%s)\n' "$version" "$expected_sha"
