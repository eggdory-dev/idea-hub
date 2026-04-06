#!/bin/bash
# auto-dev.sh - idea-hub 댓글을 감지하여 자동 개발을 수행하는 스케줄러
#
# 매 실행마다:
#   1. building 상태인 Issue 목록 조회
#   2. 각 Issue의 새 댓글 확인 (마지막 처리 이후)
#   3. 새 댓글이 있으면 해당 프로젝트에서 Claude Code 실행
#   4. 결과를 Issue 댓글로 보고
#   5. 매 실행마다 알림 발송
#
# 사용법:
#   ./scripts/auto-dev.sh          # 1회 실행
#   LaunchAgent로 주기적 실행

set -euo pipefail

export TZ="Asia/Seoul"
export PATH="/opt/homebrew/bin:/opt/anaconda3/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

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

# 알림 설정
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
      -d "{\"content\": $(printf '%s' "$message" | jq -Rs .)}" 2>/dev/null || true
  fi

  # Telegram
  if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -s -o /dev/null -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": $(printf '%s' "$message" | jq -Rs .)}" 2>/dev/null || true
  fi
}

# timeout 대체 함수 (macOS 호환)
run_with_timeout() {
  local timeout_secs="$1"
  shift
  "$@" &
  local pid=$!
  ( sleep "$timeout_secs" && kill "$pid" 2>/dev/null ) &
  local watchdog=$!
  wait "$pid" 2>/dev/null
  local exit_code=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return $exit_code
}

# 잠금 확인 (중복 실행 방지)
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    log "이전 작업이 진행 중 (PID: $LOCK_PID). 건너뜁니다."
    send_notification "⏭️ 자동 개발 스캔 건너뜀

사유: 이전 작업 진행 중 (PID: $LOCK_PID)
시각: $(date '+%Y-%m-%d %H:%M KST')"
    exit 0
  fi
  rm -f "$LOCK_FILE"
fi

# 잠금 설정
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

log "========== 자동 개발 스캔 시작 =========="

# 스캔 결과 수집용
SCAN_SUMMARY=""
ACTIONS_TAKEN=0

# 0. approved 상태인 Issue 자동 초기화
APPROVED_ISSUES=$(gh issue list --repo "$HUB_REPO" --label "approved" --json number,title --jq '.[] | @json' 2>/dev/null || echo "")

if [ -n "$APPROVED_ISSUES" ]; then
  APPROVED_COUNT=$(echo "$APPROVED_ISSUES" | wc -l | tr -d ' ')
  log "approved 상태 아이디어 발견: ${APPROVED_COUNT}개"
  SCAN_SUMMARY="${SCAN_SUMMARY}🆕 approved ${APPROVED_COUNT}개 발견\n"

  while IFS= read -r ISSUE_LINE; do
    [ -z "$ISSUE_LINE" ] && continue
    A_NUMBER=$(echo "$ISSUE_LINE" | jq -r '.number')
    A_TITLE=$(echo "$ISSUE_LINE" | jq -r '.title')
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
      SCAN_SUMMARY="${SCAN_SUMMARY}  - #${A_NUMBER} ${A_SLUG}: 라벨 변경 (이미 존재)\n"
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
      SCAN_SUMMARY="${SCAN_SUMMARY}  - #${A_NUMBER} ${A_SLUG}: 클론 실패\n"
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
- 커밋 시 반드시 --author='eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>' 사용
- docs/requirements.md 기준으로 개발
- 테스트 코드 필수 작성

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

    # Wiki 초기 파일 생성
    cat > docs/index.md << 'WIKI_INDEX_EOF'
# 문서 목록

## 원본
- [idea-original.md](idea-original.md) — 원본 아이디어

## 분석
- [project-brief.md](project-brief.md) — 프로젝트 개요
- [requirements.md](requirements.md) — 요구사항 정의
- [mvp-scope.md](mvp-scope.md) — MVP 범위
- [task-breakdown.md](task-breakdown.md) — 작업 분해
WIKI_INDEX_EOF

    cat > docs/log.md << WIKI_LOG_EOF
# 작업 기록

