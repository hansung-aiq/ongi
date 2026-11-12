"""
[온기] 부모 녹음 받아쓰기 정확도 확인 (11/9, D2 조사용)
서버 files 폴더의 녹음(m4a)을 16kHz 모노 wav로 바꿔 보드에 올리고, 보드 STT("판단만 해 보기", 재생 없음)로 받아쓴 글을 본다.
녹음 메시지를 화면에 글로 보여 줄지(C안) 정하기 전에, 받아쓰기가 얼마나 맞는지 보려는 도구. 보드 코드는 바꾸지 않는다.

실행 (먼저 bash device/tools/start_board.sh):
  python3 device/tools/stt_message_check.py                 서버 files의 녹음 전부(무음 제외)
  python3 device/tools/stt_message_check.py 파일1.m4a ...   골라서
"""
import asyncio
import glob
import json
import os
import subprocess
import sys

import websockets

URL = "ws://127.0.0.1:8765"
FILES = os.path.expanduser("~/ongi-server/server/files")
TMP = "/tmp/ongi_stt_msg"
BOARD = "/sdcard/Android/data/com.aiq.ongi.device/files/sweep"


def read_pcm(path):
    """afconvert wav는 확장 형식(65534)이라 wave 모듈이 못 읽음 → chunk를 직접 읽는다. (채널, 샘플레이트, 16비트 bytes)"""
    import struct
    b = open(path, "rb").read()
    i, ch, sr, data = 12, 1, 16000, b""
    while i + 8 <= len(b):
        cid, size = b[i:i + 4], struct.unpack("<I", b[i + 4:i + 8])[0]
        body = b[i + 8:i + 8 + size]
        if cid == b"fmt ":
            ch, sr = struct.unpack("<HI", body[2:8])
        elif cid == b"data":
            data = body
        i += 8 + size + (size & 1)
    return ch, sr, data


def to_wav(m4a):
    """m4a → 16kHz 모노 16비트 표준 wav (보드 STT 입력)"""
    import wave
    os.makedirs(TMP, exist_ok=True)
    raw = os.path.join(TMP, "_raw.wav")
    out = os.path.join(TMP, os.path.basename(m4a).rsplit(".", 1)[0] + ".wav")
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", m4a, raw], check=True)
    ch, sr, data = read_pcm(raw)
    with wave.open(out, "wb") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(sr); w.writeframes(data)
    return out


def loud_enough(wav):
    import array, wave
    w = wave.open(wav)
    a = array.array("h", w.readframes(w.getnframes()))
    return max((abs(x) for x in a), default=0) >= 1000, len(a) / w.getframerate()


async def check(ws, name):
    await ws.send(json.dumps({"type": "check", "wav": f"{BOARD}/{name}"}))
    while True:
        m = json.loads(await asyncio.wait_for(ws.recv(), 60))
        if m.get("type") == "check_result":
            return m


async def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(FILES, "*.m4a")))
    todo = []
    for f in files:
        wav = to_wav(f)
        ok, sec = loud_enough(wav)
        if not ok:
            print(f"- {os.path.basename(f)}: 무음이라 건너뜀")
            continue
        todo.append((f, wav, sec))
    if not todo:
        print("확인할 녹음이 없어요"); return
    subprocess.run(["adb", "shell", "mkdir", "-p", BOARD], check=True)
    subprocess.run(["adb", "push"] + [t[1] for t in todo] + [BOARD + "/"], check=True, stdout=subprocess.DEVNULL)
    async with websockets.connect(URL, max_size=None) as ws:
        for f, wav, sec in todo:
            m = await check(ws, os.path.basename(wav))
            print(f"\n■ {os.path.basename(f)}  ({sec:.1f}초, STT {m.get('stt_ms', '?')}ms)")
            print(f"  받아쓴 글: {m.get('heard') or m.get('error')}")


asyncio.run(main())
