"""
[온기] 가짜 서버 — 정범님 서버가 나오기 전 보드 동기화·부모 앱 시험용

기준: 정범님 API 규격서 v0.6 (server 브랜치 docs/온기_API_규격서_v0.6.xlsx, 11/3)
  보드용 (11/5 v0.6 맞춤)
    API-11 GET  /device/changes?since=      {"server_time", "messages": [...]}  since "이상", updated_at 오름차순
    API-12 GET  /device/audio/{id}           m4a 그대로 / 글 메시지 E-400 / 없거나 지워짐 E-404
    API-13 POST /device/ack                  {"acknowledged_ids": [...]}  없는 id가 있으면 E-404
    API-14 POST /device/play-logs            새 기록 201, 같은 기록 200
  부모 앱용 (11/5 추가, 유정님 앱 시험용)
    API-01 POST /families                    가족 1개(시연 가족이 이미 있어서 보통 E-409)
    API-02 GET  /situations                  상황 12개
    API-03 GET  /messages?family_id=1        삭제 안 된 메시지, 상황 번호 순
    API-04 POST /messages                    텍스트 또는 녹음(API-05의 audio_path) 등록, 201
    API-05 POST /audio  (multipart file)     m4a만, 10MB까지 → {"audio_path", "size_bytes", "content_type"}
    API-06 PATCH /messages/{id}              보낸 값만 바꿈
    API-07 DELETE /messages/{id}             소프트 삭제
    API-09 GET  /play-logs?family_id=1       재생 기록 (최근 순)
    API-10 GET  /messages/count?family_id=1
설치 없음(파이썬 기본 모듈만). 메시지는 메모리에만 둔다(끄면 처음 상태). 앱이 웹(Flutter web)이어도 되게 CORS 허용.

실행 : python3 device/mock_server.py              (포트 8000, 같은 공유기면 http://<노트북 IP>:8000)
보드 : adb reverse tcp:8000 tcp:8000               (보드의 127.0.0.1:8000 → 이 맥)
시험 :
  python3 device/mock_server.py list                      메시지·전달 여부·재생 기록 보기
  python3 device/mock_server.py add 2 dad text "괜찮아, 실수하면서 크는 거야"   상황 2에 글 메시지
  python3 device/mock_server.py del 5                     메시지 5 삭제
진짜 녹음: _local/mock_audio/{메시지 id}.m4a (시연 1·2번), 앱이 올린 녹음은 _local/mock_audio/uploads/
"""
import json
import os
import re
import sys
import threading
import urllib.request
import uuid
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("ONGI_MOCK_PORT", "8000"))   # 11/9: 웹 미리보기용으로 8001 등 (진짜 서버 8000과 같이 켤 때)
LOCK = threading.Lock()
now = lambda: datetime.now().replace(microsecond=0).isoformat()

# 진짜 녹음 파일 폴더(git 제외)
AUDIO_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_local", "mock_audio")
UPLOAD_DIR = os.path.join(AUDIO_DIR, "uploads")
FAKE_M4A = b"\x00\x00\x00\x18ftypM4A \x00\x00\x02\x00M4A isomiso2" + b"\x00" * 1000   # 가짜 녹음(재생은 안 됨)
MAX_AUDIO = 10_000_000

SITUATIONS = [
    (1, "학교 가기 싫은 날", "학교·학업"), (2, "실수해서 혼났을 때", "학교·학업"), (3, "시험을 망친 날", "학교·학업"),
    (4, "친구와 싸운 날", "관계·비교"), (5, "친구가 날 싫어하는 것 같을 때", "관계·비교"), (6, "남들과 비교될 때", "관계·비교"),
    (7, "울고 싶은 날", "감정·일상"), (8, "아무것도 하기 싫은 날", "감정·일상"), (9, "잠이 안 오는 밤", "감정·일상"),
    (10, "부모님이 보고 싶을 때", "가족·기념일"), (11, "자랑하고 싶은 날", "가족·기념일"), (12, "생일", "가족·기념일"),
]

# 시연용 데이터 (보드 시연 메시지와 같은 id, 명세서 7장)
T0 = "2026-11-01T09:00:00"
FAMILY = dict(id=1, child_name="민준", mom_title="엄마", dad_title="아빠", created_at=T0)


