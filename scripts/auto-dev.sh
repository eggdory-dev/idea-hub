#!/bin/bash
# auto-dev.sh - idea-hub 댓글을 감지하여 자동 개발을 수행하는 스케줄러
#
# 매 실행마다:
#   1. building 상태인 Issue 목록 조회
#   2. 각 Issue의 새 댓글 확인 (마지막 처리 이후)
#   3. 새 댓글이 있으면 해당 프로젝트에서 Claude Code 실행
#   4. 결과를 Issue 댓글로 보고
#
# 사용법:
#   ./scripts/auto-dev.sh          # 1회 실행
#   crontab에 등록하여 주기적 실행

set -euo pipefail

export TZ="Asia/Seoul"

REPO_OWNER="eggdory-dev"
HUB_REPO="${REPO_OWNER}/idea-hub"
PROJECTS_DIR="$HOME/Documents/repository/projects"
STATE_DIR="$HOME/.idea-hub-auto-dev"
LOG_FILE="${STATE_DIR}/auto-dev.log"
LOCK_FILE="${STATE_DIR}/auto-dev.lock"

# 상태 디렉토리 생성
mkdir -p "$STATE_DIR"

# 환경변수 로드
if [ -f "${STATE_DIR}/.env" ]; then
  set -a
  source "${STATE_DIR}/.env"
  set +a
fi

# 알림 설정 (Vercel 환경변수와 동일한 값 사용)
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# 로그 함수 (KST)
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S KST')] $*" | tee -a "$LOG_FILE"
}

# 알림 함수
send_notification() {
  local message="$1"

  # Discord
  if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    curl -s -o /dev/null -X POST "$DISCORD_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $(echo "$message" | jq -Rs .)}" 2>/dev/null || true
  fi

  # Telegram
  if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": $(echo "$message" | jq -Rs .)}" 2>/dev/null || true
  fi
}

# 잠금 확인 (중복 실행 방지)
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    log "이전 작업이 진행 중 (PID: $LOCK_PID). 건너뜁니다."
    exit 0
  fi
  rm -f "$LOCK_FILE"
fi

# 잠금 설정
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

log "========== 자동 개발 스캔 시작 =========="

# 0. approved 상태인 Issue 자동 초기화
APPROVED_ISSUES=$(gh issue list --repo "$HUB_REPO" --label "approved" --json number,title,body --jq '.[] | "\(.number)|\(.title)"' 2>/dev/null || echo "")

