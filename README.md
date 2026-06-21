# bookmark — Claude Code Plugin

Visual Studio 코드베이스 탐색을 위한 북마크 자동 생성 플러그인입니다.
작업 설명을 입력하면 관련 코드를 분석해 [Bookmark Studio](#의존성) 북마크를 자동으로 생성·정렬합니다.

## 의존성

**Visual Studio 확장 필수:**

| 확장 | 설치 |
|---|---|
| [Bookmark Studio](https://marketplace.visualstudio.com/items?itemName=MadsKristensen.BookmarkStudio) by Mads Kristensen | Visual Studio Marketplace에서 설치 |

Bookmark Studio는 북마크를 `.bookmarks.json` 파일로 관리하며, 이 플러그인은 해당 파일을 직접 수정한 뒤 Visual Studio DTE 자동화를 통해 리프레시합니다.

> **참고**: Visual Studio 2019 이상 필요. VS Code에서는 동작하지 않습니다.

## 설치

```bash
claude plugin install bookmark
```

또는 로컬 설치:

```bash
claude --plugin-dir ~/.claude/skills/bookmark
```

## 스킬

### `/bookmark:create` — 북마크 생성

작업 설명을 기반으로 코드베이스를 분석해 관련 파일/위치에 북마크를 생성합니다.

```
/bookmark:create <작업 설명> [--folder <폴더명>] [--mode overwrite|append] [--root <경로>] [--explain]
```

| 인자 | 설명 | 기본값 |
|---|---|---|
| `--folder` | 북마크 폴더명. `/`로 중첩 가능 | 작업 설명 15자 축약 |
| `--mode` | `append` (추가) / `overwrite` (교체) | `append` |
| `--root` | `.bookmarks.json` 위치 | 자동 탐색 |
| `--explain` | 생성 후 각 북마크 상세 설명 출력 | off |

**색상 의미:**
- 🔴 `red` — 직접 수정해야 하는 위치
- 🟠 `orange` — 수정의 영향을 받는 위치
- 🔵 `blue` — 참조/이해용
- 🟢 `green` — 테스트

---

### `/bookmark:plan` — 작업 분할 후 북마크 생성

큰 작업을 연관 단위로 분할하고, 각 단위에 대응하는 폴더를 만들어 북마크를 정리합니다.
기본 동작은 계획 미리보기(dry-run)이며 `--confirm`으로 실제 실행합니다.

```
/bookmark:plan <작업 설명> [--parent <상위폴더명>] [--confirm] [--explain] [--mode overwrite|append]
```

| 인자 | 설명 | 기본값 |
|---|---|---|
| `--parent` | 모든 서브폴더의 상위 폴더명 | 없음 (루트에 생성) |
| `--confirm` | dry-run 없이 바로 실행 | off (dry-run) |
| `--explain` | 각 북마크 상세 설명 출력 (`--confirm` 시에만) | off |
| `--mode` | `append` / `overwrite` | `append` |

**사용 흐름:**
```
/bookmark:plan "로그인 API 추가"             # 계획 확인
/bookmark:plan "로그인 API 추가" --confirm   # 실행
```

---

### `/bookmark:renumber` — 번호 재정렬

북마크를 수동으로 추가/삭제한 후 번호 정합성을 복구합니다.
번호(`01.`, `02.` 등)로 시작하는 항목만 재번호링하며, 번호 없는 항목은 그대로 유지합니다.

```
/bookmark:renumber <폴더명> [--root <경로>]
```

## 동작 방식

1. 코드베이스 분석 → 관련 파일/메서드 탐색 (entry → leaf 순)
2. `.bookmarks.json` 수정 (지정 폴더 외 기존 북마크 보존)
3. PowerShell DTE 자동화로 Visual Studio 즉시 리프레시

Visual Studio가 실행 중이어야 자동 리프레시가 동작합니다. 미실행 시 Bookmark Studio에서 수동 Refresh 클릭 필요.
