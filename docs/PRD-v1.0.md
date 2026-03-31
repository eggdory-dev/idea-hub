# PRD v1.0: 아이디어 인입 → 자동 개발 파이프라인

**버전**: 1.0
**작성일**: 2026-03-31
**상태**: MVP 구현 완료

---

## 1. 개요

기획자가 GitHub Issue Form으로 아이디어를 입력하면, 자동으로 분석 → 승인 → 레포 생성 → 개발 초기화까지 이어지는 파이프라인 시스템.

### 핵심 목표
- 아이디어 → 요구사항 → 개발까지 전환 비용 최소화
- 기획/개발 역할 분리
- Claude Code 중심 개발 워크플로우 구축
- GitHub 기반 상태 및 이력 관리

---

## 2. 시스템 구조

```
┌─────────────────────────────────────────────────────────┐
│                    idea-hub (중앙 레포)                    │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐           │
│  │  Issue    │───▶│ GitHub   │───▶│ Telegram │           │
│  │  Form    │    │ Actions  │    │  알림     │           │
│  └──────────┘    └──────────┘    └──────────┘           │
│       │               │               │                  │
│       ▼               ▼               ▼                  │
│  [intake]  →  [needs-review]  →  [approved]             │
│                                      │                   │
└──────────────────────────────────────┼───────────────────┘
                                       │
                            ┌──────────▼──────────┐
                            │  로컬 Claude Code    │
                            │                      │
                            │  1. init-project.sh  │
                            │  2. analyze-idea.sh  │
                            │  3. 개발 시작         │
                            └──────────┬──────────┘
                                       │
                            ┌──────────▼──────────┐
                            │  개별 프로젝트 레포    │
                            │                      │
                            │  - docs/             │
                            │  - src/              │
                            │  - CLAUDE.md         │
                            └─────────────────────┘
```

---

## 3. 상태 흐름

```
intake → needs-review → approved → building → done
                     ↘ rejected
                     ↘ on-hold
```

| 라벨 | 설명 | 트리거 |
|------|------|--------|
| `intake` | 아이디어 접수됨 | Issue 생성 시 자동 |
| `needs-review` | 검토 필요 | GitHub Actions 자동 전환 |
| `approved` | 승인됨, 개발 가능 | `/approve` 댓글 |
| `rejected` | 거절됨 | `/reject` 댓글 |
| `on-hold` | 보류 | 수동 라벨링 |
| `building` | 개발 중 | init-project.sh 실행 후 자동 |
| `done` | 완료 | 수동 라벨링 |

---

## 4. 기능 상세

### 4.1 아이디어 인입 (Issue Form)

**파일**: `.github/ISSUE_TEMPLATE/idea.yml`

| 필드 | 필수 | 설명 |
|------|------|------|
| 프로젝트 제목 | ✅ | 아이디어 핵심 요약 |
| 배경/문제 | ✅ | 해결하려는 문제 |
| 기대 효과 | ✅ | 실현 시 효과 |
| 핵심 기능 | ✅ | 필수 기능 목록 |
| 제외 범위 | ❌ | MVP 제외 항목 |
| 우선순위 | ✅ | 긴급/높음/보통/낮음 |
| 플랫폼 | ✅ | Web/Backend/Mobile/Monorepo 등 |
| 참고 자료 | ❌ | URL, 스크린샷 등 |

### 4.2 자동 알림 (GitHub Actions)

**파일**: `.github/workflows/on-idea-created.yml`

- Issue 생성 시 → 텔레그램 알림 전송
- `intake` → `needs-review` 라벨 자동 전환

**파일**: `.github/workflows/on-approve.yml`

- `/approve` 댓글 시 → `approved` 라벨 + 텔레그램 알림
- `/reject` 댓글 시 → `rejected` 라벨

### 4.3 프로젝트 초기화 (로컬 스크립트)

**파일**: `scripts/init-project.sh <issue_number>`

1. Issue에서 아이디어 정보 추출
2. approved 라벨 확인 (미승인 시 중단)
3. slug 기반 private repo 생성
4. `~/Documents/repository/projects/` 에 clone
5. 템플릿 적용 (CLAUDE.md, README, .gitignore, docs/)
6. 아이디어 원문을 `docs/idea-original.md`로 저장
7. 초기 commit & push
8. Issue에 레포 링크 댓글 + `building` 라벨

### 4.4 아이디어 분석 (Claude Code)

**파일**: `scripts/analyze-idea.sh <issue_number>`

Claude Code가 아이디어를 분석하여 4개 문서 생성:

