"""
[온기] STT 잘못 듣기 찾기 (11/5)
시연 문장과 비슷한 말을 맥 목소리(Yuna)로 빠르기·잡음을 바꿔 wav로 만들고, 보드에서 "판단만 해 보기"(재생 없음)로
STT → 키워드 결과를 한꺼번에 본다. 틀린 것만 모아 보여 준다 → 키워드 후보 (넣기 전에 학습·평가 데이터와 겹치는지 꼭 확인)

실행 (먼저 bash device/tools/start_board.sh, 앱은 11/5 check 기능이 들어간 빌드):
  python3 device/tools/stt_sweep.py              만들기 + 보내기 + 시험
  python3 device/tools/stt_sweep.py --no-make    이미 만든 wav로 시험만
결과 표: _local/speech/sweep/결과.csv
"""
import asyncio
import csv
import json
import os
import random
import subprocess
import sys
import wave
import struct

import websockets

URL = "ws://127.0.0.1:8765"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "_local", "speech", "sweep")
BOARD = "/sdcard/Android/data/com.aiq.ongi.device/files/sweep"

# (말, 기대 상황 번호, 0 = 상황 아님)
SENT = [
    ("나 오늘 시험 망쳤어", 3), ("수학 시험 망했어", 3), ("받아쓰기 빵점 맞았어", 3),
    ("오늘 친구랑 싸웠어", 4), ("짝꿍이랑 다퉜어", 4), ("친구랑 크게 싸웠어", 4),
    ("엄마 보고 싶어", 10), ("아빠 목소리 듣고 싶어", 10), ("엄마가 너무 그리워", 10),
    ("나 오늘 상 받았어", 11), ("선생님한테 칭찬 받았어", 11), ("나 달리기 일등 했어", 11),
    ("배고파", 0), ("친구랑 눈싸움했어", 0),
]
RATES = [150, 190, 240]          # 말 빠르기 (맥 say 기본 약 175)
NOISE = [0, 900]                 # 잡음 크기 (16비트 기준 표준편차)


def make():
    os.makedirs(OUT, exist_ok=True)
    random.seed(5)
    files = []
    for i, (t, exp) in enumerate(SENT):
        for r in RATES:
            base = os.path.join(OUT, f"_{i}_{r}.wav")
            subprocess.run(["say", "-v", "Yuna", "-r", str(r), "-o", base, "--data-format=LEI16@16000", t], check=True)
            w = wave.open(base); n = w.getnframes(); fr = w.getframerate(); b = w.readframes(n); w.close()
            s = struct.unpack("<%dh" % (len(b) // 2), b)
            for nz in NOISE:
                name = f"{i:02d}_r{r}_n{nz}.wav"
                if nz:
                    s2 = [max(-32768, min(32767, int(x + random.gauss(0, nz)))) for x in s]
                else:
                    s2 = s
                w = wave.open(os.path.join(OUT, name), "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(fr)
                w.writeframes(struct.pack("<%dh" % len(s2), *s2)); w.close()
                files.append((name, t, exp, r, nz))
            os.remove(base)
    print(f"만든 wav {len(files)}개 → {OUT}")
    subprocess.run(["adb", "shell", "mkdir", "-p", BOARD], check=True)
    subprocess.run(["adb", "push"] + [os.path.join(OUT, f[0]) for f in files] + [BOARD + "/"], check=True, stdout=subprocess.DEVNULL)
    print("보드로 보냄")
    return files


def listed():
    files = []
    for i, (t, exp) in enumerate(SENT):
        for r in RATES:
            for nz in NOISE:
                files.append((f"{i:02d}_r{r}_n{nz}.wav", t, exp, r, nz))
    return files


async def check(ws, name):
    await ws.send(json.dumps({"type": "check", "wav": f"{BOARD}/{name}"}))
    while True:
        m = json.loads(await ws.recv())
        if m.get("type") == "check_result":
            return m


async def main():
    files = listed() if "--no-make" in sys.argv else make()
    rows, bad = [], []
    async with websockets.connect(URL, max_size=None) as ws:
        for name, t, exp, r, nz in files:
            m = await check(ws, name)
            got = m.get("situation", "?")
            ok = got == exp
            rows.append(dict(파일=name, 말=t, 빠르기=r, 잡음=nz, 들은말=m.get("heard", ""), 기대=exp, 결과=got,
                             판단=m.get("by", m.get("error", "")), 맞음="O" if ok else "X", stt_ms=m.get("stt_ms", "")))
            if not ok:
                bad.append(rows[-1])
            print(("✅" if ok else "❌"), f"{t} (빠르기 {r}, 잡음 {nz}) → \"{m.get('heard', '')}\" → {got} ({m.get('by', m.get('error', ''))})")
    with open(os.path.join(OUT, "결과.csv"), "w", encoding="utf-8-sig", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0].keys())); wr.writeheader(); wr.writerows(rows)
    n_ok = sum(r["맞음"] == "O" for r in rows)
    print(f"\n맞음 {n_ok}/{len(rows)}  (결과표: _local/speech/sweep/결과.csv)")
    if bad:
        print("\n틀린 것 (들은 말 → 키워드 후보를 찾을 곳):")
        for b in bad:
            print(f"  기대 {b['기대']} / 결과 {b['결과']} ({b['판단']})  \"{b['말']}\" → \"{b['들은말']}\"")
    stt = [int(r["stt_ms"]) for r in rows if str(r["stt_ms"]).isdigit()]
    if stt:
        print(f"\nSTT 시간: 평균 {sum(stt)//len(stt)}ms, 최대 {max(stt)}ms")


asyncio.run(main())
