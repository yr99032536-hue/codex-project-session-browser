#!/usr/bin/env bash
set -euo pipefail

root="$HOME/.local/share/codex-project-session-browser"
repo="$root/repo"
patch="$root/manager/project-browser.patch"
bin_dir="$root/bin"
version="${1:-}"
official_package="$(npm root -g)/@openai/codex"

if [[ -z "$version" ]]; then
  version="$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).version" "$official_package/package.json")"
fi
version="${version#codex-cli }"

mkdir -p "$bin_dir" "$root/packages" "$root/versions"
exec 9>"$root/rebuild.lock"
flock 9

package_dir="$root/packages/$version"
target="$package_dir/bin/codex"
host_target="$package_dir/bin/codex-code-mode-host"

official_manifest=""
while IFS= read -r candidate; do
  candidate_version="$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).version" "$candidate" 2>/dev/null || true)"
  if [[ "$candidate_version" == "$version" ]]; then
    official_manifest="$candidate"
    break
  fi
done < <(find "$official_package" -path '*/vendor/*/codex-package.json' -type f -print 2>/dev/null)

if [[ -z "$official_manifest" ]]; then
  printf 'matching official Codex runtime package not found for version %s\n' "$version" >&2
  exit 1
fi

official_runtime="$(dirname "$official_manifest")"
for required in \
  "$official_runtime/bin/codex-code-mode-host" \
  "$official_runtime/codex-path/rg" \
  "$official_runtime/codex-resources/bwrap"; do
  if [[ ! -x "$required" ]]; then
    printf 'official Codex runtime component is missing or not executable: %s\n' "$required" >&2
    exit 1
  fi
done

mkdir -p "$package_dir/bin"
install -m 0644 "$official_manifest" "$package_dir/codex-package.json"
find "$package_dir/codex-path" "$package_dir/codex-resources" -depth -delete 2>/dev/null || true
cp -a "$official_runtime/codex-path" "$package_dir/codex-path"
cp -a "$official_runtime/codex-resources" "$package_dir/codex-resources"
install -m 0755 "$official_runtime/bin/codex-code-mode-host" "$host_target"

bundled_zsh="$package_dir/codex-resources/zsh/bin/zsh"
if [[ -x "$bundled_zsh" ]] && ! "$bundled_zsh" -fc 'exit 0' >/dev/null 2>&1; then
  find "$package_dir/codex-resources/zsh" -depth -delete
  printf 'warning: bundled zsh is incompatible with this system; using the standard shell runtime\n' >&2
fi

runtime_ready() {
  [[ -x "$target" ]] &&
    [[ -x "$host_target" ]] &&
    [[ -f "$package_dir/codex-package.json" ]] &&
    [[ -x "$package_dir/codex-path/rg" ]] &&
    [[ -x "$package_dir/codex-resources/bwrap" ]]
}

tag="rust-v$version"
worktree="$root/versions/$version"
patch_sha="$(sha256sum "$patch" | awk '{print $1}')"
patch_marker="$worktree/.project-browser-patch-sha256"
patch_is_current=false
if [[ "$(cat "$patch_marker" 2>/dev/null || true)" == "$patch_sha" ]]; then
  patch_is_current=true
fi

if runtime_ready && [[ "$patch_is_current" == true ]]; then
  ln -sfn "$target" "$bin_dir/codex-current"
  printf '%s\n' "$version" > "$root/current-version"
  exit 0
fi

git -C "$repo" fetch --depth=1 origin "refs/tags/$tag:refs/tags/$tag"
git -C "$repo" rev-parse --verify --quiet "refs/tags/$tag" >/dev/null

if [[ -d "$worktree" ]] && [[ "$(cat "$patch_marker" 2>/dev/null || true)" != "$patch_sha" ]]; then
  git -C "$repo" worktree remove --force "$worktree"
fi

if [[ ! -d "$worktree/.git" && ! -f "$worktree/.git" ]]; then
  git -C "$repo" worktree add --detach "$worktree" "$tag"
fi

if [[ "$(cat "$patch_marker" 2>/dev/null || true)" != "$patch_sha" ]]; then
  git -C "$worktree" apply --check "$patch"
  git -C "$worktree" apply "$patch"
  printf '%s\n' "$patch_sha" > "$patch_marker"
fi

(
  cd "$worktree/codex-rs"
  CARGO_TARGET_DIR="$repo/codex-rs/target" \
    PATH="$HOME/.cargo/bin:$PATH" \
    cargo build --release -p codex-cli --bin codex
)

install -m 0755 "$repo/codex-rs/target/release/codex" "$target"
strip "$target"

if ! runtime_ready; then
  printf 'rebuilt Codex runtime is incomplete for version %s\n' "$version" >&2
  exit 1
fi

ln -sfn "$target" "$bin_dir/codex-current"
printf '%s\n' "$version" > "$root/current-version"
