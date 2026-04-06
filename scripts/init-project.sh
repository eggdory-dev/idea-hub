#!/bin/bash
# init-project.sh - 승인된 아이디어의 레포 생성 및 개발 초기화
#
# 사용법: ./scripts/init-project.sh <issue_number>
#
# 동작:
#   1. Issue에서 아이디어 정보 추출
#   2. slug 기반 repo 생성 (private)
#   3. 플랫폼별 템플릿 적용
#   4. docs/ 에 분석 문서 생성
#   5. 초기 commit & push
#   6. Issue에 repo 링크 댓글
#   7. building 라벨 추가

set -euo pipefail

ISSUE_NUMBER="${1:?Usage: ./scripts/init-project.sh <issue_number>}"
REPO_OWNER="eggdory-dev"
HUB_REPO="${REPO_OWNER}/idea-hub"
PROJECTS_DIR="$HOME/Documents/repository/projects"

echo "================================================"
echo "🚀 프로젝트 초기화 시작 - Issue #${ISSUE_NUMBER}"
echo "================================================"

# 1. Issue 정보 추출
echo ""
echo "[1/7] Issue 정보 추출..."
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$HUB_REPO" --json title,body,labels)
ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title' | sed 's/\[IDEA\] //')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body')

# 라벨 확인 (approved인지)
IS_APPROVED=$(echo "$ISSUE_JSON" | jq -r '.labels[].name' | grep -c "approved" || true)
if [ "$IS_APPROVED" -eq 0 ]; then
    echo "❌ 에러: Issue #${ISSUE_NUMBER}은 아직 승인되지 않았습니다."
    exit 1
fi

echo "  제목: ${ISSUE_TITLE}"

# 2. slug 생성 및 repo 생성
echo ""
echo "[2/7] 레포지토리 생성..."
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
# 영문이 없으면 사용자에게 slug 입력 요청
print(result[:50] if result and result != '-' else '')
")

if [ -z "$SLUG" ]; then
    echo "  한글 제목이라 자동 slug 생성이 안 됩니다."
    echo -n "  레포 이름을 영문으로 입력해주세요: "
    read SLUG
fi
REPO_NAME="${SLUG}"

# repo 존재 여부 확인
if gh repo view "${REPO_OWNER}/${REPO_NAME}" &>/dev/null; then
    echo "  ⚠️ 레포 ${REPO_NAME} 이미 존재합니다. 기존 레포를 사용합니다."
else
    gh repo create "${REPO_NAME}" --private --description "Auto-generated from idea-hub Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}"
    echo "  ✅ 레포 생성: ${REPO_OWNER}/${REPO_NAME}"
fi

# 3. Clone
echo ""
echo "[3/7] Clone..."
mkdir -p "$PROJECTS_DIR"
REPO_PATH="${PROJECTS_DIR}/${REPO_NAME}"

if [ -d "$REPO_PATH" ]; then
    echo "  ⚠️ 이미 클론되어 있습니다: ${REPO_PATH}"
else
    gh repo clone "${REPO_OWNER}/${REPO_NAME}" "$REPO_PATH"
    echo "  ✅ Clone 완료: ${REPO_PATH}"
fi

cd "$REPO_PATH"

# 4. 플랫폼 감지 및 템플릿 적용
echo ""
echo "[4/7] 템플릿 적용..."
PLATFORM=$(echo "$ISSUE_BODY" | grep -oP '(?<=플랫폼\n\n).*' | head -1 || echo "Web")
echo "  플랫폼: ${PLATFORM}"

# 기본 구조 생성
mkdir -p docs src tests

# CLAUDE.md 생성
cat > CLAUDE.md << 'CLAUDE_EOF'
# CLAUDE.md

## 프로젝트 개요
이 프로젝트는 idea-hub에서 자동 생성되었습니다.

## 개발 규칙
- 한국어로 소통
- 커밋 메시지는 conventional commits 형식
- 커밋 시 반드시 --author='eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>' 사용
- docs/requirements.md 기준으로 개발
- 테스트 코드 필수 작성
- PR 단위로 작업

## 핵심 명령어
- 개발 관련 명령어는 프로젝트 세팅 후 추가

## Wiki 유지보수 (docs/)

### 구조
- `docs/idea-original.md` — 원본 아이디어 (수정 금지, raw source)
- `docs/index.md` — 문서 목록 및 요약 (카탈로그)
- `docs/log.md` — 작업 기록 (시간순, append-only)
- `docs/*.md` — 분석/설계/결정 문서 (wiki pages)

