"""
[온기] 가짜 보드 확인용 클라이언트 (앱 대신 start를 보내 보고 신호를 출력)

실행 : python test_client.py                       (같은 노트북)
       python test_client.py ws://192.168.0.20:8765 safety
"""
import asyncio
import json
import sys

import websockets


async def main():
    url = sys.argv[1] if len(sys.argv) > 1 else "ws://127.0.0.1:8765"
    scenario = sys.argv[2] if len(sys.argv) > 2 else None
    async with websockets.connect(url) as ws:
        start = {"type": "start"}
        if scenario:
            start["scenario"] = scenario
        await ws.send(json.dumps(start))
        print("보냄:", start)
        async for raw in ws:
            msg = json.loads(raw)
            print("받음:", json.dumps(msg, ensure_ascii=False))
            if msg["type"] == "idle":
                break


asyncio.run(main())
