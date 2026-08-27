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

## 프로젝트가 보이지 않는 경우

프로젝트는 Desktop 앱의 프로젝트 정의가 아니라 세션의 작업 디렉터리로 계산됩니다.

확인할 내용:

1. 해당 폴더에서 Codex 세션을 실제로 만든 적이 있는지 확인합니다.
2. 세션이 로컬 세션인지 확인합니다.
3. 과거에 폴더를 이동하거나 이름을 변경하지 않았는지 확인합니다.
4. `codex resume` 검색어를 모두 지우고 프로젝트 목록을 확인합니다.

Desktop에서 빈 프로젝트만 만든 상태라면 CLI가 그룹화할 세션이 아직 없을 수 있습니다.

## `＋ 새 대화 시작`이 보이지 않는 경우

새 대화 항목은 다음 조건에서만 표시됩니다.

- CLI 시작 시 실행한 로컬 `codex resume`
- 프로젝트 안에 들어간 상태
- 활성 세션 보기
- 검색어가 비어 있음

보관 세션, 원격 워크스페이스, 검색 중인 목록, fork 선택기에서는 표시하지 않습니다.

## 업데이트 후 공식 목록으로 돌아간 경우

새 Codex 버전에서 패치 적용이 실패했을 가능성이 있습니다.

```bash
codex --version
~/.local/bin/codex-upstream --version
```

버전이 올라간 직후 경고가 표시됐다면 GitHub 저장소에서 새 버전 지원 여부를 확인해야 합니다. 실패 시 공식 CLI로 대체하는 것은 의도된 안전 동작입니다.

## 런타임 구성 요소 확인

```bash
version="$(cat ~/.local/share/codex-project-session-browser/current-version)"
root="$HOME/.local/share/codex-project-session-browser/packages/$version"

test -x "$root/bin/codex" && echo 'codex: OK'
test -x "$root/bin/codex-code-mode-host" && echo 'host: OK'
test -x "$root/codex-path/rg" && echo 'rg: OK'
test -x "$root/codex-resources/bwrap" && echo 'bwrap: OK'
test -f "$root/codex-package.json" && echo 'manifest: OK'
```

필수 파일이 빠지면 다음 `codex` 실행에서 관리자가 복구를 시도합니다.

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
