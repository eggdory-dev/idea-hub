# Webhook 기반 즉시 자동 개발 트리거 — Design

> 작성일: 2026-06-09
> 목적: 기존 1시간 launchd 폴링 방식을 **GitHub 댓글 이벤트 즉시 트리거**로 보강

## 1. 배경

`scripts/auto-dev.sh`는 매 1시간마다 launchd로 깨어나 `building` 라벨 이슈의 새 댓글을 폴링한다. 사용자 입력 → 개발 시작 지연이 최대 1시간이고, 매 실행마다 Discord/Telegram 알림이 발송돼 노이즈가 크다. 댓글이 달리면 **수 초 안에** 처리되도록 이벤트 기반 트리거를 추가한다.

## 2. 아키텍처

```
GitHub (issue_comment.created)
  │  POST + HMAC-SHA256 signature
  ▼
Tailscale Funnel
  https://macbook-pro-7.tailee025e.ts.net/webhook   (공용 HTTPS, 고정)
  │  내부 라우팅 (tailscaled → loopback)
  ▼
Python webhook receiver  (127.0.0.1:9090)
  │  - HMAC 검증
  │  - issue_comment.created 만 통과
  │  - building 라벨 이슈만 통과
  │  - 봇 자동 댓글 패턴 필터링
  │  - 즉시 200 응답 + 백그라운드로 auto-dev.sh 실행
  ▼
scripts/auto-dev.sh  (기존 그대로)
  - LOCK_FILE 로 중복 실행 차단
  - PROCESSED_FILE 로 중복 댓글 처리 차단

[안전망]
launchd com.ideahub.autodev: 6시간 주기 폴링 (기존 1시간 → 21600s)
```

## 3. 컴포넌트

### 3.1 신규: `scripts/webhook-receiver.py`

- Python 3 stdlib만 사용 (`http.server`, `hmac`, `json`, `subprocess`, `logging`)
- 의존성 0
- 포트 9090, loopback 바인딩 (외부 노출은 Tailscale Funnel만 통해)
- 엔드포인트:
  - `POST /webhook` — GitHub 이벤트 수신
  - `GET /healthz` — 헬스체크
- 로그: `~/.idea-hub-auto-dev/webhook.log`

처리 흐름:
1. `X-Hub-Signature-256` 헤더에서 HMAC-SHA256 추출 → `GITHUB_WEBHOOK_SECRET`와 비교 (`hmac.compare_digest`)
2. `X-GitHub-Event` 헤더 검사 — `issue_comment`가 아니면 204
3. payload `action == "created"` 아니면 204
4. payload `issue.labels[*].name`에 `building` 없으면 204
5. payload `comment.body`가 봇 자동 패턴(`🤖`, `🚀 **레포지토리`, `_자동 실행 by auto-dev.sh_` 등)이면 204
6. 통과 → `subprocess.Popen([auto-dev.sh], start_new_session=True)` 백그라운드 실행
7. 즉시 `200 OK` + JSON `{"queued": true, "issue": N}`

### 3.2 신규: `~/Library/LaunchAgents/com.ideahub.webhook.plist`

- `RunAtLoad: true`
- `KeepAlive: true` — 죽으면 즉시 재시작
- StandardOutPath/StandardErrorPath: `~/.idea-hub-auto-dev/webhook-launchd-{out,err}.log`
- 환경변수: `GITHUB_WEBHOOK_SECRET` 등은 receiver 안에서 `.env` 로드

### 3.3 수정: `~/Library/LaunchAgents/com.ideahub.autodev.plist`

- `StartInterval: 3600 → 21600` (1h → 6h)
- 안전망 역할만 수행 (맥 슬립 / Tailscale 다운 / webhook 누락 케이스 캐치)

### 3.4 수정: `~/.idea-hub-auto-dev/.env`

다음 한 줄 추가:
```
GITHUB_WEBHOOK_SECRET=<32바이트 랜덤 hex>
```

### 3.5 GitHub Repo Webhook 등록

`gh api -X POST repos/eggdory-dev/idea-hub/hooks` 로 등록:
- URL: `https://macbook-pro-7.tailee025e.ts.net/webhook`
- Content type: `application/json`
- Secret: 위 `.env`와 동일
- Events: `issue_comment` 만 활성화 (불필요 트래픽 차단)

## 4. 에러 / 엣지 케이스

| 상황 | 동작 |
|---|---|
| HMAC 검증 실패 | 401 + 로그 (공격 시도 의심) |
| issue_comment 외 이벤트 | 204 (무시) |
| building 라벨 없음 | 204 (무시) |
| 봇 자동 댓글 | 204 (무시) |
| `auto-dev.sh` 이미 실행 중 | LOCK_FILE로 차단되지만, 진행 중 인스턴스가 어차피 모든 building 이슈 스캔하므로 새 댓글 누락 없음 |
| 맥 슬립 중 webhook 도착 | GitHub이 자동 redelivery 큐에 보관 (Settings → Webhooks → Recent Deliveries에서 수동 재전송 가능) |
| Tailscale Funnel 다운 | 6시간 폴링이 catch-all 역할 |
| Python receiver 크래시 | launchd KeepAlive로 즉시 재시작 |

## 5. 보안

- HMAC-SHA256 검증으로 위조 요청 차단
- Funnel URL은 공개되어 있어도 secret 없는 요청은 401
- receiver는 loopback 바인딩 → Tailscale Funnel 외부 경로 외에는 접근 불가
- 받는 페이로드의 어떤 필드도 셸로 보간하지 않음 (auto-dev.sh는 인자 없이 호출)

## 6. 테스트

1. `tailscale funnel status` — URL 노출 확인
2. `curl https://<funnel-url>/healthz` — 200 확인
3. `curl -X POST -H "X-Hub-Signature-256: sha256=wrong" .../webhook` — 401 확인
4. GitHub Settings → Webhooks → "Recent Deliveries" → 과거 이벤트 Redeliver → 로컬 로그/실행 확인
5. 실제 댓글 → end-to-end (지연 < 5초 목표)

## 7. 향후 확장 가능성 (현재 범위 밖)

- `/approve` 같은 슬래시 커맨드 즉시 처리 (현재는 GitHub Actions가 처리 중)
- 이슈별 처리 큐 분리 (현 LOCK_FILE은 글로벌)
- Tailscale 외 fallback 채널 (필요해지면 검토)