## [$(date -u '+%Y-%m-%d')] init | 프로젝트 초기화
- idea-hub Issue #${A_NUMBER}에서 자동 생성
- 기본 템플릿 적용
WIKI_LOG_EOF

    git add -A
    git commit --author="eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>" -m "feat: 프로젝트 초기화 (idea-hub #${A_NUMBER})" 2>/dev/null || true
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

    # 분석 문서 생성 (Claude Code) - 30분 타임아웃
    log "  분석 문서 생성 중..."
    cd "$A_REPO_PATH"
    CLAUDE_PROMPT="docs/idea-original.md 파일을 읽고, 다음 4개 분석 문서를 생성해주세요:
1. docs/project-brief.md - 프로젝트 개요, 목표, 대상 사용자, 핵심 가치
2. docs/requirements.md - 기능 요구사항 (필수/선택), 비기능 요구사항, 기술 스택 제안
3. docs/mvp-scope.md - MVP에 포함할 기능, 제외할 기능, 성공 기준
4. docs/task-breakdown.md - 개발 작업 목록 (우선순위별), 예상 복잡도
5. docs/index.md를 갱신하여 위 4개 문서의 링크와 한 줄 요약을 추가하세요.
6. docs/log.md에 분석 완료 기록을 추가하세요 (형식: ## [YYYY-MM-DD] analysis | 아이디어 분석 문서 생성)
각 문서는 한국어로 작성하고, 불명확한 항목은 ⚠️로 표시해주세요.
완료 후 git commit --author='eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>' & push 해주세요."
    echo "$CLAUDE_PROMPT" | claude -p --dangerously-skip-permissions --output-format text --max-turns 30 2>&1 | tail -5 || true

    log "  Issue #${A_NUMBER} 초기화 완료: ${A_SLUG}"
    SCAN_SUMMARY="${SCAN_SUMMARY}  - #${A_NUMBER} ${A_SLUG}: 초기화 완료\n"
    ACTIONS_TAKEN=$((ACTIONS_TAKEN + 1))

    send_notification "🚀 자동 프로젝트 초기화 완료

아이디어: ${A_TITLE}
레포: ${REPO_OWNER}/${A_SLUG}
상태: approved → building"

    cd "$HOME"
  done <<< "$APPROVED_ISSUES"
fi

# 1. building 상태인 Issue 목록 조회
BUILDING_JSON=$(gh issue list --repo "$HUB_REPO" --label "building" --json number,title --jq '.[] | @json' 2>/dev/null || echo "")

if [ -z "$BUILDING_JSON" ]; then
  log "building 상태인 아이디어가 없습니다."
  SCAN_SUMMARY="${SCAN_SUMMARY}📦 building 상태 아이디어: 0개"
  send_notification "📊 자동 개발 스캔 완료 — $(date '+%m/%d %H:%M KST')

$(echo -e "$SCAN_SUMMARY")

결과: 처리할 아이디어 없음"
  log "========== 자동 개발 스캔 완료 =========="
  exit 0
fi

BUILDING_COUNT=$(echo "$BUILDING_JSON" | wc -l | tr -d ' ')
log "building 상태 아이디어: ${BUILDING_COUNT}개"
SCAN_SUMMARY="${SCAN_SUMMARY}📦 building ${BUILDING_COUNT}개 감시 중\n"

# 2. 각 Issue 처리
while IFS= read -r ISSUE_LINE; do
  [ -z "$ISSUE_LINE" ] && continue
  ISSUE_NUMBER=$(echo "$ISSUE_LINE" | jq -r '.number')
  ISSUE_TITLE=$(echo "$ISSUE_LINE" | jq -r '.title')
  [ -z "$ISSUE_NUMBER" ] && continue

  log "--- Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE} ---"

  # 마지막 처리 시각 확인
  LAST_CHECK_FILE="${STATE_DIR}/issue-${ISSUE_NUMBER}-last-check"
  LAST_CHECK=""
  if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE")
  fi

  # 댓글을 JSON 배열로 조회 (파이프 구분자 사용하지 않음)
  # 자동 생성 댓글 제외: "자동 실행 by auto-dev.sh" 포함 댓글만 정확히 제외
  COMMENTS_TEMP="${STATE_DIR}/comments-${ISSUE_NUMBER}.json"
  gh api "repos/${HUB_REPO}/issues/${ISSUE_NUMBER}/comments" \
    --jq '[.[] | select(
      (.body | test("_자동 실행 by auto-dev\\.sh_") | not) and
      (.body | test("^✅ 승인 상태로 변경됨") | not) and
      (.body | test("^🚀 \\*\\*레포지토리") | not) and
      (.body | test("^🤖") | not) and
      (.body | test("개발 현황 리포트") | not)
    ) | {id: .id, created_at: .created_at, login: .user.login, body: .body}]' \
    > "$COMMENTS_TEMP" 2>/dev/null || echo "[]" > "$COMMENTS_TEMP"

  COMMENT_COUNT=$(jq 'length' "$COMMENTS_TEMP" 2>/dev/null || echo "0")

  if [ "$COMMENT_COUNT" -eq 0 ]; then
    log "  사용자 댓글 없음, 건너뜁니다."
    SCAN_SUMMARY="${SCAN_SUMMARY}  - #${ISSUE_NUMBER}: 댓글 없음\n"
    NOW_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "$NOW_UTC" > "$LAST_CHECK_FILE"
    rm -f "$COMMENTS_TEMP"
    continue
  fi

  # 새 댓글 필터링 (processed 파일 + 시각 기반)
  PROCESSED_FILE="${STATE_DIR}/issue-${ISSUE_NUMBER}-processed"
  touch "$PROCESSED_FILE"

  # processed 파일 정리: 숫자만 남기기 (오염된 데이터 제거)
  if [ -f "$PROCESSED_FILE" ]; then
    grep -E '^[0-9]+$' "$PROCESSED_FILE" 2>/dev/null | sort -u > "${PROCESSED_FILE}.clean"
    mv "${PROCESSED_FILE}.clean" "$PROCESSED_FILE"
  fi

  # processed IDs를 JSON 배열로 변환
  PROCESSED_JSON=$(jq -Rs '[split("\n") | .[] | select(length > 0) | tonumber] // []' "$PROCESSED_FILE" 2>/dev/null || echo "[]")

  NEW_COMMENTS_JSON=$(jq --arg last_check "$LAST_CHECK" --argjson processed "$PROCESSED_JSON" '
    [.[] | select(
      (.id as $id | $processed | map(. == $id) | any | not) and
      (if $last_check == "" then true else .created_at > $last_check end)
    )]
  ' "$COMMENTS_TEMP" 2>/dev/null || echo "[]")

  NEW_COUNT=$(echo "$NEW_COMMENTS_JSON" | jq 'length' 2>/dev/null || echo "0")

  if [ "$NEW_COUNT" -eq 0 ]; then
    log "  새 댓글 없음."
    SCAN_SUMMARY="${SCAN_SUMMARY}  - #${ISSUE_NUMBER}: 새 댓글 없음\n"
    NOW_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "$NOW_UTC" > "$LAST_CHECK_FILE"
    rm -f "$COMMENTS_TEMP"
    continue
  fi

  log "  새 댓글 ${NEW_COUNT}개 발견!"

  # Issue 댓글에서 프로젝트 레포 추출 (eggdory-dev/xxx 패턴)
  PROJECT_SLUG=$(gh api "repos/${HUB_REPO}/issues/${ISSUE_NUMBER}/comments" \
    --jq '[.[].body] | join(" ")' 2>/dev/null \
    | grep -o 'eggdory-dev/[a-z0-9-]*' | head -1 | sed 's/eggdory-dev\///' || echo "")

  if [ -z "$PROJECT_SLUG" ]; then
    log "  프로젝트 레포를 찾을 수 없습니다. 건너뜁니다."
    SCAN_SUMMARY="${SCAN_SUMMARY}  - #${ISSUE_NUMBER}: 레포 못 찾음\n"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LAST_CHECK_FILE"
    rm -f "$COMMENTS_TEMP"
    continue
  fi

  PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_SLUG}"

  if [ ! -d "$PROJECT_DIR" ]; then
    log "  프로젝트 디렉토리 없음: ${PROJECT_DIR}, 건너뜁니다."
    SCAN_SUMMARY="${SCAN_SUMMARY}  - #${ISSUE_NUMBER} ${PROJECT_SLUG}: 디렉토리 없음\n"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LAST_CHECK_FILE"
    rm -f "$COMMENTS_TEMP"
    continue
  fi

  log "  프로젝트: ${PROJECT_SLUG} (${PROJECT_DIR})"

  # 새 댓글들을 하나의 프롬프트로 합치기
  PROMPT="idea-hub Issue #${ISSUE_NUMBER} (${ISSUE_TITLE})에 새로운 요청이 들어왔습니다.\n\n"

  for i in $(seq 0 $((NEW_COUNT - 1))); do
    C_AUTHOR=$(echo "$NEW_COMMENTS_JSON" | jq -r ".[$i].login")
    C_DATE=$(echo "$NEW_COMMENTS_JSON" | jq -r ".[$i].created_at")
    C_BODY=$(echo "$NEW_COMMENTS_JSON" | jq -r ".[$i].body")
    PROMPT="${PROMPT}--- @${C_AUTHOR} (${C_DATE}) ---\n${C_BODY}\n\n"
  done

  # 새 댓글의 본문에서 URL 추출
  ALL_URLS=$(echo "$NEW_COMMENTS_JSON" | jq -r '.[].body' 2>/dev/null \
    | grep -oE 'https?://[^ )"]+' | sed 's/[)>]*$//' | sort -u || echo "")

  # URL 프리페치: 댓글에 포함된 URL 내용을 가져와서 프롬프트에 추가
  if [ -n "$ALL_URLS" ]; then
    PROMPT="${PROMPT}--- 참고 자료 (댓글에 포함된 URL 내용) ---\n\n"
    while IFS= read -r URL; do
      [ -z "$URL" ] && continue
      log "  URL 프리페치: ${URL:0:80}..."
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

  PROMPT="${PROMPT}위 요청사항을 분석하고 구현해주세요. 참고 자료 URL의 내용을 레퍼런스로 활용하세요. 완료 후 git commit --author='eggdory-dev <229576826+eggdory-dev@users.noreply.github.com>' & push 해주세요."

  log "  Claude Code 실행 중... (최대 30분)"

  # Claude Code 실행 (--max-turns로 제한, 별도 프로세스로 타임아웃)
  RESULT_FILE="${STATE_DIR}/claude-result-${ISSUE_NUMBER}.txt"
  cd "$PROJECT_DIR"
  (echo -e "$PROMPT" | claude -p --dangerously-skip-permissions --output-format text --max-turns 50 > "$RESULT_FILE" 2>&1) &
  CLAUDE_PID=$!
  ( sleep 1800 && kill "$CLAUDE_PID" 2>/dev/null && echo "[TIMEOUT] Claude Code 30분 타임아웃" >> "$RESULT_FILE" ) &
  WATCHDOG_PID=$!
  wait "$CLAUDE_PID" 2>/dev/null || true
  kill "$WATCHDOG_PID" 2>/dev/null
  wait "$WATCHDOG_PID" 2>/dev/null || true
  cd "$HOME"

  RESULT=$(cat "$RESULT_FILE" 2>/dev/null || echo "(결과 없음)")
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

  log "  완료. 결과 댓글 + 알림 전송."
  SCAN_SUMMARY="${SCAN_SUMMARY}  - #${ISSUE_NUMBER} ${PROJECT_SLUG}: 댓글 ${NEW_COUNT}개 처리 완료\n"
  ACTIONS_TAKEN=$((ACTIONS_TAKEN + 1))

  # 개별 알림 (개발 완료 시)
  send_notification "🤖 자동 개발 완료

