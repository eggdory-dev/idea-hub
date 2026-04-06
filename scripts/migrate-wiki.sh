#!/bin/bash
# migrate-wiki.sh - 기존 프로젝트에 LLM Wiki 구조를 소급 적용
#
# 사용법: ./scripts/migrate-wiki.sh
#
# 동작:
#   1. ~/Documents/repository/projects/ 아래 각 프로젝트 순회
#   2. docs/index.md가 없는 프로젝트에 대해 Claude Code로 wiki 구조 생성
#   3. CLAUDE.md에 Wiki 유지보수 섹션 추가
#   4. commit & push

set -euo pipefail

PROJECTS_DIR="$HOME/Documents/repository/projects"

echo "================================================"
echo "📚 기존 프로젝트 Wiki 마이그레이션 시작"
echo "================================================"

if [ ! -d "$PROJECTS_DIR" ]; then
  echo "❌ 프로젝트 디렉토리를 찾을 수 없습니다: ${PROJECTS_DIR}"
  exit 1
fi

MIGRATED=0
SKIPPED=0

for PROJECT_DIR in "$PROJECTS_DIR"/*/; do
  [ ! -d "$PROJECT_DIR" ] && continue
  PROJECT_NAME=$(basename "$PROJECT_DIR")

  echo ""
  echo "--- ${PROJECT_NAME} ---"

  # 이미 wiki 구조가 있으면 스킵
  if [ -f "${PROJECT_DIR}docs/index.md" ]; then
    echo "  ⏭️ docs/index.md 이미 존재. 건너뜁니다."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # docs/ 디렉토리 존재 확인
  if [ ! -d "${PROJECT_DIR}docs" ]; then
    echo "  ⚠️ docs/ 디렉토리 없음. 건너뜁니다."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  cd "$PROJECT_DIR"

  echo "  Claude Code로 wiki 구조 생성 중..."
  echo "docs/ 디렉토리의 모든 .md 파일을 읽고 다음 작업을 수행해주세요:

1. docs/index.md 생성: 각 문서의 링크와 한 줄 요약이 포함된 카탈로그. 카테고리(원본, 분석, 설계 등)로 분류.
2. docs/log.md 생성: 프로젝트 초기화 및 분석 문서 생성 기록을 소급으로 작성 (날짜는 git log에서 추정).
3. CLAUDE.md에 아래 Wiki 유지보수 섹션이 없으면 추가:

## Wiki 유지보수 (docs/)

### 구조
- docs/idea-original.md — 원본 아이디어 (수정 금지, raw source)
- docs/index.md — 문서 목록 및 요약 (카탈로그)
- docs/log.md — 작업 기록 (시간순, append-only)
- docs/*.md — 분석/설계/결정 문서 (wiki pages)

### 규칙
1. 문서 생성/수정 시 → docs/index.md에 링크와 한 줄 요약 갱신
2. 의미 있는 작업 완료 시 → docs/log.md에 ## [YYYY-MM-DD] 카테고리 | 제목 형식으로 기록
3. 새로운 설계 결정, 기술 조사, 아키텍처 변경 시 → docs/에 별도 문서 작성 + index.md 갱신
4. idea-original.md는 절대 수정 금지
5. 주기적으로 wiki 점검: 오래된 정보, 누락 문서, 끊어진 참조 확인

완료 후 git commit -m 'docs: LLM Wiki 구조 추가 (index.md, log.md)' && git push 해주세요." \
    | claude -p --dangerously-skip-permissions --output-format text --max-turns 20 2>&1 | tail -5 || true

  echo "  ✅ ${PROJECT_NAME} 마이그레이션 완료"
  MIGRATED=$((MIGRATED + 1))
  cd "$HOME"
done

echo ""
echo "================================================"
echo "✅ 마이그레이션 완료!"
echo "  적용: ${MIGRATED}개 프로젝트"
echo "  스킵: ${SKIPPED}개 프로젝트"
echo "================================================"
