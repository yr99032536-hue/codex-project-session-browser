# 문제 해결

## 현재 실행 버전 확인

```bash
codex --version
cat ~/.local/share/codex-project-session-browser/current-version
```

두 버전이 같아야 합니다.

## 어떤 실행 파일이 호출되는지 확인

```bash
readlink -f ~/.local/bin/codex
readlink -f ~/.local/share/codex-project-session-browser/bin/codex-current
readlink -f ~/.local/bin/codex-upstream
```

정상 설치에서는 다음 역할로 연결됩니다.

- `codex`: `manager/dispatch.sh`
- `codex-current`: 현재 버전의 패치된 바이너리
- `codex-upstream`: npm으로 설치된 공식 Codex 실행 파일

`codex`가 존재하지 않거나 `~/.local/manager/dispatch.sh`처럼 존재하지 않는 경로를 가리키면, 이전 관리자 버전의 심볼릭 링크 경로 계산 문제가 발생한 것입니다. 최신 관리자 설치 후 `doctor.sh`를 실행하면 공개 런처와 공식 업스트림 런처까지 함께 검사합니다.

## 프로젝트가 보이지 않는 경우

로컬 Desktop 프로젝트는 `~/.codex/.codex-global-state.json`에서 읽습니다. `CODEX_HOME`을 별도로 설정했다면 그 디렉터리 아래의 같은 파일을 사용합니다.

확인할 내용:

1. Desktop 프로젝트가 로컬 프로젝트인지 확인합니다. 클라우드 ChatGPT 프로젝트는 현재 지원하지 않습니다.
2. `~/.codex/.codex-global-state.json` 또는 `.bak` 파일이 존재하고 읽을 수 있는지 확인합니다.
3. 세션이 로컬 세션인지 확인합니다.
4. `codex resume` 검색어를 모두 지우고 프로젝트 목록을 확인합니다.

Desktop에서 세션이나 폴더 없이 만든 빈 로컬 프로젝트도 0 sessions로 보여야 합니다. 상태 파일을 사용할 수 없으면 세션의 `cwd` 그룹만 표시됩니다.

## 한 프로젝트의 세션이 나뉘어 보이는 경우

- Desktop에서 명시적으로 프로젝트에 연결한 세션은 `cwd`가 서로 달라도 프로젝트 ID로 함께 표시됩니다.
- CLI에서 새로 만든 세션은 `cwd`가 한 프로젝트의 루트와 정확히 일치할 때 그 프로젝트로 추론됩니다.
- 같은 폴더를 여러 Desktop 프로젝트가 공유하면 잘못 묶지 않기 위해 추론하지 않고 `cwd` 폴백 그룹으로 표시합니다.
- 프로젝트의 하위 폴더에서 별도로 시작한 세션은 루트와 정확히 같지 않으므로 `cwd` 폴백으로 남을 수 있습니다.

## `＋ 새 대화 시작`이 보이지 않는 경우

새 대화 항목은 다음 조건에서만 표시됩니다.

- CLI 시작 시 실행한 로컬 `codex resume`
- 프로젝트 안에 들어간 상태
- 활성 세션 보기
- 검색어가 비어 있음

보관 세션, 원격 워크스페이스, 검색 중인 목록, fork 선택기에서는 표시하지 않습니다.

Desktop 프로젝트에 폴더가 하나도 없어도 프로젝트 자체는 표시됩니다. 다만 CLI 새 세션에는 작업 디렉터리가 필요하므로, 이런 프로젝트 안에서는 기존 세션을 열 수 있지만 `＋ 새 대화 시작`은 표시되지 않습니다.

## 업데이트 후 공식 목록으로 돌아간 경우

새 Codex 버전에서 패치 적용이 실패했을 가능성이 있습니다.

```bash
codex --version
~/.local/bin/codex-upstream --version
```

버전이 올라간 직후 경고가 표시됐다면 GitHub 저장소에서 새 버전 지원 여부를 확인해야 합니다. 자동 업데이트가 실행됐더라도 업스트림 Rust 소스의 위치나 구조가 바뀌면 기존 패치를 기계적으로 이식할 수 없습니다. 실패 시 설정이나 세션을 삭제하지 않고 공식 CLI로 대체하므로 프로젝트 묶음 화면만 사라져 보이는 것은 의도된 안전 동작입니다.

