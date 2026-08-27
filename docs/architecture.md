# 내부 구조와 실행 흐름

## 설계 목표

이 프로젝트의 핵심 목표는 별도의 세션 선택기를 만드는 것이 아니라, **Codex CLI의 기존 `resume` TUI에 프로젝트 탐색 단계를 직접 추가하는 것**입니다.

따라서 다음 원칙을 사용합니다.

- 사용자는 계속 `codex resume`를 실행합니다.
- 키보드 처리, 화면 렌더링, 세션 로딩은 기존 Codex TUI 구조를 사용합니다.
- 프로젝트 목록과 세션 목록은 같은 선택기 상태 안에서 전환됩니다.
- Desktop 프로젝트 메타데이터는 읽기 전용 보조 인덱스로만 사용합니다.
- Desktop 상태를 사용할 수 없으면 원래 세션 메타데이터인 `cwd`로 폴백합니다.
- 공식 실행 파일과 런타임은 항상 보존해 실패 시 복귀할 수 있게 합니다.
- 커스텀 바이너리만 단독으로 설치하지 않고 같은 버전의 전체 공식 런타임과 함께 조립합니다.

## 구성 요소

```text
사용자
  │
  └─ ~/.local/bin/codex
       │
       └─ manager/dispatch.sh
            ├─ 정상 상태 ─────────> packages/<version>/bin/codex
            ├─ 버전 변경/누락 ────> manager/rebuild.sh
            └─ 패치/빌드 실패 ────> ~/.local/bin/codex-upstream
```

### `install.sh`

- 필요한 명령과 npm 전역 Codex 설치를 검사합니다.
- 공식 실행 파일을 `codex-upstream`으로 보존합니다.
- OpenAI Codex 저장소를 `--filter=blob:none --no-checkout` 방식으로 부분 복제합니다.
- 관리자 스크립트와 패치를 사용자 데이터 디렉터리에 설치합니다.
- 현재 공식 버전에 맞는 첫 빌드를 실행합니다.

### `manager/dispatch.sh`

모든 `codex` 실행이 처음 통과하는 얇은 런처입니다.

- 공식 npm 패키지 버전과 현재 커스텀 버전을 비교합니다.
- 커스텀 런타임의 필수 구성 요소가 모두 존재하는지 검사합니다.
- 정상 상태이면 패치된 바이너리를 실행합니다.
- 버전이 다르거나 파일이 빠졌으면 `rebuild.sh`를 호출합니다.
- 복구에 실패하면 공식 `codex-upstream`을 실행합니다.
- 첫 인자가 `update`이면 공식 업데이트 후 패치 재적용 흐름을 실행합니다.

### `manager/rebuild.sh`

버전별 소스, 패치, 빌드, 런타임 조립을 담당합니다.

1. npm 패키지에서 현재 버전과 플랫폼 런타임을 찾습니다.
2. `codex-code-mode-host`, `rg`, `bwrap`을 검사합니다.
3. 공식 런타임을 `packages/<version>`에 복사합니다.
4. 패치 SHA-256을 worktree와 설치된 패키지의 SHA-256 기록과 비교합니다.
5. 새 버전 또는 새 패치이면 공식 `rust-v<version>` 태그로 worktree를 만듭니다.
6. `git apply --check` 후 패치를 적용합니다.
7. 공유 Cargo target 디렉터리에서 `codex-cli` 릴리스를 빌드합니다.
8. 빌드한 바이너리를 같은 버전의 공식 런타임에 설치합니다.
9. 설치된 바이너리의 패치 SHA-256을 기록합니다.
10. `codex-current` 링크와 `current-version`을 갱신합니다.

공유 빌드 캐시는 버전이 올라가도 공통 의존성을 다시 활용하기 위한 구조입니다.

## Codex 소스 변경 지점

패치는 구현·테스트·스냅샷을 포함한 아홉 파일을 변경하거나 추가합니다.

### `codex-rs/tui/src/resume_picker/desktop_projects.rs`

- `CODEX_HOME/.codex-global-state.json`과 백업 파일을 읽습니다.
- `local-projects`, `project-order`, `thread-project-assignments`만 역직렬화합니다.
- 프로젝트 ID, 이름, 모든 루트 폴더, 시간, 세션 연결을 메모리 인덱스로 만듭니다.
- 한 루트가 여러 프로젝트에 연결되면 해당 루트의 자동 추론을 비활성화합니다.
- 파싱 실패, 누락, 16 MiB 초과 시 빈 인덱스를 반환해 `cwd` 폴백을 유지합니다.

### `codex-rs/tui/src/resume_picker/project_browser.rs`

