---
description: 코드 수정으로 라인이 밀린 북마크를 lineText 기준으로 재탐색해 올바른 lineNumber로 원복합니다.
---

# /bookmark:restore — 밀린 북마크 위치 원복

코드에 라인이 추가/삭제되면 북마크의 `lineNumber`가 실제 코드와 어긋난다.
이 스킬은 각 북마크에 저장된 `lineText`를 실제 파일에서 재탐색해 `lineNumber`를 올바른 위치로 복구한다.

## 사용법

```
/bookmark:restore [폴더명] [--root <솔루션 루트 경로>] [--dry-run]
```

- `폴더명`: 원복할 북마크 폴더 이름. 중첩 폴더는 `/`로 구분 (예: `로그인/AI`). **생략 시 모든 폴더의 모든 북마크를 대상으로 함**
- `--root`: `.bookmarks.json`이 있는 디렉토리 (기본값: 자동 탐색)
- `--dry-run`: 파일을 수정하지 않고 어떤 북마크가 어디로 이동될지 미리보기만 출력

## 실행 절차

### Step 1 — 인자 파싱

- `FOLDER_NAME`: 첫 번째 인자 (선택). 없으면 전체 대상
- `ROOT`: `--root` 값, 없으면 Step 2에서 자동 탐색
- `DRY_RUN`: `--dry-run` 플래그 존재 여부 (true/false, 기본: false)

### Step 2 — `.bookmarks.json` 위치 탐색

다음 순서로 탐색한다:
1. 현재 디렉토리에서 `.sln` 파일이 있는 디렉토리까지 부모를 거슬러 올라감
2. 해당 디렉토리에 `.bookmarks.json` 존재 여부 확인
3. 없으면 `.git` 루트 확인
4. 없으면 `.vs` 폴더 확인
5. 없으면 오류 출력 후 종료

이하 절차에서 이 경로를 `BOOKMARKS_FILE`이라 부른다 (Claude 컨텍스트 내 변수, 디스크에 별도 저장하지 않음).

### Step 3 — 대상 북마크 수집

`BOOKMARKS_FILE`을 읽는다.

- `FOLDER_NAME`이 지정된 경우: `root` 객체에서 해당 폴더(중첩이면 `/` 계층 탐색)의 `_bookmarks` 배열만 대상으로 한다. 폴더가 없으면 오류 출력 후 종료.
- `FOLDER_NAME`이 없는 경우: `root` 아래 모든 폴더를 재귀적으로 순회하며 모든 `_bookmarks` 항목을 대상으로 한다.

각 대상 북마크는 `(폴더경로, documentPath, lineNumber, lineText, label)`을 가진다.

### Step 4 — 각 북마크 재탐색

대상 북마크별로 다음을 수행한다:

1. **파일 로드**: `documentPath`(`BOOKMARKS_FILE` 위치 기준 상대 경로)를 절대 경로로 변환해 실제 파일을 읽는다.
   - 파일이 없으면 → 상태 `MISSING_FILE`, `lineNumber` 그대로 유지, 보고에 표시
2. **현재 위치 확인**: 저장된 `lineNumber`의 실제 라인 텍스트가 `lineText`와 (양끝 공백 제거 후) 일치하면 → 상태 `OK`, 변경 없음
3. **재탐색**: 일치하지 않으면 파일 전체에서 `lineText`와 일치하는 라인을 찾는다.
   - **비교 기준**: 양끝 공백을 제거한 문자열 완전 일치 (1차)
   - 1차에서 후보가 없으면 내부 연속 공백을 단일 공백으로 정규화한 뒤 비교 (2차)
   - **후보가 1개**: 그 라인으로 `lineNumber` 갱신 → 상태 `MOVED`
   - **후보가 여러 개**: 기존 `lineNumber`에 **가장 가까운** 후보를 선택 → 상태 `MOVED` (동거리면 위쪽=작은 번호 우선)
   - **후보가 0개**: `lineText`가 코드에서 사라진 것으로 간주 → 상태 `LOST`, `lineNumber` 그대로 유지, 보고에 표시

> 절대 `lineText`를 변경하지 않는다. `lineNumber`만 갱신한다.

### Step 5 — 분기: dry-run vs 실행

- `DRY_RUN`이 true → Step 6 건너뛰고 Step 7로 (파일 미수정)
- `DRY_RUN`이 false → Step 6 수행

### Step 6 — 파일 쓰기

`MOVED` 상태인 북마크의 `lineNumber`만 갱신한 JSON을 `BOOKMARKS_FILE`에 들여쓰기(2칸) 형식으로 저장한다.

- `lineText`, `label`, `color`, `id` 등 다른 필드는 절대 수정하지 않는다
- 대상이 아닌 폴더/북마크는 절대 수정하지 않는다
- `_bookmarks` 배열의 순서는 그대로 유지한다 (`lineNumber`만 바뀜)

### Step 7 — VS 리프레시 (dry-run이 아닐 때만)

다음 PowerShell 명령을 실행한다:

```
pwsh -File "..\..\bin\refresh_bookmarks.ps1"
```

실행 실패 시 사용자에게 Bookmark Studio에서 수동 Refresh를 클릭하도록 안내한다.

### Step 8 — 결과 보고

```
북마크 원복: <FOLDER_NAME 또는 "전체">   [DRY-RUN]
대상 <N>개 | 이동 <X>개 · 정상 <Y>개 · 분실 <Z>개 · 파일없음 <W>개

  [MOVED]   src/Services/AuthService.cs   42 → 51   "02. AuthService.AuthenticateAsync — ..."
  [OK]      src/Api/AuthController.cs      15        "01. AuthController — ..."
  [LOST]    src/Repo/UserRepository.cs     88        "03. UserRepository — ..."   ← lineText 사라짐, 수동 확인 필요
  [MISSING] src/Old/Removed.cs             10        "04. ... — ..."              ← 파일 없음

VS 리프레시: 완료 / 실패 (수동 리프레시 필요) / 생략(dry-run)
```

`LOST`, `MISSING` 항목이 있으면 사용자에게 해당 북마크는 자동 복구 불가하니 직접 위치를 확인하거나 `/bookmark:create`로 재생성하라고 안내한다.

## 주의사항

- `lineNumber`만 갱신하고 다른 필드는 절대 건드리지 않는다
- 대상 외 폴더/북마크는 절대 수정하지 않는다
- 같은 `lineText`가 여러 줄 존재하면 기존 위치에 가장 가까운 라인을 선택한다 (대량 중복 라인은 오복구 위험이 있으므로 보고에서 확인 권장)
- `--dry-run`으로 먼저 이동 결과를 확인한 뒤 실제 실행하는 것을 권장한다
