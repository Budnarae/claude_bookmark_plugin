---
description: bookmark 플러그인의 전체 커맨드 사용법과 옵션, 색상 의미를 한눈에 보여줍니다. 도움말/usage/사용법 요청 시 사용.
---

# /bookmark:help — bookmark 플러그인 도움말

bookmark 플러그인의 모든 커맨드 사용법을 정리해 출력한다.
사용자가 `/bookmark:help`를 호출하거나 "bookmark 사용법", "도움말", "어떤 명령 있어?" 등을 물으면 아래 내용을 출력한다.

## 사용법

```
/bookmark:help [커맨드명]
```

- 인자 없음: 전체 커맨드 요약 출력 (아래 "전체 출력")
- 커맨드명 지정 (`create`/`plan`/`renumber`/`restore`): 해당 커맨드의 상세 사용법만 출력

## 실행 절차

### Step 1 — 인자 파싱

- `TOPIC`: 첫 번째 인자 (선택). `create`/`plan`/`renumber`/`restore`/`help` 중 하나거나 없음

### Step 2 — 출력

`TOPIC`이 없으면 "전체 출력"을, 특정 커맨드면 해당 커맨드 블록만 출력한다.
인식 불가한 `TOPIC`이면 전체 출력 후 "알 수 없는 커맨드: <TOPIC>" 한 줄을 덧붙인다.

이 스킬은 파일을 수정하지 않고 VS 리프레시도 하지 않는다. 출력만 한다.

---

## 전체 출력

```
bookmark — Visual Studio Bookmark Studio 연동 플러그인
거대한 코드베이스에서 작업 관련 위치에만 북마크를 자동 생성·관리한다.

커맨드:
  /bookmark:create    작업 설명 → 관련 코드 분석 → 북마크 생성
  /bookmark:plan      큰 작업을 폴더 단위로 분할해 북마크 생성 (기본 dry-run)
  /bookmark:renumber  폴더 내 북마크 번호(01,02,..) 재정렬
  /bookmark:restore   코드 수정으로 밀린 북마크를 lineText 기준으로 위치 원복
  /bookmark:help      이 도움말

색상 의미:
  🔴 red     직접 수정할 위치
  🟠 orange  수정의 영향을 받는 위치
  🔵 blue    참조/이해용
  🟢 green   테스트

자세히: /bookmark:help <커맨드명>
```

---

## create 상세

```
/bookmark:create — 코드베이스 북마크 자동 생성

작업 설명을 기반으로 관련 코드를 탐색해 .bookmarks.json에 북마크를 생성한다.

문법:
  /bookmark:create <작업 설명> [--folder <폴더명>] [--mode overwrite|append]
                   [--root <경로>] [--explain]

옵션:
  --folder   북마크 폴더명. '/'로 중첩 가능. 기본: 작업 설명 15자 축약
  --mode     append(추가, 기본) / overwrite(폴더 교체)
  --root     .bookmarks.json 위치. 기본: 자동 탐색
  --explain  생성 후 각 북마크 상세 설명 출력

예시:
  /bookmark:create "로그인 API 추가"
  /bookmark:create "결제 검증" --folder 결제/검증 --explain
```

---

## plan 상세

```
/bookmark:plan — 작업 분할 후 폴더별 북마크 생성

큰 작업을 연관 단위로 분할하고 폴더별 북마크를 만든다. 기본은 계획 미리보기(dry-run).

문법:
  /bookmark:plan <작업 설명> [--parent <상위폴더>] [--confirm]
                 [--explain] [--mode overwrite|append]

옵션:
  --parent   모든 서브폴더의 상위 폴더명
  --confirm  dry-run 없이 바로 실행 (기본: dry-run)
  --explain  각 북마크 상세 설명 (--confirm 시에만)
  --mode     append(기본) / overwrite

흐름:
  /bookmark:plan "로그인 개선"            # 계획 확인
  /bookmark:plan "로그인 개선" --confirm  # 실행
```

---

## renumber 상세

```
/bookmark:renumber — 북마크 번호 재정렬

폴더 내 북마크 label 번호를 현재 순서 기준 01,02,03..로 재번호링한다.
번호 없는 항목은 순서·내용 그대로 유지한다.

문법:
  /bookmark:renumber <폴더명> [--root <경로>]

예시:
  /bookmark:renumber 결제/검증
```

---

## restore 상세

```
/bookmark:restore — 밀린 북마크 위치 원복

코드 수정으로 lineNumber가 어긋난 북마크를, 저장된 lineText를 실제 파일에서
재탐색해 올바른 라인으로 복구한다. lineNumber만 갱신, 다른 필드는 불변.

문법:
  /bookmark:restore [폴더명] [--root <경로>] [--dry-run]

옵션:
  폴더명     원복할 폴더. 생략 시 전체 폴더 대상
  --root     .bookmarks.json 위치. 기본: 자동 탐색
  --dry-run  파일 미수정, 이동 미리보기만 출력

상태 표시:
  MOVED    라인이 밀려 새 위치로 복구됨
  OK       이미 올바른 위치
  LOST     lineText가 코드에서 사라짐 (수동 확인 필요)
  MISSING  파일 자체가 없음

예시:
  /bookmark:restore --dry-run      # 전체 미리보기
  /bookmark:restore 결제/검증       # 해당 폴더만 원복
```
