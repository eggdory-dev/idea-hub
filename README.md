# idea-hub

아이디어 인입 → 자동 개발 파이프라인 허브

## 사용법

### 1. 아이디어 제출
- [New Issue](../../issues/new/choose) → "아이디어 제출" 양식 작성

### 2. 리뷰 및 승인
- Issue에 `/approve` 댓글 → 승인
- Issue에 `/reject` 댓글 → 거절

### 3. 프로젝트 생성 (로컬)
```bash
./scripts/init-project.sh <issue_number>
```

### 4. 분석 문서 생성 (로컬)
```bash
./scripts/analyze-idea.sh <issue_number>
```

### 5. 개발 시작
```bash
cd ~/Documents/repository/projects/<project-slug>
claude
```

## 상태 흐름
```
intake → needs-review → approved → building → done
                     ↘ rejected / on-hold
```

## 문서
- [PRD v1.0](docs/PRD-v1.0.md)

## 사전 설정
1. GitHub Secrets: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`
2. GitHub Labels: `intake`, `needs-review`, `approved`, `rejected`, `on-hold`, `building`, `done`
3. 로컬: `gh` CLI 로그인, Claude Code CLI 설치
