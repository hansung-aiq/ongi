"""
[온기] 가짜 서버 (DEV-09) — 정범님 서버가 나오기 전 보드 동기화 시험용

서버 과제서 4장 API 중 보드가 쓰는 API-11 ~ 14 + 시험용 메시지 등록·삭제.
설치 없음(파이썬 기본 모듈만). 메시지는 메모리에만 둔다(끄면 처음 상태).

실행 : python3 device/mock_server.py              (포트 8000)
보드 : adb reverse tcp:8000 tcp:8000               (보드의 127.0.0.1:8000 → 이 맥)
시험 :
  python3 device/mock_server.py add 2 dad voice           상황 2에 아빠 녹음 메시지 추가
  python3 device/mock_server.py add 7 mom text "울어도 괜찮아, 엄마가 있잖아"
  python3 device/mock_server.py del 5                     메시지 5 삭제
  python3 device/mock_server.py list                      메시지·전달 여부·재생 기록 보기

API-11 응답(가정, 정범님 규격 확정되면 맞춤):
  {"server_time": "...", "messages": [{"id", "situation_id", "author", "kind", "text", "deleted", "updated_at"}]}
"""
import json
import sys
import threading
import urllib.request
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = 8000
LOCK = threading.Lock()
now = lambda: datetime.now().replace(microsecond=0).isoformat()

# 시연용 데이터 (공통지침 규칙 7, 보드 시연 메시지와 같은 id)
T0 = "2026-11-01T09:00:00"
MESSAGES = {
    1: dict(id=1, situation_id=4, author="mom", kind="voice", text=None, deleted=False, delivered=False, updated_at=T0),
    2: dict(id=2, situation_id=10, author="mom", kind="voice", text=None, deleted=False, delivered=False, updated_at=T0),
    3: dict(id=3, situation_id=11, author="dad", kind="text",
            text="민준아, 상 받은 거 정말 축하해. 아빠는 네가 노력한 게 제일 자랑스러워.", deleted=False, delivered=False, updated_at=T0),
    # 11/5 시연 4개 상황 맞추기: 3 시험을 망친 날
    4: dict(id=4, situation_id=3, author="mom", kind="text",
            text="괜찮아, 시험보다 네가 더 소중해. 엄마는 늘 네 편이야.", deleted=False, delivered=False, updated_at=T0),
}
PLAY_LOGS = []
FAKE_M4A = b"\x00\x00\x00\x18ftypM4A \x00\x00\x02\x00M4A isomiso2" + b"\x00" * 1000   # 가짜 녹음(재생은 안 됨)


def err(code, msg):
    return {"error": code, "message": msg}


class H(BaseHTTPRequestHandler):
    def _send(self, status, obj=None, raw=None, ctype="application/json; charset=utf-8"):
        body = raw if raw is not None else json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def log_message(self, fmt, *args):
        print(f"[{now()}] {self.command} {self.path}")

    def do_GET(self):
        u = urlparse(self.path)
        with LOCK:
            if u.path == "/health":
                return self._send(200, {"ok": True})
            if u.path == "/device/changes":                       # API-11
                since = parse_qs(u.query).get("since", ["2000-01-01T00:00:00"])[0]
                ch = [{k: v for k, v in m.items() if k != "delivered"} for m in MESSAGES.values() if m["updated_at"] > since]
                return self._send(200, {"server_time": now(), "messages": ch})
            if u.path.startswith("/device/audio/"):               # API-12
                mid = int(u.path.rsplit("/", 1)[1])
                m = MESSAGES.get(mid)
                if not m or m["deleted"] or m["kind"] != "voice":
                    return self._send(404, err("E-404", "녹음이 없어요"))
                return self._send(200, raw=FAKE_M4A, ctype="audio/mp4")
            if u.path == "/messages":                             # API-03 (확인용)
                return self._send(200, {"messages": [m for m in MESSAGES.values() if not m["deleted"]]})
            if u.path == "/play-logs":                            # API-09 (확인용)
                return self._send(200, {"play_logs": PLAY_LOGS})
        self._send(404, err("E-404", "없는 주소"))

    def do_POST(self):
        u = urlparse(self.path)
        b = self._body()
        with LOCK:
            if u.path == "/device/ack":                           # API-13
                ids = b.get("message_ids", [])
                for i in ids:
                    if i in MESSAGES: MESSAGES[i]["delivered"] = True
                print(f"   → 전달됨: {ids}")
                return self._send(200, {"ok": True, "updated": len(ids)})
            if u.path == "/device/play-logs":                     # API-14
                PLAY_LOGS.append({"message_id": b["message_id"], "played_at": b["played_at"]})
                print(f"   → 재생 기록: {b}")
                return self._send(200, {"ok": True})
            if u.path == "/messages":                             # API-04 (시험용)
                sid = int(b["situation_id"])
                if any(m["situation_id"] == sid and not m["deleted"] for m in MESSAGES.values()):
                    return self._send(409, err("E-409", "이 상황에는 이미 메시지가 있어요"))
                mid = max(MESSAGES) + 1
                MESSAGES[mid] = dict(id=mid, situation_id=sid, author=b.get("author", "mom"), kind=b.get("kind", "text"),
                                     text=b.get("text"), deleted=False, delivered=False, updated_at=now())
                print(f"   → 메시지 {mid} 추가 (상황 {sid})")
                return self._send(200, MESSAGES[mid])
        self._send(404, err("E-404", "없는 주소"))

    def do_DELETE(self):
        u = urlparse(self.path)
        with LOCK:
            if u.path.startswith("/messages/"):                   # API-07 (시험용)
                mid = int(u.path.rsplit("/", 1)[1])
                if mid not in MESSAGES or MESSAGES[mid]["deleted"]:
                    return self._send(404, err("E-404", "없는 메시지"))
                MESSAGES[mid].update(deleted=True, updated_at=now())
                print(f"   → 메시지 {mid} 삭제")
                return self._send(200, {"ok": True})
        self._send(404, err("E-404", "없는 주소"))


def call(method, path, body=None):
    req = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}", method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read())


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        print(f"가짜 서버 시작: http://0.0.0.0:{PORT}  (보드: adb reverse tcp:{PORT} tcp:{PORT})")
        ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
    elif a[0] == "add":
        sid, author, kind = a[1], a[2], a[3]
        text = a[4] if len(a) > 4 else None
        print(json.dumps(call("POST", "/messages", {"situation_id": int(sid), "author": author, "kind": kind, "text": text}), ensure_ascii=False))
    elif a[0] == "del":
        print(json.dumps(call("DELETE", f"/messages/{a[1]}"), ensure_ascii=False))
    elif a[0] == "list":
        for m in call("GET", "/messages")["messages"]:
            print(f"  {m['id']:>2}  상황 {m['situation_id']:>2}  {m['author']} {m['kind']:<5}  전달됨 {'O' if m['delivered'] else '-'}  {m['text'] or ''}")
        print("  재생 기록:", call("GET", "/play-logs")["play_logs"])
