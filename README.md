# Codex Project Session Browser

An unofficial source patch for the OpenAI Codex CLI that keeps the native `codex resume` TUI while grouping sessions by project directory.

## Features

- Shows project directories first in `codex resume`.
- Opens project sessions in the same TUI with Enter or Right Arrow.
- Adds `＋ 새 대화 시작` as the first row inside each project.
- Starts the new session with the selected project's working directory and project configuration.
- Returns to the project list with Escape or Left Arrow.
- Reapplies the patch and rebuilds Codex after `codex update`.
- Restores the matching official runtime helpers and falls back to the official CLI if a future patch cannot be applied.

## Requirements

- Linux
- Codex installed globally through npm as `@openai/codex`
- `bash`, `git`, `node`, `npm`, `flock`, `sha256sum`, `strip`
- A Rust toolchain capable of building the selected Codex release

## Install

```bash
git clone https://github.com/yr99032536-hue/codex-project-session-browser.git
cd codex-project-session-browser
./install.sh
```

The first build compiles Codex from source and can take several minutes. Build artifacts are shared between versions under `~/.local/share/codex-project-session-browser/repo/codex-rs/target`.

## Usage

```bash
codex resume
```

Select a project, then select `＋ 새 대화 시작` to begin a fresh session in that directory.

## Updates

Use the normal command:

```bash
codex update
```

The launcher runs the official updater first, applies `patches/project-browser.patch` to the matching source tag, rebuilds the CLI, and restores the full runtime package. Scheduled jobs are compatible when they invoke the same `codex update` command.

The patch is currently verified against Codex CLI `0.150.1`. If an upstream refactor causes a conflict, the launcher prints a warning and uses the official CLI instead of starting a partially patched runtime.

## Uninstall

```bash
./uninstall.sh
```

This restores the official `codex` launcher. Generated sources and build caches remain under `~/.local/share/codex-project-session-browser` so they can be removed separately if no longer needed.

## Scope

This repository distributes source patches and build scripts only. It does not distribute OpenAI binaries, credentials, conversations, or local Codex configuration.

## License

Apache-2.0. The patch modifies the Apache-2.0-licensed OpenAI Codex project; see `NOTICE` for attribution.