- 명시적 Desktop 프로젝트 ID를 가장 먼저 사용합니다.
- 미연결 세션은 고유한 Desktop 루트와 정확히 일치할 때 프로젝트를 추론합니다.
- 나머지 세션을 `cwd`별 폴백 프로젝트로 그룹화합니다.
- 세션이 없거나 폴더가 없는 Desktop 프로젝트도 합성 프로젝트 행으로 만듭니다.
- 프로젝트 행에 폴더명과 세션 수를 표시합니다.
- 선택한 프로젝트 ID와 선택적 주 폴더를 상태로 보관합니다.
- 프로젝트 내부 목록의 첫 줄에 합성 행인 `＋ 새 대화 시작`을 추가합니다.
- 합성 프로젝트 행과 실제 세션 행을 구분합니다.

### `codex-rs/tui/src/resume_picker.rs`

- resume 선택 결과에 `new_session_cwd`를 추가합니다.
- Enter/Right로 프로젝트 진입, Escape/Left로 복귀하도록 처리합니다.
- Desktop 프로젝트 내부에서는 전체 세션을 로드한 뒤 프로젝트 ID로 필터링해 여러 `cwd`를 보존합니다.
- `cwd` 폴백 프로젝트 내부에서는 기존처럼 서버의 `cwd` 필터를 사용합니다.
- 활성 로컬 시작 화면이고 검색어가 없을 때만 새 대화 행을 표시합니다.
- 포크, 원격, 보관 화면에는 새 대화 행이 영향을 주지 않도록 범위를 제한합니다.
- 프로젝트 행에서는 archive 단축키가 동작하지 않도록 실제 thread ID를 확인합니다.

### `codex-rs/tui/src/lib.rs`

- 선택기에서 반환한 `new_session_cwd`를 시작 작업 디렉터리로 사용합니다.
- 단순히 화면 표시만 바꾸는 것이 아니라 실제 새 세션 구성의 `cwd`를 교체합니다.
- 선택한 프로젝트 경로를 기준으로 설정을 다시 로드해 프로젝트 설정이 적용되게 합니다.

### `codex-rs/tui/src/resume_picker/archive.rs`

- 프로젝트와 새 대화 합성 행에는 실제 thread ID가 없다는 점을 확인합니다.
- 실제 세션 행을 선택했을 때만 archive 단축키를 표시하고 처리합니다.

### 테스트 및 스냅샷

- `desktop_projects_tests.rs`에서 상태 파일, 백업, 프로젝트 순서, 연결 종류, 공유 루트 안전성을 검사합니다.
- `project_browser_tests.rs`에서 ID 그룹화, 다중 폴더, 빈 프로젝트, 루트 추론, 진입/복귀, 포크 비영향, 새 세션 경로 전달을 검사합니다.
- TUI 스냅샷은 Desktop 프로젝트 개요와 새 대화 행이 기존 네이티브 목록에 렌더링되는지 검사합니다.

## 데이터 흐름

```text
Codex Desktop global state (read-only)
  ├─ project P: roots=[/work/alpha, /work/shared]
  └─ session A/B -> project P
                         │
Codex app-server thread/list
  ├─ session A: cwd=/work/alpha
  ├─ session B: cwd=/work/shared
  └─ session C: cwd=/work/beta
                         │
                         ▼
ProjectBrowser::overview_rows
  ├─ project P · 2 sessions
  └─ beta      · 1 session (cwd fallback)
                         │
                         ▼ Enter project P
전체 thread/list + client-side project ID filter
  ├─ ＋ 새 대화 시작 (/work/alpha)
  ├─ session A
  └─ session B
```

프로젝트 정보는 새로운 데이터베이스에 저장하지 않습니다. Desktop 상태 파일과 세션 목록을 읽어 실행 중에만 인덱스를 만들며, 파일에는 아무것도 쓰지 않습니다.

## 새 세션 선택 흐름

```text
사용자가 ＋ 새 대화 시작 선택
  │
  ├─ SessionSelection::StartFresh 반환
  └─ new_session_cwd=/선택한/프로젝트 반환
       │
       ▼
startup cwd 결정
       │
       ▼
선택한 cwd 기준 설정 재로드
       │
       ▼
새 Codex 세션 시작
```

`StartFresh`만 반환하면 기존 resume 선택기의 취소 동작과 구분할 수 없기 때문에, 선택한 프로젝트 경로를 별도의 결과 필드로 함께 전달합니다.

## 업데이트 실패 시 동작

패치는 특정 소스 구조를 전제로 하는 unified diff입니다. 새 Codex 버전에서 관련 코드가 크게 바뀌면 `git apply --check`가 실패할 수 있습니다.

이 경우:

1. 손상된 커스텀 바이너리를 설치하지 않습니다.
2. 경고를 출력합니다.
3. 공식 `codex-upstream`으로 같은 명령을 실행합니다.
4. 패치를 새 버전 소스에 맞게 갱신하면 다시 커스텀 빌드를 사용할 수 있습니다.

## 배포하지 않는 항목

- 컴파일된 Codex 바이너리
- 공식 npm 런타임 파일
- Cargo 빌드 캐시
- 사용자 세션 및 대화 파일
- 인증 토큰과 API 키
- `~/.codex` 설정

저장소는 재현에 필요한 패치와 관리자 스크립트만 포함합니다.