### 규칙
1. 문서 생성/수정 시 → docs/index.md에 링크와 한 줄 요약 갱신
2. 의미 있는 작업 완료 시 → docs/log.md에 `## [YYYY-MM-DD] 카테고리 | 제목` 형식으로 기록
3. 새로운 설계 결정, 기술 조사, 아키텍처 변경 시 → docs/에 별도 문서 작성 + index.md 갱신
4. idea-original.md는 절대 수정 금지
5. 주기적으로 wiki 점검: 오래된 정보, 누락 문서, 끊어진 참조 확인
CLAUDE_EOF

# README.md 생성
cat > README.md << EOF
# ${ISSUE_TITLE}

> Auto-generated from [idea-hub Issue #${ISSUE_NUMBER}](https://github.com/${HUB_REPO}/issues/${ISSUE_NUMBER})

## 상태
🚧 개발 중

## 문서
- [요구사항](docs/requirements.md)
- [프로젝트 브리프](docs/project-brief.md)
- [MVP 범위](docs/mvp-scope.md)
- [작업 분해](docs/task-breakdown.md)
EOF

# .gitignore 생성
cat > .gitignore << 'GITIGNORE_EOF'
node_modules/
.env
.env.local
*.log
.DS_Store
build/
dist/
__pycache__/
*.pyc
.vscode/
.idea/
GITIGNORE_EOF

echo "  ✅ 기본 템플릿 적용 완료"

# 5. 아이디어 원문 저장
echo ""
echo "[5/7] 아이디어 문서 저장..."
cat > docs/idea-original.md << EOF
# 원본 아이디어

- **Issue**: [#${ISSUE_NUMBER}](https://github.com/${HUB_REPO}/issues/${ISSUE_NUMBER})
- **제목**: ${ISSUE_TITLE}
- **생성일**: $(date -u '+%Y-%m-%d')

---

${ISSUE_BODY}
EOF

# 빈 분석 문서 자리잡기
touch docs/project-brief.md
touch docs/requirements.md
touch docs/mvp-scope.md
touch docs/task-breakdown.md

# Wiki 초기 파일 생성
cat > docs/index.md << 'INDEX_EOF'
# 문서 목록

## 원본
- [idea-original.md](idea-original.md) — 원본 아이디어

## 분석
- [project-brief.md](project-brief.md) — 프로젝트 개요
- [requirements.md](requirements.md) — 요구사항 정의
- [mvp-scope.md](mvp-scope.md) — MVP 범위
- [task-breakdown.md](task-breakdown.md) — 작업 분해
INDEX_EOF

cat > docs/log.md << EOF
# 작업 기록

## [$(date -u '+%Y-%m-%d')] init | 프로젝트 초기화
- idea-hub Issue #${ISSUE_NUMBER}에서 자동 생성
- 기본 템플릿 적용
EOF

echo "  ✅ 문서 저장 완료"

# 6. 초기 commit & push
echo ""
echo "[6/7] 초기 커밋 및 푸시..."
git add -A
git commit --author="eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>" -m "feat: 프로젝트 초기화 (idea-hub #${ISSUE_NUMBER})

- CLAUDE.md, README.md, .gitignore 생성
- docs/ 디렉토리 구조 생성
- 아이디어 원문 저장

Source: https://github.com/${HUB_REPO}/issues/${ISSUE_NUMBER}"

git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null || {
    git branch -M main
    git push -u origin main
}
echo "  ✅ 푸시 완료"

# 7. Issue 업데이트
echo ""
echo "[7/7] Issue 업데이트..."
gh issue comment "$ISSUE_NUMBER" --repo "$HUB_REPO" --body "🚀 **레포지토리 생성 완료**

- **Repo**: [${REPO_OWNER}/${REPO_NAME}](https://github.com/${REPO_OWNER}/${REPO_NAME})
- **로컬 경로**: \`${REPO_PATH}\`
- **생성 시각**: $(date -u '+%Y-%m-%d %H:%M UTC')

다음 단계: Claude Code로 분석 문서 생성 및 개발 시작"

gh issue edit "$ISSUE_NUMBER" --repo "$HUB_REPO" \
    --add-label "building" \
    --remove-label "approved"

echo ""
echo "================================================"
echo "✅ 프로젝트 초기화 완료!"
echo "  Repo: https://github.com/${REPO_OWNER}/${REPO_NAME}"
echo "  경로: ${REPO_PATH}"
echo ""
echo "다음 단계:"
echo "  cd ${REPO_PATH}"
echo "  claude  # Claude Code로 개발 시작"
echo "================================================"
