"""
[온기] 가짜 보드 (DEV-05)

진짜 보드 없이 자녀 앱을 개발할 수 있도록, 신호 규격서(docs/신호규격서.txt)와
똑같은 신호를 보내는 WebSocket 서버.

설치  : pip install websockets
실행  : python mock_board.py                      (기본: 시연 문장 4개를 차례대로)
        python mock_board.py --scenario safety    (한 가지 경우만 반복)
        python mock_board.py --delay 0.5          (신호 간격 조절, 초)
접속  : ws://<이 노트북 IP>:8765   (같은 공유기 안. IP는 맥: ipconfig getifaddr en0)

시나리오
  normal        상황 4/10/11 + 배고파(not_found) 4개를 차례대로 (기본값)
  play_voice    상황 4, 엄마 녹음 재생
  play_text     상황 11, 아빠 글 메시지(온기 목소리)
  empathy_only  공감 한마디만 (has_message=false)
  not_found     받아주는 말
  safety        위기 표현 → 안전 응답
  error         받아쓰기 실패(D-002)

앱 개발 편의를 위한 추가 기능(가짜 보드에만 있음, 진짜 보드에는 없음)
  {"type":"start","scenario":"safety"}  처럼 start에 scenario를 넣으면 그 경우로 한 번 진행
"""

import argparse
import asyncio
import itertools
import json
import logging
from datetime import datetime

import websockets

PORT = 8765

# 시연용 고정 데이터 (공통지침 규칙 7)
MESSAGES = {
    4: {"message_id": 1, "author": "mom", "kind": "voice", "text": None, "seconds": 6},
    10: {"message_id": 2, "author": "mom", "kind": "voice", "text": None, "seconds": 6},
    11: {"message_id": 3, "author": "dad", "kind": "text",
         "text": "민준아, 상 받은 거 정말 축하해. 아빠는 네가 노력한 게 제일 자랑스러워.", "seconds": 6},
}

SCENARIOS = {
    "play_voice": {"heard": "오늘 친구랑 싸웠어", "kind": "play", "situation_id": 4,
                   "empathy": "속상한 일이 있었나 보다"},
    "play_mom10": {"heard": "엄마 보고 싶어", "kind": "play", "situation_id": 10,
                   "empathy": "많이 보고 싶었구나"},
    "play_text": {"heard": "나 오늘 상 받았어", "kind": "play", "situation_id": 11,
                  "empathy": "우와 정말 기쁘겠다"},
    "empathy_only": {"heard": "오늘 기분 진짜 별로야", "kind": "empathy_only",
                     "empathy": "오늘 마음이 좀 무거웠나 보다"},
    "not_found": {"heard": "배고파", "kind": "not_found",
                  "reply": "그런 날도 있지, 이야기해 줘서 고마워"},
    "safety": {"heard": "(위기 표현 예시)", "kind": "safety",
               "reply": "지금 많이 힘들구나. 혼자 견디지 않아도 돼. 청소년 상담전화 1388에 전화하면 언제든 이야기를 들어줄 거야."},
    "error": {"heard": None, "kind": "error", "code": "D-002"},
}
NORMAL_ORDER = ["play_voice", "play_mom10", "play_text", "not_found"]

log = logging.getLogger("mock_board")


def now():
    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


async def send(ws, msg):
    await ws.send(json.dumps(msg, ensure_ascii=False))
    log.info("→ %s", json.dumps(msg, ensure_ascii=False))


async def run_cycle(ws, name, delay):
    """start 한 번에 대한 신호 흐름. stop이 오면 취소된다."""
    s = SCENARIOS[name]
    log.info("== 시나리오: %s ==", name)
    await send(ws, {"type": "listening"})
    await asyncio.sleep(delay * 2)            # 아이가 말하는 시간

    if s["kind"] == "error":
        await send(ws, {"type": "error", "code": s["code"]})
        await asyncio.sleep(delay)
        await send(ws, {"type": "idle"})
        return

    await send(ws, {"type": "thinking", "text": s["heard"]})
    await asyncio.sleep(delay)

    if s["kind"] == "safety":
        await send(ws, {"type": "safety", "text": s["reply"]})
        await asyncio.sleep(delay * 3)
    elif s["kind"] == "not_found":
        await send(ws, {"type": "not_found", "text": s["reply"]})
        await asyncio.sleep(delay * 2)
    elif s["kind"] == "empathy_only":
        await send(ws, {"type": "empathy", "text": s["empathy"], "has_message": False, "author": None})
        await asyncio.sleep(delay * 2)
    else:  # play
        m = MESSAGES[s["situation_id"]]
        await send(ws, {"type": "empathy", "text": s["empathy"], "has_message": True, "author": m["author"]})
        await asyncio.sleep(delay * 2)
        await send(ws, {"type": "playing", "situation_id": s["situation_id"], "message_id": m["message_id"],
                        "author": m["author"], "kind": m["kind"], "text": m["text"]})
        await asyncio.sleep(m["seconds"] * delay)

    await send(ws, {"type": "idle"})


async def handler(ws, args, order):
    peer = ws.remote_address
    log.info("앱 접속: %s", peer)
    task = None
    try:
        async for raw in ws:
            log.info("← %s", raw)
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                log.warning("JSON이 아닌 메시지 무시")
                continue
            t = msg.get("type")
            if t == "start":
                if task and not task.done():
                    log.info("이미 진행 중 → start 무시")
                    continue
                name = msg.get("scenario") or (args.scenario if args.scenario != "normal" else next(order))
                if name not in SCENARIOS:
                    log.warning("모르는 시나리오 %s → normal 순서로 진행", name)
                    name = next(order)
                task = asyncio.create_task(run_cycle(ws, name, args.delay))
            elif t == "stop":
                if task and not task.done():
                    task.cancel()
                await send(ws, {"type": "idle"})
            else:
                log.warning("모르는 type: %s", t)
    except websockets.ConnectionClosed:
        pass
    finally:
        if task and not task.done():
            task.cancel()
        log.info("앱 연결 끊김: %s", peer)


async def main():
    p = argparse.ArgumentParser(description="온기 가짜 보드 (WebSocket 8765)")
    p.add_argument("--scenario", default="normal", choices=["normal"] + list(SCENARIOS))
    p.add_argument("--delay", type=float, default=1.0, help="신호 간격(초)")
    p.add_argument("--port", type=int, default=PORT)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
    order = itertools.cycle(NORMAL_ORDER)
    async with websockets.serve(lambda ws: handler(ws, args, order), "0.0.0.0", args.port):
        log.info("가짜 보드 시작: ws://0.0.0.0:%d  (시나리오 %s, 간격 %.1f초)", args.port, args.scenario, args.delay)
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
