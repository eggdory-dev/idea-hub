# CLAUDE.md

## 프로젝트 개요
idea-hub는 아이디어 인입 → 자동 개발 파이프라인의 중앙 허브 레포입니다.

## 구조
- `.github/ISSUE_TEMPLATE/` - 아이디어 제출 양식
- `.github/workflows/` - GitHub Actions 자동화
- `scripts/` - 로컬 실행 스크립트
- `templates/` - 프로젝트 템플릿 (확장 예정)
- `docs/` - PRD 및 문서

## 규칙
- 한국어로 소통
- 이 레포는 코드 개발용이 아닌 파이프라인 관리용
- 실제 개발은 개별 프로젝트 레포에서 수행
- conventional commits 형식
- 프로젝트 레포는 `eggdory-dev` 계정에 생성 (예: `eggdory-dev/<slug>`)
- 커밋 author는 반드시 `eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>`으로 설정 (Vercel 배포 차단 방지)

## 프로젝트 Wiki 패턴
- 개별 프로젝트 레포의 docs/ 디렉토리는 LLM Wiki로 운영
- 패턴 설명: docs/llm-wiki.md 참조
- 템플릿: scripts/init-project.sh에서 관리