if [ -n "$APPROVED_ISSUES" ]; then
  log "approved 상태 아이디어 발견: $(echo "$APPROVED_ISSUES" | wc -l | tr -d ' ')개"

  while IFS='|' read -r A_NUMBER A_TITLE; do
    [ -z "$A_NUMBER" ] && continue
    log "--- [AUTO-INIT] Issue #${A_NUMBER}: ${A_TITLE} ---"

    # slug 생성 (영문만 추출, 없으면 issue-N)
    A_SLUG=$(echo "$A_TITLE" | python3 -c "
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
    if [ -z "$A_SLUG" ]; then
      A_SLUG="idea-${A_NUMBER}"
    fi

    A_REPO_PATH="${PROJECTS_DIR}/${A_SLUG}"

    # 이미 초기화된 경우 건너뛰기
    if gh repo view "${REPO_OWNER}/${A_SLUG}" &>/dev/null; then
      log "  레포 ${A_SLUG} 이미 존재. 라벨만 변경합니다."
      gh issue edit "$A_NUMBER" --repo "$HUB_REPO" --add-label "building" --remove-label "approved" 2>/dev/null || true
      continue
    fi

    # 레포 생성
    gh repo create "${A_SLUG}" --private --description "Auto-generated from idea-hub Issue #${A_NUMBER}: ${A_TITLE}" 2>/dev/null || true
    log "  레포 생성: ${REPO_OWNER}/${A_SLUG}"

    # Clone
    mkdir -p "$PROJECTS_DIR"
    if [ ! -d "$A_REPO_PATH" ]; then
      gh repo clone "${REPO_OWNER}/${A_SLUG}" "$A_REPO_PATH" 2>/dev/null || true
    fi

    if [ ! -d "$A_REPO_PATH" ]; then
      log "  클론 실패, 건너뜁니다."
      continue
    fi

    cd "$A_REPO_PATH"
    mkdir -p docs src tests

    # 기본 파일 생성
    cat > CLAUDE.md << 'INIT_EOF'
# CLAUDE.md

## 프로젝트 개요
이 프로젝트는 idea-hub에서 자동 생성되었습니다.

## 개발 규칙
- 한국어로 소통
- 커밋 메시지는 conventional commits 형식
- docs/requirements.md 기준으로 개발
- 테스트 코드 필수 작성
INIT_EOF

    cat > README.md << INIT_EOF
# ${A_TITLE}

> Auto-generated from [idea-hub Issue #${A_NUMBER}](https://github.com/${HUB_REPO}/issues/${A_NUMBER})

## 상태
🚧 개발 중
INIT_EOF

    cat > .gitignore << 'INIT_EOF'
node_modules/
.env
.env.local
*.log
.DS_Store
build/
dist/
.next/
INIT_EOF

    # 아이디어 원문 저장
    A_BODY=$(gh issue view "$A_NUMBER" --repo "$HUB_REPO" --json body --jq '.body' 2>/dev/null || echo "")
    cat > docs/idea-original.md << INIT_EOF
# 원본 아이디어

- **Issue**: [#${A_NUMBER}](https://github.com/${HUB_REPO}/issues/${A_NUMBER})
- **제목**: ${A_TITLE}
- **생성일**: $(date -u '+%Y-%m-%d')

---

${A_BODY}
INIT_EOF

    touch docs/project-brief.md docs/requirements.md docs/mvp-scope.md docs/task-breakdown.md

    git add -A
    git commit -m "feat: 프로젝트 초기화 (idea-hub #${A_NUMBER})" 2>/dev/null || true
    git push -u origin main 2>/dev/null || { git branch -M main && git push -u origin main 2>/dev/null; } || true

    # Issue 업데이트
    gh issue comment "$A_NUMBER" --repo "$HUB_REPO" --body "🚀 **레포지토리 자동 생성 완료**

- **Repo**: [${REPO_OWNER}/${A_SLUG}](https://github.com/${REPO_OWNER}/${A_SLUG})
- **로컬 경로**: \`${A_REPO_PATH}\`
- **생성 시각**: $(date -u '+%Y-%m-%d %H:%M UTC')

다음 단계: Claude Code로 분석 문서 생성 및 개발 시작

---
_자동 실행 by auto-dev.sh_" 2>/dev/null || true

    gh issue edit "$A_NUMBER" --repo "$HUB_REPO" --add-label "building" --remove-label "approved" 2>/dev/null || true

    # 분석 문서 생성 (Claude Code)
    log "  분석 문서 생성 중..."
    cd "$A_REPO_PATH"
    echo "docs/idea-original.md 파일을 읽고, 다음 4개 분석 문서를 생성해주세요:
1. docs/project-brief.md - 프로젝트 개요, 목표, 대상 사용자, 핵심 가치
2. docs/requirements.md - 기능 요구사항 (필수/선택), 비기능 요구사항, 기술 스택 제안
3. docs/mvp-scope.md - MVP에 포함할 기능, 제외할 기능, 성공 기준
4. docs/task-breakdown.md - 개발 작업 목록 (우선순위별), 예상 복잡도
완료 후 git commit & push 해주세요." | claude -p --dangerously-skip-permissions --output-format text --max-turns 30 2>&1 | tail -5 || true

    log "  Issue #${A_NUMBER} 초기화 완료: ${A_SLUG}"

    send_notification "🚀 자동 프로젝트 초기화 완료

아이디어: ${A_TITLE}
레포: ${REPO_OWNER}/${A_SLUG}
상태: approved → building

👉 https://web-iota-ashy-12.vercel.app/ideas/${A_NUMBER}"

    cd "$HOME"
  done <<< "$APPROVED_ISSUES"
fi

# 1. building 상태인 Issue 목록 조회
ISSUES=$(gh issue list --repo "$HUB_REPO" --label "building" --json number,title --jq '.[] | "\(.number)|\(.title)"' 2>/dev/null || echo "")

if [ -z "$ISSUES" ]; then
  log "building 상태인 아이디어가 없습니다."
  log "========== 자동 개발 스캔 완료 =========="
  exit 0
fi

log "building 상태 아이디어: $(echo "$ISSUES" | wc -l | tr -d ' ')개"

# 2. 각 Issue 처리
while IFS='|' read -r ISSUE_NUMBER ISSUE_TITLE; do
  [ -z "$ISSUE_NUMBER" ] && continue

  log "--- Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE} ---"

  # 마지막 처리 시각 확인
  LAST_CHECK_FILE="${STATE_DIR}/issue-${ISSUE_NUMBER}-last-check"
  LAST_CHECK=""
  if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE")
  fi

  # 댓글 조회
  # 자동 생성 댓글 제외: 상태 변경("상태로 변경됨"), 자동 개발 보고("🤖"), 프로젝트 초기화("프로젝트 초기화")
  COMMENTS_JSON=$(gh api "repos/${HUB_REPO}/issues/${ISSUE_NUMBER}/comments" \
    --jq '.[] | select(.body | test("상태로 변경됨") | not) | select(.body | test("🤖") | not) | select(.body | test("프로젝트 초기화") | not) | select(.body | test("개발 현황 리포트") | not) | "\(.id)|\(.created_at)|\(.user.login)|\(.body)"' \
    2>/dev/null || echo "")

  if [ -z "$COMMENTS_JSON" ]; then
    log "  댓글 없음, 건너뜁니다."
    continue
  fi

  # 새 댓글 필터링
  NEW_COMMENTS=""
  while IFS='|' read -r COMMENT_ID CREATED_AT AUTHOR BODY; do
    [ -z "$COMMENT_ID" ] && continue

    # 이미 처리한 댓글인지 확인
    PROCESSED_FILE="${STATE_DIR}/issue-${ISSUE_NUMBER}-processed"
    if [ -f "$PROCESSED_FILE" ] && grep -q "^${COMMENT_ID}$" "$PROCESSED_FILE" 2>/dev/null; then
      continue
    fi

    # 마지막 체크 이후 댓글인지 확인
    if [ -n "$LAST_CHECK" ]; then
      if [[ "$CREATED_AT" < "$LAST_CHECK" ]] || [[ "$CREATED_AT" == "$LAST_CHECK" ]]; then
        # 처리 완료 기록
        echo "$COMMENT_ID" >> "$PROCESSED_FILE"
        continue
      fi
    fi

    NEW_COMMENTS="${NEW_COMMENTS}${COMMENT_ID}|${CREATED_AT}|${AUTHOR}|${BODY}\n"
  done <<< "$COMMENTS_JSON"

  if [ -z "$NEW_COMMENTS" ]; then
    log "  새 댓글 없음."
    NOW_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "$NOW_UTC" > "$LAST_CHECK_FILE"
    log "  기준 시각 갱신: ${NOW_UTC} (KST: $(date '+%Y-%m-%d %H:%M:%S'))"
    continue
  fi

  # Issue 댓글에서 프로젝트 레포 추출 (eggdory-dev/xxx 패턴)
  ISSUE_COMMENTS_ALL=$(gh api "repos/${HUB_REPO}/issues/${ISSUE_NUMBER}/comments" --jq '.[].body' 2>/dev/null || echo "")
  PROJECT_SLUG=$(echo "$ISSUE_COMMENTS_ALL" | grep -o 'eggdory-dev/[a-z0-9-]*' | head -1 | sed 's/eggdory-dev\///' || echo "")

  if [ -z "$PROJECT_SLUG" ]; then
    log "  프로젝트 레포를 찾을 수 없습니다. 건너뜁니다."
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LAST_CHECK_FILE"
    continue
  fi

  PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_SLUG}"

  if [ ! -d "$PROJECT_DIR" ]; then
    log "  프로젝트 디렉토리 없음: ${PROJECT_DIR}, 건너뜁니다."
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LAST_CHECK_FILE"
    continue
  fi

  log "  프로젝트: ${PROJECT_SLUG} (${PROJECT_DIR})"

  # 새 댓글들을 하나의 프롬프트로 합치기
  PROMPT="idea-hub Issue #${ISSUE_NUMBER} (${ISSUE_TITLE})에 새로운 요청이 들어왔습니다.\n\n"
  PROCESSED_IDS=""

  while IFS='|' read -r COMMENT_ID CREATED_AT AUTHOR BODY; do
    [ -z "$COMMENT_ID" ] && continue
    PROMPT="${PROMPT}--- @${AUTHOR} (${CREATED_AT}) ---\n${BODY}\n\n"
    PROCESSED_IDS="${PROCESSED_IDS}${COMMENT_ID}\n"
  done <<< "$(echo -e "$NEW_COMMENTS")"

  # 새 댓글의 원본 본문에서 URL 추출 (GitHub API에서 직접)
  ALL_URLS=$(gh api "repos/${HUB_REPO}/issues/${ISSUE_NUMBER}/comments" \
    --jq "[.[] | select(.created_at > \"${LAST_CHECK}\") | select(.body | test(\"상태로 변경됨\") | not) | select(.body | test(\"🤖\") | not) | .body] | join(\" \")" \
    2>/dev/null | grep -oE 'https?://[^ )"]+' | sort -u || echo "")

  # URL 프리페치: 댓글에 포함된 URL 내용을 가져와서 프롬프트에 추가
  if [ -n "$ALL_URLS" ]; then
    PROMPT="${PROMPT}--- 참고 자료 (댓글에 포함된 URL 내용) ---\n\n"
    while IFS= read -r URL; do
      [ -z "$URL" ] && continue
      # URL 끝의 특수문자 정리
      URL=$(echo "$URL" | sed 's/[)>]*$//')
      log "  URL 프리페치: ${URL:0:80}..."
      # 페이지 내용 가져오기 (텍스트만, 최대 5000자, 10초 타임아웃)
      PAGE_CONTENT=$(curl -sL --max-time 10 -H "User-Agent: Mozilla/5.0" "$URL" 2>/dev/null \
        | sed 's/<script[^>]*>.*<\/script>//g' \
        | sed 's/<style[^>]*>.*<\/style>//g' \
        | sed 's/<[^>]*>//g' \
        | sed 's/&nbsp;/ /g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g' \
        | tr -s '[:space:]' ' ' \
        | head -c 5000 || echo "(내용을 가져올 수 없습니다)")
      PROMPT="${PROMPT}[URL: ${URL:0:100}]\n${PAGE_CONTENT}\n\n"
    done <<< "$ALL_URLS"
  fi

  PROMPT="${PROMPT}위 요청사항을 분석하고 구현해주세요. 참고 자료 URL의 내용을 레퍼런스로 활용하세요. 완료 후 git commit & push 해주세요."

  log "  Claude Code 실행 중..."

  # Claude Code 실행
  RESULT=$(cd "$PROJECT_DIR" && echo -e "$PROMPT" | claude -p --dangerously-skip-permissions --output-format text --max-turns 50 2>&1) || true

  # 결과 요약 (앞 2000자)
  RESULT_SUMMARY=$(echo "$RESULT" | tail -100 | head -c 2000)

  # Issue에 결과 댓글 작성
  REPORT_BODY="🤖 자동 개발 완료

**Issue**: #${ISSUE_NUMBER}
**프로젝트**: ${PROJECT_SLUG}

### 처리 결과
\`\`\`
${RESULT_SUMMARY}
\`\`\`

---
_자동 실행 by auto-dev.sh_"

  gh issue comment "$ISSUE_NUMBER" --repo "$HUB_REPO" --body "$REPORT_BODY" 2>/dev/null || true

  # 디스코드 + 텔레그램 알림
  NOTIFY_MSG="🤖 자동 개발 완료

아이디어: ${ISSUE_TITLE}
프로젝트: ${PROJECT_SLUG}
결과: ${RESULT_SUMMARY:0:500}

👉 https://web-iota-ashy-12.vercel.app/ideas/${ISSUE_NUMBER}"
  send_notification "$NOTIFY_MSG"

  log "  완료. 결과 댓글 + 알림 전송."

  # 처리 완료 기록
  PROCESSED_FILE="${STATE_DIR}/issue-${ISSUE_NUMBER}-processed"
  echo -e "$PROCESSED_IDS" >> "$PROCESSED_FILE"
  NOW_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "$NOW_UTC" > "$LAST_CHECK_FILE"
  log "  기준 시각 갱신: ${NOW_UTC} (KST: $(date '+%Y-%m-%d %H:%M:%S'))"

done <<< "$ISSUES"

log "========== 자동 개발 스캔 완료 =========="
