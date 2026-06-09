#!/usr/bin/env python3
"""GitHub issue_comment webhook → auto-dev.sh 트리거.

- 포트 9090 loopback 바인딩 (외부는 Tailscale Funnel을 통해서만 접근)
- HMAC-SHA256 으로 X-Hub-Signature-256 검증
- issue_comment.created 만 통과, building 라벨 + 봇 자동 댓글 필터
- 통과 시 auto-dev.sh 를 백그라운드 실행, 즉시 200 응답
"""
from __future__ import annotations

import hmac
import hashlib
import json
import logging
import os
import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

STATE_DIR = Path.home() / ".idea-hub-auto-dev"
ENV_FILE = STATE_DIR / ".env"
LOG_FILE = STATE_DIR / "webhook.log"
AUTO_DEV_SCRIPT = Path.home() / "Documents/repository/idea-hub/scripts/auto-dev.sh"

PORT = 9090
HOST = "127.0.0.1"


def load_env() -> dict[str, str]:
    env: dict[str, str] = {}
    if not ENV_FILE.exists():
        return env
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip()
    return env


ENV = load_env()
SECRET = ENV.get("GITHUB_WEBHOOK_SECRET", "").encode()

BOT_PATTERNS = [
    re.compile(r"_자동 실행 by auto-dev\.sh_"),
    re.compile(r"^✅ 승인 상태로 변경됨"),
    re.compile(r"^🚀 \*\*레포지토리"),
    re.compile(r"^🤖"),
    re.compile(r"개발 현황 리포트"),
]


def is_bot_comment(body: str) -> bool:
    return any(p.search(body) for p in BOT_PATTERNS)


def verify_signature(secret: bytes, body: bytes, header: str | None) -> bool:
    if not secret or not header or not header.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(secret, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, header)


def trigger_auto_dev(issue_number: int) -> None:
    """auto-dev.sh를 백그라운드로 실행. 부모와 분리된 세션."""
    log = LOG_FILE.open("ab")
    subprocess.Popen(
        ["/bin/bash", str(AUTO_DEV_SCRIPT)],
        stdout=log,
        stderr=log,
        start_new_session=True,
        env={**os.environ, "WEBHOOK_TRIGGER_ISSUE": str(issue_number)},
    )


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: dict | None = None) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        payload = json.dumps(body or {}).encode()
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args) -> None:
        logging.info("%s - %s", self.address_string(), format % args)

    def do_GET(self) -> None:
        if self.path == "/healthz":
            self._send(200, {"ok": True})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/webhook":
            self._send(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""

        sig = self.headers.get("X-Hub-Signature-256")
        if not verify_signature(SECRET, body, sig):
            logging.warning("HMAC 검증 실패 from %s", self.address_string())
            self._send(401, {"error": "invalid signature"})
            return

        event = self.headers.get("X-GitHub-Event", "")
        if event == "ping":
            logging.info("ping 수신 (GitHub webhook 등록 확인)")
            self._send(200, {"pong": True})
            return

        if event != "issue_comment":
            self._send(204)
            return

        try:
            payload = json.loads(body.decode())
        except json.JSONDecodeError:
            self._send(400, {"error": "invalid json"})
            return

        action = payload.get("action")
        if action != "created":
            self._send(204)
            return

        issue = payload.get("issue") or {}
        issue_number = issue.get("number", 0)
        labels = {l.get("name") for l in issue.get("labels", [])}
        if "building" not in labels:
            logging.info("issue #%s: building 라벨 없음, 무시", issue_number)
            self._send(204)
            return

        comment_body = (payload.get("comment") or {}).get("body", "")
        if is_bot_comment(comment_body):
            logging.info("issue #%s: 봇 자동 댓글, 무시", issue_number)
            self._send(204)
            return

        author = (payload.get("comment") or {}).get("user", {}).get("login", "?")
        logging.info("issue #%s @%s: auto-dev 트리거", issue_number, author)
        trigger_auto_dev(issue_number)
        self._send(200, {"queued": True, "issue": issue_number})


def main() -> int:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=str(LOG_FILE),
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )
    logging.info("webhook receiver 시작 — listening on %s:%s", HOST, PORT)

    if not SECRET:
        logging.error("GITHUB_WEBHOOK_SECRET 미설정 — .env 확인 필요")
        print("ERROR: GITHUB_WEBHOOK_SECRET not set in", ENV_FILE, file=sys.stderr)
        return 1

    if not AUTO_DEV_SCRIPT.exists():
        logging.error("auto-dev.sh 없음: %s", AUTO_DEV_SCRIPT)
        return 1

    server = ThreadingHTTPServer((HOST, PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info("종료 (KeyboardInterrupt)")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