새 버전용 패치가 저장소에 게시된 뒤에는 다음 명령으로 즉시 다시 확인할 수 있습니다.

```bash
codex update
```

설치 상태와 패치 해시는 다음 명령으로 한 번에 검사합니다.

```bash
~/.local/share/codex-project-session-browser/manager/doctor.sh
```

## 09시 자동 업데이트 확인

```bash
systemctl --user status codex-project-session-browser-update.timer
systemctl --user list-timers codex-project-session-browser-update.timer
journalctl --user -u codex-project-session-browser-update.service -n 100 --no-pager
```

타이머는 Codex Desktop 앱과 별도로 동작하며, 놓친 실행은 다음 사용자 로그인 때 보충합니다.

## 런타임 구성 요소 확인

```bash
version="$(cat ~/.local/share/codex-project-session-browser/current-version)"
root="$HOME/.local/share/codex-project-session-browser/packages/$version"

test -x "$root/bin/codex" && echo 'codex: OK'
test -x "$root/bin/codex-code-mode-host" && echo 'host: OK'
test -x "$root/codex-path/rg" && echo 'rg: OK'
test -x "$root/codex-resources/bwrap" && echo 'bwrap: OK'
test -f "$root/codex-package.json" && echo 'manifest: OK'
test -f "$root/project-browser-patch.sha256" && echo 'patch marker: OK'
```

필수 파일이 빠지면 다음 `codex` 실행에서 관리자가 복구를 시도합니다.

패치 파일이 갱신됐는데 Codex 버전이 그대로여도 패치 마커가 다르면 자동으로 다시 빌드합니다.

## `OSError: [Errno 25] Inappropriate ioctl for device`

이 프로젝트는 별도 Python 세션 선택기를 사용하지 않고 Codex의 네이티브 TUI 안에서 동작하므로 정상 설치에서는 이 오류를 만들지 않습니다.

이 오류와 함께 별도 세션 선택기 경로가 표시된다면 오래된 래퍼가 아직 실행되고 있을 수 있습니다.

```bash
readlink -f ~/.local/bin/codex
```

결과가 `codex-project-session-browser/manager/dispatch.sh`인지 확인합니다.

## 번들 `zsh` 호환 경고

다음 경고는 치명적인 오류가 아닙니다.

```text
warning: bundled zsh is incompatible with this system; using the standard shell runtime
```

공식 패키지의 선택적 번들 `zsh`가 현재 시스템에서 실행되지 않아 이를 제외하고 시스템 기본 셸을 사용한다는 뜻입니다. `codex`, `codex-code-mode-host`, `rg`, `bwrap`이 정상이라면 계속 사용할 수 있습니다.

## 빌드가 오래 걸리거나 디스크가 부족한 경우

Codex Rust 워크스페이스의 최적화 릴리스 링크 단계는 오래 걸릴 수 있고 CPU와 메모리를 많이 사용합니다.

```bash
df -h "$HOME"
du -sh ~/.local/share/codex-project-session-browser/repo/codex-rs/target
```

빌드 캐시는 다음 업데이트를 빠르게 만들기 위해 유지됩니다. 캐시 삭제 후에는 전체 재빌드가 필요합니다.

## 관리자 스크립트 구문 확인

```bash
bash -n \
  ~/.local/share/codex-project-session-browser/manager/dispatch.sh \
  ~/.local/share/codex-project-session-browser/manager/rebuild.sh
```

## 공식 Codex로 되돌리기

복제한 저장소에서 다음을 실행합니다.

```bash
./uninstall.sh
```

또는 공식 실행 파일을 직접 확인할 수 있습니다.

```bash
~/.local/bin/codex-upstream --version
```

제거 스크립트는 대화 세션이나 `~/.codex` 설정을 삭제하지 않습니다.

## 이슈를 보고할 때 포함할 정보

토큰, API 키, 대화 내용은 제외하고 다음 정보만 첨부하는 것이 좋습니다.

```bash
codex --version
~/.local/bin/codex-upstream --version
uname -a
readlink -f ~/.local/bin/codex
cat ~/.local/share/codex-project-session-browser/current-version
```

패치 실패라면 오류에 표시된 Codex 버전과 `git apply --check` 메시지도 함께 제공하세요.