| 문서 | 내용 |
|------|------|
| `docs/project-brief.md` | 프로젝트 개요, 목표, 대상 사용자, 핵심 가치 |
| `docs/requirements.md` | 기능/비기능 요구사항, 기술 스택 제안 |
| `docs/mvp-scope.md` | MVP 포함/제외 기능, 성공 기준 |
| `docs/task-breakdown.md` | 개발 작업 목록, 우선순위, 예상 복잡도 |

---

## 5. 프로젝트 구조

```
idea-hub/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── idea.yml              # 아이디어 제출 폼
│   │   └── config.yml            # 빈 이슈 차단
│   └── workflows/
│       ├── on-idea-created.yml   # 생성 시 알림 + 라벨 전환
│       └── on-approve.yml        # 승인/거절 처리
├── docs/
│   └── PRD-v1.0.md               # 이 문서
├── scripts/
│   ├── init-project.sh           # 프로젝트 초기화
│   └── analyze-idea.sh           # Claude Code 분석
├── templates/
│   ├── web/                      # 웹 프로젝트 템플릿 (확장 예정)
│   ├── backend/                  # 백엔드 템플릿 (확장 예정)
│   ├── mobile/                   # 모바일 템플릿 (확장 예정)
│   └── monorepo/                 # 모노레포 템플릿 (확장 예정)
├── CLAUDE.md
└── README.md
```

---

## 6. 운영 흐름 (End-to-End)

```
1. 기획자: idea-hub에서 "New Issue" → 아이디어 양식 작성
                    ↓
2. 자동: intake 라벨 → needs-review 라벨 + 텔레그램 알림
                    ↓
3. 리뷰어: Issue 검토 → "/approve" 또는 "/reject" 댓글
                    ↓
4. 자동: approved 라벨 + 텔레그램 알림
                    ↓
5. 로컬: ./scripts/init-project.sh <issue_number>
         → repo 생성, 템플릿 적용, 초기 커밋
                    ↓
6. 로컬: ./scripts/analyze-idea.sh <issue_number>
         → Claude Code가 분석 문서 4종 생성
                    ↓
7. 로컬: cd ~/Documents/repository/projects/<slug>
         → claude  # Claude Code로 개발 시작
```

---

## 7. 사전 설정

### GitHub Secrets (idea-hub 레포)
| Secret | 설명 |
|--------|------|
| `TELEGRAM_BOT_TOKEN` | 텔레그램 봇 토큰 |
| `TELEGRAM_CHAT_ID` | 알림 받을 채팅 ID |

### GitHub Labels (수동 생성 필요)
- `intake` / `needs-review` / `approved` / `rejected` / `on-hold` / `building` / `done`

### 로컬 환경
- `gh` CLI 로그인 완료
- Claude Code CLI 설치 완료
- `~/Documents/repository/projects/` 디렉토리 존재

---

## 8. 정책

### 안전 정책
- 승인(`approved`) 전에는 레포 생성 불가
- 시크릿 자동 주입 금지 (수동 설정)
- destructive 작업은 수동 승인 필요

### 개발 정책
- 모든 개발은 Claude Code가 수행
- `CLAUDE.md` 필수
- `docs/requirements.md` 기준 개발
- conventional commits 형식

### 입력 정책
- Issue Form으로만 입력 (빈 이슈 차단)
- 필수 필드 강제
- 수정 가능, 히스토리 자동 유지 (GitHub)

---

## 9. MVP 범위

### 포함
- [x] Issue Form 기반 입력
- [x] 라벨 기반 상태 관리
- [x] `/approve`, `/reject` 명령어
- [x] 텔레그램 알림
- [x] 로컬 스크립트로 repo 생성
- [x] Claude Code 분석 문서 생성
- [x] 기본 템플릿 (공통)

### 미포함 (v2.0 확장)
- [ ] 플랫폼별 상세 템플릿 (web/backend/mobile)
- [ ] Issue → GitHub Project 자동 연결
- [ ] task-breakdown → 개별 Issue 자동 생성
- [ ] PR 자동 생성
- [ ] CI/CD 자동 연동
- [ ] 배포 자동화
- [ ] 웹 대시보드

---

## 10. 확장 계획 (v2.0+)

| 단계 | 기능 | 설명 |
|------|------|------|
| v1.1 | 플랫폼별 템플릿 | Next.js, FastAPI, Flutter 등 상세 템플릿 |
| v1.2 | GitHub Project 연동 | 칸반 보드 자동 생성 |
| v2.0 | 자동 Issue 분할 | task-breakdown → 개별 Issue 자동 생성 |
| v2.1 | PR 자동 생성 | Claude Code 작업 → PR 자동 생성 |
| v3.0 | CI/CD 연동 | 테스트/빌드/배포 자동화 |
