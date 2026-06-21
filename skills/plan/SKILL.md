---
description: 큰 작업을 연관 단위로 분할하고 폴더별로 북마크를 생성합니다. 기본 동작은 계획 미리보기(dry-run)이며 --confirm으로 실행합니다.
---

# /bookmark:plan — 작업 분할 후 폴더별 북마크 생성

큰 작업을 서로 연관 있는 단위로 분할하고, 각 단위에 대응하는 폴더를 만들어 북마크를 정리합니다.
기본 동작은 계획만 출력(dry-run)하며, `--confirm`을 추가해야 실제 북마크를 생성합니다.

## 사용법

```
/bookmark:plan <작업 설명> [--parent <상위폴더명>] [--confirm] [--explain] [--mode overwrite|append]
```

- `--parent`: 모든 서브폴더를 이 폴더 아래에 생성 (예: `--parent 로그인개선` → `로그인개선/인증`, `로그인개선/API`)
- `--confirm`: dry-run 없이 바로 실행
- `--explain`: 북마크 생성 후 각 위치에 대한 상세 설명 출력 (`--confirm`과 함께 사용 시에만 출력)
- `--mode`: `append` (기본값) / `overwrite`

## 실행 절차

### Step 1 — 인자 파싱

args에서 다음을 추출한다:
- `TASK_DESC`: 작업 설명 (필수)
- `PARENT`: `--parent` 값 (없으면 빈 값)
- `CONFIRM`: `--confirm` 플래그 존재 여부 (true/false, 기본: false)
- `EXPLAIN`: `--explain` 플래그 존재 여부 (true/false)
- `MODE`: `--mode` 값 (기본: `append`)

### Step 2 — `.bookmarks.json` 위치 탐색

다음 순서로 탐색한다:
1. 현재 디렉토리에서 `.sln` 파일이 있는 디렉토리까지 부모를 거슬러 올라감
2. 해당 디렉토리에 `.bookmarks.json` 존재 여부 확인
3. 없으면 `.git` 루트 확인
4. 없으면 `.vs` 폴더 확인
5. 모두 없으면 솔루션 루트에 새로 생성 (`--confirm` 시에만)

이하 절차에서 이 경로를 `BOOKMARKS_FILE`이라 부른다 (Claude 컨텍스트 내 변수).

### Step 3 — 코드베이스 분석 및 작업 분할

`TASK_DESC`를 기반으로 코드베이스를 탐색하고, 작업을 서로 연관 있는 단위로 분할한다.

**분할 기준:**
- 같은 레이어/모듈에 속한 코드끼리 묶는다 (예: 인증 로직, API 엔드포인트, DB 접근)
- 변경 이유가 같은 파일끼리 묶는다
- 서브태스크 수: 2~6개가 적절. 너무 잘게 쪼개지 않는다
- 각 서브태스크 북마크 수: 2~8개

**각 서브태스크에 대해 다음을 결정한다:**
- 서브태스크명 → 폴더명 (15자 내외 슬러그)
- 포함할 파일/위치 목록 (entry → leaf 순서)
- 각 북마크의 색상 (작업 행동 유형 기준):
  - `red`: 직접 수정해야 하는 위치
  - `orange`: 수정으로 인해 영향받는 위치
  - `blue`: 참조/이해용
  - `green`: 테스트

**폴더 경로 결정:**
- `PARENT`가 있으면: `PARENT/서브태스크명` (예: `로그인개선/인증처리`)
- `PARENT`가 없으면: `서브태스크명` (예: `인증처리`)

### Step 4 — 분기: dry-run vs 실행

**`CONFIRM`이 false인 경우 (dry-run) → Step 5로**
**`CONFIRM`이 true인 경우 (실행) → Step 6으로**

### Step 5 — 계획 출력 (dry-run)

다음 형식으로 분할 계획을 출력하고 종료한다:

