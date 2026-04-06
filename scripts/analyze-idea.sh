#!/bin/bash
# analyze-idea.sh - Claude Code로 아이디어 분석 문서 생성
#
# 사용법: ./scripts/analyze-idea.sh <issue_number>
#
# 동작:
#   1. Issue에서 아이디어 원문 읽기
#   2. Claude Code로 분석 문서 4종 생성
#   3. commit & push
#   4. Issue에 분석 완료 댓글

set -euo pipefail

ISSUE_NUMBER="${1:?Usage: ./scripts/analyze-idea.sh <issue_number>}"
REPO_OWNER="eggdory-dev"
HUB_REPO="${REPO_OWNER}/idea-hub"
PROJECTS_DIR="$HOME/Documents/repository/projects"

echo "================================================"
echo "📋 아이디어 분석 시작 - Issue #${ISSUE_NUMBER}"
echo "================================================"

# Issue 정보에서 repo 경로 찾기
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$HUB_REPO" --json title,body)
ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title' | sed 's/\[IDEA\] //')
SLUG=$(echo "$ISSUE_TITLE" | python3 -c "
import sys
title = sys.stdin.read().strip()
result = ''
for ch in title:
    if ch.isascii() and (ch.isalnum() or ch == '-'):
        result += ch.lower()
    elif ch == ' ':
        result += '-'
result = '-'.join(filter(None, result.split('-')))
print(result[:50] if result and result != '-' else '')
")

if [ -z "$SLUG" ]; then
    echo "  한글 제목이라 자동 slug 생성이 안 됩니다."
    echo -n "  레포 이름을 영문으로 입력해주세요: "
    read SLUG
fi
REPO_PATH="${PROJECTS_DIR}/${SLUG}"

if [ ! -d "$REPO_PATH" ]; then
    echo "❌ 프로젝트 디렉토리를 찾을 수 없습니다: ${REPO_PATH}"
    echo "먼저 init-project.sh를 실행하세요."
    exit 1
fi

cd "$REPO_PATH"

echo ""
echo "프로젝트 경로: ${REPO_PATH}"
echo "Claude Code로 분석 문서를 생성합니다..."
echo ""

# Claude Code CLI로 분석 실행
claude --print "
docs/idea-original.md 파일을 읽고, 다음 작업을 수행해주세요:

1. docs/project-brief.md - 프로젝트 개요, 목표, 대상 사용자, 핵심 가치
2. docs/requirements.md - 기능 요구사항 (필수/선택), 비기능 요구사항, 기술 스택 제안
3. docs/mvp-scope.md - MVP에 포함할 기능, 제외할 기능, 성공 기준
4. docs/task-breakdown.md - 개발 작업 목록 (우선순위별), 예상 복잡도
5. docs/index.md를 갱신하여 위 4개 문서의 링크와 한 줄 요약을 추가하세요.
6. docs/log.md에 분석 완료 기록을 추가하세요 (형식: ## [YYYY-MM-DD] analysis | 아이디어 분석 문서 생성)

각 문서는 한국어로 작성하고, 불명확한 항목은 ⚠️로 표시해주세요.
코드는 생성하지 마세요. 분석 문서만 작성해주세요.
" > /dev/null

echo ""
echo "✅ 분석 문서 생성 완료"

# commit & push
git add docs/
git commit --author="eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>" -m "docs: 아이디어 분석 문서 생성 (idea-hub #${ISSUE_NUMBER})

- project-brief.md
- requirements.md
- mvp-scope.md
- task-breakdown.md"

git push

# Issue 댓글
gh issue comment "$ISSUE_NUMBER" --repo "$HUB_REPO" --body "📋 **분석 문서 생성 완료**

Claude Code가 아이디어를 분석하여 다음 문서를 생성했습니다:
- \`docs/project-brief.md\` - 프로젝트 개요
- \`docs/requirements.md\` - 요구사항 정의
- \`docs/mvp-scope.md\` - MVP 범위
- \`docs/task-breakdown.md\` - 작업 분해

[레포에서 확인](https://github.com/${REPO_OWNER}/${SLUG}/tree/main/docs)"

echo ""
echo "================================================"
echo "✅ 분석 완료! 문서를 확인하세요:"
echo "  ${REPO_PATH}/docs/"
echo "================================================"
