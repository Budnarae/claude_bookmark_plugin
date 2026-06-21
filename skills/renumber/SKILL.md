---
description: 지정한 북마크 폴더의 번호를 현재 순서 기준으로 01, 02, 03... 재정렬합니다. 번호 없는 항목은 유지합니다.
---

# /bookmark:renumber — 북마크 폴더 번호 재정렬

지정한 폴더의 북마크 label 번호를 현재 JSON 배열 순서 기준으로 01, 02, 03... 재번호링합니다.
사용자가 수동으로 북마크를 추가/삭제한 후 번호 정합성을 복구할 때 사용합니다.

## 사용법

```
/bookmark:renumber <폴더명> [--root <솔루션 루트 경로>]
```

- `폴더명`: 재번호링할 북마크 폴더 이름. 중첩 폴더는 `/`로 구분 (예: `로그인/AI`)
- `--root`: `.bookmarks.json`이 있는 디렉토리 (기본값: 자동 탐색)

## 실행 절차

### Step 1 — 인자 파싱

- `FOLDER_NAME`: 첫 번째 인자 (필수)
- `ROOT`: `--root` 값, 없으면 Step 2에서 자동 탐색

### Step 2 — `.bookmarks.json` 위치 탐색

다음 순서로 탐색한다:
1. 현재 디렉토리에서 `.sln` 파일이 있는 디렉토리까지 부모를 거슬러 올라감
2. 해당 디렉토리에 `.bookmarks.json` 존재 여부 확인
3. 없으면 `.git` 루트 확인
4. 없으면 `.vs` 폴더 확인
5. 없으면 오류 출력 후 종료

이하 절차에서 이 경로를 `BOOKMARKS_FILE`이라 부른다 (Claude 컨텍스트 내 변수, 디스크에 별도 저장하지 않음).

### Step 3 — 대상 폴더 탐색

`BOOKMARKS_FILE`을 읽어 `root` 객체에서 `FOLDER_NAME`에 해당하는 중첩 객체를 찾는다.

`FOLDER_NAME`에 `/`가 포함된 경우 계층적으로 탐색한다 (예: `로그인/AI` → `root.로그인.AI`).

폴더가 존재하지 않으면 오류 출력 후 종료한다.

### Step 4 — 재번호링

대상 폴더의 `_bookmarks` 배열을 **현재 순서 그대로** 유지하면서 label의 번호만 교체한다.

**번호 추출 및 교체 규칙:**
- label이 `숫자. ` 또는 `숫자숫자. ` 로 시작하면 해당 prefix를 새 번호로 교체
- 번호로 시작하지 않는 label은 그대로 유지 (사용자가 의도적으로 번호 없이 작성한 것으로 간주)
- 번호가 있는 항목만 순서대로 01, 02, 03... 재배정

예시:
```
변경 전: ["03. ServiceA — ...", "★ 내가 추가", "01. ControllerB — ...", "07. RepoC — ..."]
변경 후: ["01. ServiceA — ...", "★ 내가 추가", "02. ControllerB — ...", "03. RepoC — ..."]
```

### Step 5 — 파일 쓰기

변경된 내용을 `BOOKMARKS_FILE`에 들여쓰기(2칸) 형식으로 저장한다.
다른 폴더의 내용은 절대 수정하지 않는다.

### Step 6 — VS 리프레시

다음 PowerShell 명령을 실행한다:

```
pwsh -File "C:\Users\budnarae\.claude\plugins\bookmark\bin\refresh_bookmarks.ps1"
```

실행 실패 시 사용자에게 Bookmark Studio에서 수동 Refresh를 클릭하도록 안내한다.

### Step 7 — 결과 보고

```
재번호링 완료: <FOLDER_NAME>
총 <N>개 항목 재번호링 (번호 없는 항목 <M>개 유지)

  01. ServiceA — ...
  ★ 내가 추가        ← 번호 없는 항목, 순서 유지
  02. ControllerB — ...
  03. RepoC — ...
```