def _msg(mid, sid, author, kind, text=None, audio_path=None):
    return dict(id=mid, family_id=1, situation_id=sid, author=author, kind=kind, text=text, audio_path=audio_path,
                delivered=False, created_at=T0, updated_at=T0, deleted=False)


MESSAGES = {
    1: _msg(1, 4, "mom", "voice", audio_path="1.m4a"),
    2: _msg(2, 10, "mom", "voice", audio_path="2.m4a"),
    3: _msg(3, 11, "dad", "text", "민준아, 상 받은 거 정말 축하해! 일곱 살 때 자전거를 배우면서 열 번도 넘게 넘어지고도, 울면서 다시 페달을 밟던 네 모습이 아빠는 아직도 생생해. 이 상도 그렇게 포기하지 않은 민준이가 만든 거야. 곁에서 안아 주지는 못해도, 아빠는 민준이가 정말 자랑스러워."),
    4: _msg(4, 3, "mom", "text", "민준아, 시험 때문에 속상하구나. 엄마도 3학년 때 받아쓰기에서 빵점을 받고, 집에 오는 길 내내 울었어. 그때 외할머니가 \"틀린 건 다음에 맞히면 돼\" 하셨는데, 그 말이 아직도 생각나. 엄마는 점수보다 끝까지 해 본 민준이가 더 자랑스러워."),
}
PLAY_LOGS = []
UPLOADED = set()      # API-05로 올라온 audio_path


def err(code, msg):
    return {"error": code, "message": msg}


def device_view(m):
    """API-11 항목 모양"""
    return {k: m[k] for k in ("id", "situation_id", "author", "kind", "text", "deleted", "updated_at")}


def audio_file(m):
    """메시지의 녹음 파일 경로 (없으면 None)"""
    p = m.get("audio_path")
    cands = ([os.path.join(UPLOAD_DIR, p), os.path.join(AUDIO_DIR, p)] if p else []) + [os.path.join(AUDIO_DIR, f"{m['id']}.m4a")]
    return next((c for c in cands if os.path.isfile(c)), None)


def parse_multipart(body, ctype):
    """multipart/form-data에서 file 부분 (파일 이름, 바이트). 없으면 (None, None)"""
    m = re.search(r'boundary="?([^";]+)"?', ctype or "")
    if not m:
        return None, None
    for part in body.split(b"--" + m.group(1).encode()):
        head, sep, data = part.partition(b"\r\n\r\n")
        if not sep or b'name="file"' not in head:
            continue
        fn = re.search(rb'filename="([^"]*)"', head)
        return (fn.group(1).decode("utf-8", "replace") if fn else ""), data[:-2] if data.endswith(b"\r\n") else data
    return None, None


