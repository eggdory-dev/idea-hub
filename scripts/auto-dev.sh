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

# 로그 함수 (KST)
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S KST')] $*" | tee -a "$LOG_FILE"
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

# 1. building 상태인 Issue 목록 조회
ISSUES=$(gh issue list --repo "$HUB_REPO" --label "building" --json number,title --jq '.[] | "\(.number)|\(.title)"' 2>/dev/null || echo "")

if [ -z "$ISSUES" ]; then
  log "building 상태인 아이디어가 없습니다."
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

  PROMPT="${PROMPT}위 요청사항을 분석하고 구현해주세요. 완료 후 git commit & push 해주세요."

  log "  Claude Code 실행 중..."

  # Claude Code 실행
  RESULT=$(cd "$PROJECT_DIR" && echo -e "$PROMPT" | claude --print --dangerously-skip-permissions 2>&1) || true

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

  log "  완료. 결과 댓글 작성."

  # 처리 완료 기록
  PROCESSED_FILE="${STATE_DIR}/issue-${ISSUE_NUMBER}-processed"
  echo -e "$PROCESSED_IDS" >> "$PROCESSED_FILE"
  NOW_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "$NOW_UTC" > "$LAST_CHECK_FILE"
  log "  기준 시각 갱신: ${NOW_UTC} (KST: $(date '+%Y-%m-%d %H:%M:%S'))"

done <<< "$ISSUES"

log "========== 자동 개발 스캔 완료 =========="
