---
description: 작업 설명을 기반으로 코드베이스를 분석해 Visual Studio Bookmark Studio에 북마크를 자동 생성합니다.
---

# /bookmark:create — 코드베이스 북마크 자동 생성

사용자가 작업 내용을 설명하면 코드베이스에서 관련 코드를 탐색하고,
Visual Studio Bookmark Studio의 `.bookmarks.json`을 갱신한 뒤 VS를 자동으로 리프레시합니다.

## 사용법

```
/bookmark:create <작업 설명> [--folder <폴더명>] [--mode overwrite|append] [--root <솔루션 루트 경로>] [--explain]
```

- `--folder`: 북마크 폴더 이름. `/`로 중첩 가능 (예: `로그인/검증레이어`). 기본값: 작업 설명을 15자 내외로 축약한 슬러그 (공백→`_`, 특수문자 제거)
- `--mode`: `append` (해당 폴더에 추가, 기본값) / `overwrite` (해당 폴더 교체)
- `--root`: `.bookmarks.json`이 있는 디렉토리 (기본값: 자동 탐색)
- `--explain`: 북마크 생성 후 각 위치에 대한 상세 설명을 출력

## 실행 절차

### Step 1 — 인자 파싱

args에서 다음을 추출한다:
- `TASK_DESC`: 작업 설명 (필수)
- `FOLDER_NAME`: `--folder` 값. 없으면 `TASK_DESC`를 15자 내외로 축약해 생성 (예: "로그인 API 추가 기능" → `로그인_API_추가`). `/`를 포함하면 중첩 폴더로 처리
- `MODE`: `--mode` 값 (기본: `append`)
- `ROOT`: `--root` 값, 없으면 Step 2에서 자동 탐색
- `EXPLAIN`: `--explain` 플래그 존재 여부 (true/false)

### Step 2 — `.bookmarks.json` 위치 탐색

`ROOT`가 지정되지 않은 경우, 다음 순서로 탐색한다:

1. 현재 디렉토리에서 `.sln` 파일이 있는 디렉토리까지 부모를 거슬러 올라감
2. 해당 디렉토리에 `.bookmarks.json` 존재 여부 확인
3. 없으면 `.git` 루트 확인
4. 없으면 `.vs` 폴더 확인
5. 모두 없으면 솔루션 루트에 새로 생성

이하 절차에서 이 경로를 `BOOKMARKS_FILE`이라 부른다 (Claude 컨텍스트 내 변수, 디스크에 별도 저장하지 않음).

### Step 3 — 코드베이스 분석

`TASK_DESC`를 기반으로 관련 코드를 탐색한다.

**탐색 전략 (순서대로):**

1. **키워드 추출**: `TASK_DESC`에서 도메인 용어, 기능명, 클래스명 후보를 추출한다
2. **진입점 탐색**: 추출한 키워드로 파일/클래스/메서드를 검색한다
   - Controller, Handler, Command, UseCase, Service, ViewModel 등 레이어 진입점 우선
   - 테스트 파일, 마이그레이션 파일, 생성된 파일(`.g.cs`, `.designer.cs`)은 제외
3. **호출 체인 추적**: 진입점에서 호출되는 메서드/클래스를 따라 내려간다
   - 외부 라이브러리 호출은 추적 중단
   - 최대 깊이: 8단계
4. **관련성 필터링**: `TASK_DESC`와 직접 관련 없는 코드(공통 유틸, 로깅 등)는 제외

**결과물**: 순서가 있는 북마크 목록
```
[(파일경로, 라인번호, 라인텍스트, 역할설명, 색상), ...]
```

**색상 배정 규칙 (작업 행동 유형 기준):**
- `red`: 이 작업에서 **직접 수정**해야 하는 파일/위치
- `orange`: 수정으로 인해 **영향받는** 파일 (호출하거나 호출받는 쪽)
- `blue`: **참조/이해용** — 맥락 파악을 위해 읽어야 하지만 건드리지 않음
- `green`: 관련 **테스트** 위치

깊이(depth)는 넘버링(01, 02...)으로만 표현하고 색상과 무관하게 배정한다.

### Step 4 — JSON 병합

`BOOKMARKS_FILE`을 읽는다. 파일이 없으면 초기 구조로 시작한다:
```json
{
  "documentPathRoot": "bookmarksFile",
  "root": { "_bookmarks": [] },
  "expandedFolders": []
}
```

**`overwrite` 모드**: `root` 객체에서 `FOLDER_NAME` 키를 제거 후 새로 삽입
**`append` 모드**: `root.FOLDER_NAME._bookmarks` 배열에 새 항목을 끝에 추가

`documentPath`는 `BOOKMARKS_FILE` 위치 기준 상대 경로로 변환한다 (슬래시 `/` 사용).

**생성할 북마크 JSON 구조:**
```json
{
  "id": "<새 UUID v4>",
  "documentPath": "src/Services/MyService.cs",
  "lineNumber": 42,
  "lineText": "public async Task<Result> ExecuteAsync(Command cmd)",
  "label": "02. MyService.ExecuteAsync — 핵심 비즈니스 로직",
  "color": "green",
  "createdUtc": "<현재 UTC ISO8601>"
}
```

`label` 형식: `"<순번(2자리 zero-padding, 예: 01, 02, ..., 10, 11)>. <클래스/메서드명> — <역할 한 줄 설명>"`

`expandedFolders` 배열에 `FOLDER_NAME`이 없으면 추가한다.

### Step 5 — 파일 쓰기

병합된 JSON을 `BOOKMARKS_FILE`에 들여쓰기(2칸) 형식으로 저장한다.

### Step 6 — VS 리프레시

다음 PowerShell 명령을 실행한다:

```
pwsh -File "C:\Users\budnarae\.claude\skills\bookmark\bin\refresh_bookmarks.ps1"
```

실행 실패 시 (VS 미실행 등) 사용자에게 수동으로 Bookmark Studio의 Refresh 버튼을 클릭하도록 안내한다.

### Step 7 — 결과 보고

다음 형식으로 요약을 출력한다:

```
북마크 생성 완료: <FOLDER_NAME>
총 <N>개 위치 | 모드: <MODE>

  01. [red]    src/Api/MyController.cs:15 — 직접 수정
  02. [orange] src/Services/MyService.cs:42 — 영향받는 코드
  03. [blue]   src/Config/AppConfig.cs:88 — 참조용
  04. [green]  tests/MyServiceTest.cs:10 — 테스트

VS 리프레시: 완료 / 실패 (수동 리프레시 필요)
```

### Step 8 — 설명 출력 (`--explain` 활성 시에만)

`EXPLAIN`이 true인 경우, Step 7 이후 다음 형식으로 각 북마크에 대한 상세 설명을 출력한다:

```
## 북마크 설명

### 01. MyController.cs:15 [red — 직접 수정]
이 작업에서 실제로 변경해야 하는 진입점입니다.
<이 위치가 작업과 어떻게 연관되는지, 무엇을 수정해야 하는지 2~4문장으로 설명>

### 02. MyService.cs:42 [orange — 영향받는 코드]
<수정의 영향을 받는 이유, 어떤 부분을 주의해야 하는지 2~4문장으로 설명>

...
```

## 주의사항

- 기존 북마크 파일의 다른 폴더는 절대 수정하지 않는다
- `_bookmarks` 키는 항상 해당 객체의 첫 번째 키로 유지한다
- UUID는 RFC 4122 v4 형식으로 새로 생성한다
- 파일 경로 구분자는 JSON 내에서 항상 `/`를 사용한다
