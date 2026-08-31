# Codex Project Session Browser

[![validate](https://github.com/yr99032536-hue/codex-project-session-browser/actions/workflows/validate.yml/badge.svg)](https://github.com/yr99032536-hue/codex-project-session-browser/actions/workflows/validate.yml)

OpenAI Codex CLI의 기존 `codex resume` 화면을 그대로 사용하면서, 대화 세션을 Codex Desktop 프로젝트별로 묶어 보여주는 비공식 소스 패치 및 업데이트 관리자입니다. Desktop 메타데이터가 없거나 연결되지 않은 세션은 기존 작업 디렉터리 기준으로 안전하게 폴백합니다.

## 한 줄 요약

기존 Codex CLI를 다른 프로그램으로 대체하지 않고, 네이티브 TUI 안에 다음 탐색 단계를 추가합니다.

```text
codex resume
  └─ Desktop 프로젝트 + 경로 폴백 목록
       └─ 선택한 프로젝트의 대화 세션 목록
            ├─ ＋ 새 대화 시작
            └─ 기존 대화 세션들
```

## 왜 만들었나

Codex Desktop 앱은 대화 세션을 프로젝트 단위로 정리해서 보여주지만, 기본 Codex CLI의 `resume` 목록은 세션을 한 화면에 나열합니다. 세션이 많아지면 같은 프로젝트에서 진행한 대화를 찾기 어렵기 때문에, CLI의 원래 화면과 키 조작은 유지하면서 프로젝트 폴더를 한 단계 먼저 보여주도록 만들었습니다.

## 이 도구가 하는 일

- Desktop의 로컬 프로젝트 ID와 대화-프로젝트 연결 정보를 읽어 `codex resume` 첫 화면을 프로젝트별로 묶습니다.
- 여러 폴더가 연결된 프로젝트의 세션도 하나의 프로젝트로 표시합니다.
- 폴더가 없거나 세션이 0개인 Desktop 프로젝트도 목록에 표시합니다.
- Desktop 연결 정보가 없는 세션은 작업 디렉터리(`cwd`) 기준 프로젝트로 폴백합니다.
- 프로젝트를 선택하면 별도 창을 열지 않고 같은 TUI 안에서 세션 목록으로 이동합니다.
- 프로젝트 안의 첫 줄에 `＋ 새 대화 시작`을 추가합니다.
- 새 대화를 선택하면 해당 프로젝트 폴더를 작업 디렉터리로 사용합니다.
- 새 세션을 시작하기 전에 해당 폴더 기준의 Codex 프로젝트 설정을 다시 읽습니다.
- 공식 `codex update`가 끝난 뒤 버전별 호환 패치를 확인하고 CLI를 다시 빌드합니다.
- GitHub에 새 버전용 호환 패치가 게시되면 다음 업데이트나 복구 시 자동으로 내려받아 SHA-256을 검증합니다.
- 공식 호스트, `rg`, `bwrap` 등의 런타임 구성 요소가 누락됐는지 검사하고 복구합니다.
- 패치를 적용할 수 없는 새 버전에서는 불완전한 커스텀 바이너리 대신 공식 Codex CLI로 안전하게 대체합니다.

## 이 도구가 아닌 것

| 구분 | 설명 |
| --- | --- |
| 별도 플러그인 | 아닙니다. 현재 Codex CLI에는 이 화면을 교체하는 일반 플러그인 지점이 없어 Rust 소스를 패치합니다. |
| 별도 세션 선택 프로그램 | 아닙니다. Python, FZF, 새 터미널 창을 사용하지 않습니다. |
| 새로운 CLI 명령어 | 아닙니다. 계속 `codex resume`를 사용합니다. |
| Codex 전체 포크 배포판 | 아닙니다. 패치와 빌드 관리자만 배포하며 공식 소스 태그에서 로컬 빌드합니다. |
| 세션 동기화 도구 | 아닙니다. 대화를 업로드하거나 Desktop 앱과 별도 동기화를 수행하지 않습니다. |
| 프로젝트 편집기 | 아닙니다. Desktop 상태를 읽기만 하며 프로젝트 이름, 폴더, 연결 정보를 수정하지 않습니다. |
| 클라우드 ChatGPT 프로젝트 브라우저 | 아닙니다. 현재는 이 컴퓨터의 Codex Desktop 로컬 프로젝트를 대상으로 합니다. |

## 화면 사용법

### 1. 프로젝트 목록 열기

```bash
codex resume
```

첫 화면에는 Desktop 프로젝트 이름, 세션 수, 주 폴더가 표시됩니다. Desktop에 연결되지 않은 세션은 `cwd` 폴더명으로 표시됩니다.

```text
❯ ▸ Isaac  ·  8 sessions
    ~/Isaac

  ▸ Obsidian-Vault  ·  2 sessions
    ~/Obsidian-Vault
```

### 2. 프로젝트 안으로 이동하기

- `Enter` 또는 `Right Arrow`: 선택한 프로젝트 열기
- `Escape` 또는 `Left Arrow`: 프로젝트 목록으로 돌아가기
- `Up` / `Down`: 항목 이동

전환은 같은 Codex TUI 안에서 이루어집니다. 별도 프로세스의 선택 창이나 보조 UI가 나타나지 않습니다.

### 3. 새 대화 시작하기

프로젝트 안의 첫 항목을 선택합니다.

```text
❯ ＋ 새 대화 시작
  ~/Isaac

  기존 대화 1
  기존 대화 2
```

`Enter`를 누르면 `~/Isaac`을 작업 디렉터리로 사용하는 새 Codex 세션이 시작됩니다. Desktop 프로젝트에 여러 폴더가 있으면 첫 번째 폴더인 주 폴더를 사용합니다. 해당 폴더의 `.codex` 설정과 프로젝트 범위 설정도 새 작업 디렉터리를 기준으로 다시 로드됩니다.

폴더가 없는 Desktop 프로젝트는 목록과 기존 세션을 볼 수 있지만, CLI가 시작할 `cwd`가 없으므로 `＋ 새 대화 시작`은 표시하지 않습니다. Desktop에서 폴더를 하나 연결하면 다음 `codex resume`부터 사용할 수 있습니다.

### 4. 기존 대화 이어가기

`＋ 새 대화 시작` 아래의 기존 세션을 선택하면 원래 `codex resume`와 동일하게 해당 대화를 이어갑니다.

## 프로젝트를 묶는 기준

우선순위는 다음과 같습니다.

1. `CODEX_HOME/.codex-global-state.json`의 `thread-project-assignments`에 로컬 프로젝트 ID가 있으면 그 ID로 묶습니다.
2. 연결 정보가 없는 세션의 `cwd`가 한 Desktop 프로젝트의 루트 폴더와 정확히 일치하면 그 프로젝트로 묶습니다. 같은 루트를 여러 프로젝트가 공유하면 추론하지 않습니다.
3. 둘 다 아니면 기존처럼 같은 `cwd`를 가진 세션끼리 폴백 프로젝트로 묶습니다.
4. `cwd`도 없는 세션은 개별 세션으로 남을 수 있습니다.

이 구조 덕분에 Desktop에서 프로젝트 폴더를 이동해도 명시적으로 연결된 세션은 프로젝트 ID를 기준으로 계속 함께 보입니다. 반대로 Desktop 상태 파일의 형식이 바뀌거나 파일을 읽을 수 없어도 `codex resume` 자체가 깨지지 않고 `cwd` 그룹으로 폴백합니다.

Desktop 프로젝트 목록은 `project-order` 순서를 따르고, 이름과 모든 `rootPaths`를 읽습니다. CLI는 이 파일을 수정하지 않습니다.

## 적용 범위

- 로컬 `codex resume`: 프로젝트 브라우저와 새 대화 항목 사용
- Desktop 로컬 프로젝트: 프로젝트 ID 우선 그룹화
- Desktop 다중 폴더 프로젝트: 한 프로젝트로 통합, 첫 폴더를 새 대화의 `cwd`로 사용
- Desktop 폴더 없는 프로젝트: 프로젝트와 기존 세션 표시, 새 대화 항목 숨김
- Desktop 미연결 세션: 고유 루트 추론 후 `cwd` 그룹 폴백
- 활성 세션 + 검색어 없음: `＋ 새 대화 시작` 표시
- 검색 중: 실제 세션 검색에 집중하도록 새 대화 항목 숨김
- 보관된 세션: 새 대화 항목 숨김
- `codex fork`: 원래의 평면 세션 목록 유지
- 원격 워크스페이스: 현재 프로젝트 브라우저를 적용하지 않음
- 이미 열린 세션에서 호출되는 내부 resume 선택기: 새 대화 항목을 추가하지 않음

## 설치 요구 사항

- Linux
- npm 전역 패키지로 설치된 `@openai/codex`
- `bash`, `curl`, `git`, `node`, `npm`
- `flock`, `sha256sum`, `strip`
- 선택한 Codex 릴리스를 빌드할 수 있는 Rust 툴체인과 `cargo`
- 소스 및 빌드 캐시를 위한 충분한 디스크 공간

첫 릴리스 빌드는 시스템에 따라 수 분 이상 걸릴 수 있습니다. Codex 전체 Rust 워크스페이스를 빌드하므로 소스와 캐시가 수십 GB까지 증가할 수 있습니다.

## 설치

```bash
git clone https://github.com/yr99032536-hue/codex-project-session-browser.git
cd codex-project-session-browser
./install.sh
```

설치기는 다음 작업을 수행합니다.

1. 현재 공식 Codex 실행 파일을 `~/.local/bin/codex-upstream`으로 보존합니다.
2. OpenAI Codex 소스 저장소를 부분 복제합니다.
3. 설치된 Codex 버전에 대응하는 `rust-v<version>` 태그를 가져옵니다.
4. `patches/project-browser.patch`를 적용합니다.
5. `codex-cli` 릴리스 바이너리를 로컬에서 빌드합니다.
6. 공식 npm 패키지의 런타임 구성 요소와 로컬 빌드 바이너리를 하나의 버전 패키지로 조립합니다.
7. `~/.local/bin/codex`가 업데이트 관리자를 거쳐 실행되도록 연결합니다.

앱 실행 여부와 무관하게 매일 09시에 업데이트를 검사하려면 선택적으로 사용자 systemd 타이머를 설치합니다.

```bash
./install-systemd-timer.sh
```

`Persistent=true`이므로 컴퓨터가 꺼져 있거나 사용자 세션이 없었던 경우 다음 로그인 때 누락된 실행을 보충합니다.

## 설치 후 파일 구조

```text
~/.local/bin/
├─ codex             -> 업데이트 관리자
└─ codex-upstream    -> 공식 Codex 실행 파일

~/.local/share/codex-project-session-browser/
├─ manager/          # 실행 분기, 업데이트, 재빌드 스크립트
├─ compatibility/    # 마지막으로 받은 버전별 패치 목록
├─ failures/         # 반복 빌드를 막는 최근 실패 기록
├─ repo/             # OpenAI Codex 소스와 공유 Cargo 캐시
├─ versions/         # 버전별 패치 적용 소스 worktree
├─ packages/         # 버전별 실행 가능한 전체 런타임
├─ bin/codex-current # 현재 커스텀 바이너리 링크
└─ current-version   # 현재 적용된 Codex 버전
```

## 업데이트

기존과 같은 명령을 사용합니다.

```bash
codex update
```

처리 순서는 다음과 같습니다.

1. `codex-upstream update`로 공식 업데이트 실행
2. 새 npm 패키지 버전 확인
3. GitHub 호환 목록에서 해당 버전의 패치 확인 및 SHA-256 검증
4. 같은 버전의 공식 Rust 태그 가져오기
5. 패치 적용 가능 여부 검사
6. 패치된 CLI 릴리스 빌드
7. 공식 런타임 구성 요소 복구
8. `codex` 런처를 커스텀 관리자로 다시 연결

예약 작업에서도 반드시 `codex update`를 호출하면 같은 흐름이 적용됩니다. npm 명령으로 Codex만 직접 교체하면 커스텀 재빌드 단계가 실행되지 않을 수 있습니다.

관리자는 패치 SHA-256을 소스 worktree와 설치된 바이너리 패키지 양쪽에 기록합니다. Codex 버전이 같아도 게시된 패치가 바뀌면 다음 예약 또는 수동 업데이트에서 자동으로 다시 빌드하므로, 이전 패치 바이너리를 최신 것으로 오인하지 않습니다.

현재 패치는 Codex CLI `0.151.0`에서 검증했습니다. 이후 버전에서도 소스 구조가 호환되면 기존 패치를 자동 적용합니다. 업스트림 리팩터링으로 충돌하면 프로그램이 새 코드를 스스로 작성할 수는 없으므로 공식 CLI로 폴백하며, 이 저장소에 해당 버전용 패치가 게시된 뒤 다음 업데이트에서 자동 복구됩니다.

## 안전장치와 자체 복구

실행 관리자는 다음 구성 요소를 검사합니다.

- 패치된 `codex` 바이너리
- 공식 `codex-code-mode-host`
- `codex-package.json`
- 번들 검색 도구 `rg`
- 샌드박스 도우미 `bwrap`

구성 요소가 빠졌거나 공식 버전과 커스텀 버전이 다르면 재조립 또는 재빌드를 시도합니다. 패치 적용이나 빌드가 실패하면 업데이트 명령을 실패 상태로 종료하고 공식 `codex-upstream`을 실행합니다. 같은 실패를 일반 실행 때마다 오래 재시도하지 않도록 동일 버전·패치 조합은 6시간 동안 빠르게 폴백하며, 명시적인 `codex update`는 즉시 다시 시도합니다.

공식 npm 업데이트가 `~/.local/bin/codex` 링크를 교체하거나 삭제해도, 관리자는 실제 설치 경로를 기준으로 동작한 뒤 링크를 다시 연결합니다. 예약 업데이트는 공개 런처가 일시적으로 없어도 관리자 스크립트를 직접 호출하며, 진단은 공개 런처와 `codex-upstream`까지 검사합니다.

설치 상태는 다음 명령으로 검사할 수 있습니다.

```bash
~/.local/share/codex-project-session-browser/manager/doctor.sh
```

일부 시스템에서 공식 패키지의 번들 `zsh`가 호환되지 않으면 해당 선택 구성 요소만 제외하고 시스템 기본 셸을 사용합니다.

## 개인정보와 보안

- 이 저장소는 실행 바이너리를 배포하지 않습니다.
- API 키, 로그인 토큰, 대화 세션, 로컬 설정을 포함하지 않습니다.
- 세션을 외부 서버로 추가 전송하지 않습니다.
- Desktop 상태 파일은 로컬에서 읽기 전용으로 열며 수정하거나 업로드하지 않습니다.
- 기본 상태 파일이 갱신 중이거나 손상됐으면 `.codex-global-state.json.bak`을 읽고, 둘 다 사용할 수 없으면 `cwd` 기준으로 폴백합니다.
- 상태 파일은 16 MiB보다 크면 읽지 않아 비정상 파일로 인한 과도한 메모리 사용을 막습니다.
- 빌드는 사용자의 컴퓨터에서 공식 OpenAI Codex 소스 태그를 기반으로 수행됩니다.
- 호환 패치는 이 GitHub 저장소의 HTTPS 주소에서만 자동으로 받고, 버전 목록에 기록된 SHA-256과 일치할 때만 설치합니다.

## 제거

```bash
./uninstall.sh
```

`~/.local/bin/codex`가 공식 `codex-upstream`을 가리키도록 복구됩니다. 다시 설치할 때 빌드 캐시를 재사용할 수 있도록 `~/.local/share/codex-project-session-browser`의 소스와 캐시는 자동 삭제하지 않습니다.

## 검증 상태

- Desktop 프로젝트 ID 그룹화, 다중 `cwd`, 빈 프로젝트, 백업 파일, 모호한 루트 폴백 테스트
- 프로젝트 진입/복귀, 새 세션 경로 전달, 네이티브 TUI 스냅샷 테스트
- 기존 resume, archive, remote, fork 동작 회귀 테스트
- 새 기능 관련 단위·스냅샷 테스트 14개 통과
- 깨끗한 Codex `rust-v0.151.0` 태그에 패치 적용 확인
- 격리된 가짜 홈에서 설치 → 실행 → 제거 흐름 확인
- GitHub Actions에서 셸 구문과 패치 적용 가능 여부 자동 검사

## 추가 문서

- [내부 구조와 실행 흐름](docs/architecture.md)
- [문제 해결](docs/troubleshooting.md)

## 라이선스

Apache-2.0. 이 패치는 Apache-2.0으로 배포되는 OpenAI Codex 프로젝트를 수정합니다. 저작권과 파생 코드 고지는 `NOTICE`를 참고하세요.