아이디어: ${ISSUE_TITLE}
프로젝트: ${PROJECT_SLUG}
새 댓글: ${NEW_COUNT}개
결과: ${RESULT_SUMMARY:0:500}"

  # 처리 완료 기록 (ID만 정확히 기록)
  echo "$NEW_COMMENTS_JSON" | jq -r '.[].id' >> "$PROCESSED_FILE"
  NOW_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "$NOW_UTC" > "$LAST_CHECK_FILE"
  log "  기준 시각 갱신: ${NOW_UTC} (KST: $(date '+%Y-%m-%d %H:%M:%S'))"

  rm -f "$COMMENTS_TEMP" "$RESULT_FILE"

done <<< "$BUILDING_JSON"

log "========== 자동 개발 스캔 완료 =========="

# 매 실행마다 요약 알림 발송
if [ "$ACTIONS_TAKEN" -eq 0 ]; then
  STATUS_EMOJI="😴"
  STATUS_TEXT="새 작업 없음"
else
  STATUS_EMOJI="✅"
  STATUS_TEXT="${ACTIONS_TAKEN}건 처리"
fi

FINAL_SUMMARY=$(printf '%s' "$SCAN_SUMMARY" | sed 's/\\n/\n/g')
send_notification "${STATUS_EMOJI} 자동 개발 스캔 완료 — $(date '+%m/%d %H:%M KST')

${FINAL_SUMMARY}
결과: ${STATUS_TEXT}"