```
분할 계획: <TASK_DESC>
총 <N>개 서브태스크

📁 <PARENT/>서브태스크1명/         (북마크 <N>개)
  01. [red]    파일경로:라인 — 설명
  02. [orange] 파일경로:라인 — 설명
  ...

📁 <PARENT/>서브태스크2명/         (북마크 <N>개)
  01. [blue]   파일경로:라인 — 설명
  ...

실행하려면: /bookmark:plan "<TASK_DESC>" --confirm [기타 플래그 그대로]
```

이후 Step 6~9는 실행하지 않는다.

### Step 6 — JSON 병합 (실행 모드)

`BOOKMARKS_FILE`을 읽는다. 파일이 없으면 초기 구조로 시작한다:
```json
{
  "documentPathRoot": "bookmarksFile",
  "root": { "_bookmarks": [] },
  "expandedFolders": []
}
```

각 서브태스크에 대해 순서대로 처리한다:

**`overwrite` 모드**: 해당 폴더 키를 제거 후 새로 삽입
**`append` 모드**: 해당 폴더의 `_bookmarks` 배열에 새 항목을 끝에 추가

`documentPath`는 `BOOKMARKS_FILE` 위치 기준 상대 경로로 변환한다 (슬래시 `/` 사용).

**북마크 JSON 구조:**
```json
{
  "id": "<새 UUID v4>",
  "documentPath": "src/Services/AuthService.cs",
  "lineNumber": 42,
  "lineText": "public async Task<Token> AuthenticateAsync(Credentials creds)",
  "label": "02. AuthService.AuthenticateAsync — 토큰 생성 로직",
  "color": "red",
  "createdUtc": "<현재 UTC ISO8601>"
}
```

`label` 형식: `"<순번(2자리 zero-padding)>. <클래스/메서드명> — <역할 한 줄 설명>"`

`expandedFolders` 배열에 각 폴더 경로가 없으면 추가한다.

### Step 7 — 파일 쓰기

병합된 JSON을 `BOOKMARKS_FILE`에 들여쓰기(2칸) 형식으로 저장한다.
다른 폴더의 내용은 절대 수정하지 않는다.

### Step 8 — VS 리프레시

다음 PowerShell 명령을 실행한다:

```
pwsh -File "C:\Users\budnarae\.claude\skills\bookmark\bin\refresh_bookmarks.ps1"
```

실행 실패 시 사용자에게 Bookmark Studio에서 수동 Refresh를 클릭하도록 안내한다.

### Step 9 — 결과 보고

```
북마크 생성 완료: <N>개 서브태스크, 총 <M>개 북마크

📁 인증처리/  (3개)
  01. [red]    src/Auth/AuthController.cs:15
  02. [red]    src/Auth/AuthService.cs:42
  03. [green]  tests/AuthServiceTest.cs:10

📁 DB접근/  (2개)
  01. [orange] src/Repo/UserRepository.cs:88
  02. [blue]   src/Models/UserEntity.cs:5

VS 리프레시: 완료 / 실패 (수동 리프레시 필요)
```

### Step 10 — 설명 출력 (`--explain` 활성 시에만)

`EXPLAIN`이 true인 경우, Step 9 이후 각 북마크에 대한 상세 설명을 출력한다:

```
## 북마크 설명

### [인증처리] 01. AuthController.cs:15 [red — 직접 수정]
<이 위치가 작업과 어떻게 연관되는지, 무엇을 수정해야 하는지 2~4문장>

### [인증처리] 02. AuthService.cs:42 [red — 직접 수정]
<설명>
...
```

## 주의사항

- 기존 북마크 파일의 다른 폴더는 절대 수정하지 않는다
- `_bookmarks` 키는 항상 해당 객체의 첫 번째 키로 유지한다
- UUID는 RFC 4122 v4 형식으로 새로 생성한다
- 파일 경로 구분자는 JSON 내에서 항상 `/`를 사용한다
