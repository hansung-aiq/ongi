"""
[온기] 신호 확인용 클라이언트 (앱 대신 start를 보내 보고 신호를 출력)

실행 : python test_client.py                                  (같은 노트북의 가짜 보드)
       python test_client.py ws://192.168.0.20:8765 safety     (가짜 보드: 시나리오 지정)
       python test_client.py ws://127.0.0.1:8765 "오늘 친구랑 싸웠어"
                                                               (진짜 보드 시험 모드: 아이 말 대신 글)
진짜 보드는 먼저: adb forward tcp:8765 tcp:8765
"""
import asyncio
import json
import sys

import websockets

SCENARIOS = {"normal", "play_voice", "play_mom10", "play_text", "empathy_only", "not_found", "safety", "error"}


async def main():
    url = sys.argv[1] if len(sys.argv) > 1 else "ws://127.0.0.1:8765"
    extra = sys.argv[2] if len(sys.argv) > 2 else None
    async with websockets.connect(url) as ws:
        start = {"type": "start"}
        if extra in SCENARIOS:
            start["scenario"] = extra      # 가짜 보드용
        elif extra:
            start["text"] = extra          # 진짜 보드 시험 모드용
        await ws.send(json.dumps(start, ensure_ascii=False))
        print("보냄:", json.dumps(start, ensure_ascii=False))
        async for raw in ws:
            msg = json.loads(raw)
            print("받음:", json.dumps(msg, ensure_ascii=False))
            if msg["type"] == "idle":
                break


asyncio.run(main())