class H(BaseHTTPRequestHandler):
    def _send(self, status, obj=None, raw=None, ctype="application/json; charset=utf-8", extra=None):
        body = raw if raw is not None else json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _raw(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _body(self):
        try:
            return json.loads(self._raw() or b"{}")
        except Exception:
            return None

    def log_message(self, fmt, *args):
        # 11/9: 잘못된 요청(브라우저 https 시도 등)은 command·path가 없을 수 있음
        print(f"[{now()}] {getattr(self, 'command', '?')} {getattr(self, 'path', fmt % args)}")

    def do_OPTIONS(self):          # CORS (Flutter web)
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _family(self, q):
        try:
            fid = int(q.get("family_id", [""])[0])
        except ValueError:
            return None, self._send(400, err("E-400", "family_id가 없거나 형식이 올바르지 않아요"))
        if fid != FAMILY["id"]:
            return None, self._send(404, err("E-404", "가족을 찾을 수 없어요"))
        return fid, None

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        with LOCK:
            if u.path == "/health":
                return self._send(200, {"ok": True})
            if u.path == "/device/changes":                       # API-11
                since = q.get("since", ["2000-01-01T00:00:00"])[0]
                if not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d", since):
                    return self._send(400, err("E-400", "since 형식이 올바르지 않아요 (예: 2026-11-02T20:00:00)"))
                ch = sorted((device_view(m) for m in MESSAGES.values() if m["updated_at"] >= since), key=lambda m: m["updated_at"])
                return self._send(200, {"server_time": now(), "messages": ch})
            if u.path.startswith("/device/audio/"):               # API-12
                mid = int(u.path.rsplit("/", 1)[1])
                m = MESSAGES.get(mid)
                if not m or m["deleted"]:
                    return self._send(404, err("E-404", "메시지를 찾을 수 없어요"))
                if m["kind"] != "voice":
                    return self._send(400, err("E-400", "녹음 메시지가 아니에요"))
                f = audio_file(m)
                data = open(f, "rb").read() if f else FAKE_M4A
                return self._send(200, raw=data, ctype="audio/mp4",
                                  extra={"Content-Disposition": f'attachment; filename="{mid}.m4a"'})
            if u.path == "/situations":                           # API-02
                return self._send(200, {"items": [dict(id=i, name=n, category=c) for i, n, c in SITUATIONS]})
            if u.path == "/messages":                             # API-03
                fid, e = self._family(q)
                if fid is None:
                    return e
                items = sorted((m for m in MESSAGES.values() if not m["deleted"]), key=lambda m: m["situation_id"])
                return self._send(200, {"items": items})
            if u.path == "/messages/count":                       # API-10
                fid, e = self._family(q)
                if fid is None:
                    return e
                return self._send(200, {"count": sum(not m["deleted"] for m in MESSAGES.values())})
            if u.path == "/play-logs":                            # API-09
                fid, e = self._family(q)
                if fid is None:
                    return e
                items = [dict(l, situation_id=MESSAGES[l["message_id"]]["situation_id"], author=MESSAGES[l["message_id"]]["author"])
                         for l in sorted(PLAY_LOGS, key=lambda l: l["played_at"], reverse=True) if l["message_id"] in MESSAGES]
                return self._send(200, {"items": items})
        self._send(404, err("E-404", "없는 주소"))

    def do_POST(self):
        u = urlparse(self.path)
        if u.path == "/audio":                                    # API-05 (multipart)
            raw = self._raw()
            name, data = parse_multipart(raw, self.headers.get("Content-Type"))
            if data is None or len(data) == 0:
                return self._send(400, err("E-400", "파일이 없거나 비어 있어요"))
            if len(data) > MAX_AUDIO:
                return self._send(413, err("E-413", "파일 크기는 10MB 이하여야 해요"))
            if not name.lower().endswith(".m4a") or data[4:8] != b"ftyp":
                return self._send(400, err("E-400", "m4a 파일만 올릴 수 있어요"))
            os.makedirs(UPLOAD_DIR, exist_ok=True)
            key = uuid.uuid4().hex + ".m4a"
            with open(os.path.join(UPLOAD_DIR, key), "wb") as f:
                f.write(data)
            with LOCK:
                UPLOADED.add(key)
            print(f"   → 녹음 올림: {name} ({len(data)}바이트) → {key}")
            return self._send(201, {"audio_path": key, "size_bytes": len(data), "content_type": "audio/mp4"})
        b = self._body()
        if b is None:
            return self._send(400, err("E-400", "JSON이 올바르지 않아요"))
        with LOCK:
            if u.path == "/device/ack":                           # API-13
                ids = b.get("message_ids", [])
                if not ids or len(ids) > 100 or len(set(ids)) != len(ids):
                    return self._send(400, err("E-400", "message_ids가 올바르지 않아요"))
                if any(i not in MESSAGES for i in ids):
                    return self._send(404, err("E-404", "메시지를 찾을 수 없어요"))
                for i in ids:
                    MESSAGES[i]["delivered"] = True
                print(f"   → 전달됨: {ids}")
                return self._send(200, {"acknowledged_ids": ids})
            if u.path == "/device/play-logs":                     # API-14
                if b.get("message_id") not in MESSAGES:
                    return self._send(404, err("E-404", "메시지를 찾을 수 없어요"))
                old = next((l for l in PLAY_LOGS if l["message_id"] == b["message_id"] and l["played_at"] == b["played_at"]), None)
                if old:
                    return self._send(200, old)
                rec = {"id": len(PLAY_LOGS) + 1, "message_id": b["message_id"], "played_at": b["played_at"]}
                PLAY_LOGS.append(rec)
                print(f"   → 재생 기록: {rec}")
                return self._send(201, rec)
            if u.path == "/families":                             # API-01 (가족 1개)
                return self._send(409, err("E-409", "이미 등록된 가족이 있어요 (시연 가족 id 1)"))
            if u.path == "/messages":                             # API-04
                try:
                    fid, sid = int(b.get("family_id", 1)), int(b["situation_id"])
                except (KeyError, ValueError, TypeError):
                    return self._send(400, err("E-400", "family_id·situation_id가 올바르지 않아요"))
                author, kind = b.get("author"), b.get("kind")
                if fid != FAMILY["id"] or not 1 <= sid <= 12:
                    return self._send(404, err("E-404", "가족·상황을 찾을 수 없어요"))
                if author not in ("mom", "dad") or kind not in ("text", "voice"):
                    return self._send(400, err("E-400", "author는 mom/dad, kind는 text/voice"))
                text, ap = b.get("text"), b.get("audio_path")
                if kind == "text" and (not text or not str(text).strip() or len(text) > 200 or ap):
                    return self._send(400, err("E-400", "글 메시지는 text 1~200자, audio_path는 보내지 않아요"))
                if kind == "voice" and (text or ap not in UPLOADED):
                    return self._send(400, err("E-400", "녹음 메시지는 API-05가 준 audio_path가 필요해요"))
                if any(m["situation_id"] == sid and not m["deleted"] for m in MESSAGES.values()):
                    return self._send(409, err("E-409", "이 상황에는 이미 메시지가 있어요"))
                mid = max(MESSAGES) + 1
                m = _msg(mid, sid, author, kind, text if kind == "text" else None, ap if kind == "voice" else None)
                m["created_at"] = m["updated_at"] = now()
                MESSAGES[mid] = m
                print(f"   → 메시지 {mid} 등록 (상황 {sid}, {author} {kind})")
                return self._send(201, m)
        self._send(404, err("E-404", "없는 주소"))

    def do_PATCH(self):
        u = urlparse(self.path)
        b = self._body()
        with LOCK:
            if u.path.startswith("/messages/"):                   # API-06
                mid = int(u.path.rsplit("/", 1)[1])
                m = MESSAGES.get(mid)
                if not m or m["deleted"]:
                    return self._send(404, err("E-404", "메시지를 찾을 수 없어요"))
                if not b or any(k not in ("author", "kind", "text", "audio_path") for k in b):
                    return self._send(400, err("E-400", "바꿀 값이 없거나 보낼 수 없는 칸이 있어요"))
                m.update(b)
                if "kind" in b:
                    if b["kind"] == "text" and "audio_path" not in b: m["audio_path"] = None
                    if b["kind"] == "voice" and "text" not in b: m["text"] = None
                m.update(updated_at=now(), delivered=False)
                print(f"   → 메시지 {mid} 수정")
                return self._send(200, m)
        self._send(404, err("E-404", "없는 주소"))

    def do_DELETE(self):
        u = urlparse(self.path)
        with LOCK:
            if u.path.startswith("/messages/"):                   # API-07
                mid = int(u.path.rsplit("/", 1)[1])
                m = MESSAGES.get(mid)
                if not m:
                    return self._send(404, err("E-404", "메시지를 찾을 수 없어요"))
                if not m["deleted"]:
                    m.update(deleted=True, delivered=False, updated_at=now())
                    print(f"   → 메시지 {mid} 삭제")
                return self._send(200, m)
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
        # 켤 때 모든 메시지 시각을 지금으로 → 보드가 since와 상관없이 다시 받아 감(바뀐 글·진짜 녹음 반영)
        for mid, m in MESSAGES.items():
            m["updated_at"] = now()
            real = audio_file(m) is not None
            print(f"메시지 {mid} (상황 {m['situation_id']}, {m['author']} {m['kind']}{', 진짜 녹음' if real else ''}) → 보드가 다시 받아 감")
        print(f"가짜 서버 시작: http://0.0.0.0:{PORT}  (보드: adb reverse tcp:{PORT} tcp:{PORT})")
        ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
    elif a[0] == "add":
        sid, author, kind = a[1], a[2], a[3]
        text = a[4] if len(a) > 4 else None
        print(json.dumps(call("POST", "/messages", {"family_id": 1, "situation_id": int(sid), "author": author, "kind": kind, "text": text}), ensure_ascii=False))
    elif a[0] == "del":
        print(json.dumps(call("DELETE", f"/messages/{a[1]}"), ensure_ascii=False))
    elif a[0] == "list":
        for m in call("GET", "/messages?family_id=1")["items"]:
            print(f"  {m['id']:>2}  상황 {m['situation_id']:>2}  {m['author']} {m['kind']:<5}  전달됨 {'O' if m['delivered'] else '-'}  {m['text'] or m['audio_path'] or ''}")
        print("  재생 기록:", call("GET", "/play-logs?family_id=1")["items"])
