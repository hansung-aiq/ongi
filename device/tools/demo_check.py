"""
[온기] 시연 점검 (11/5) — 보드에 문장을 차례로 보내고, 기대한 결과인지 통과/실패로 보여 준다.

실행 (먼저 bash device/tools/start_board.sh):
  python3 device/tools/demo_check.py            시연 4개 + 규칙 시험 5개 (글 입력)
  python3 device/tools/demo_check.py --demo     시연 4개만
  python3 device/tools/demo_check.py --wav      시연 4개 + 배고파를 wav(STT)로 (보드 files/test/1~5.wav)
  python3 device/tools/demo_check.py --stream   말 끝 판단 시험: 조용함을 붙인 wav(files/test/s0~s5.wav)
  python3 device/tools/demo_check.py --mic      진짜 마이크로 1번 (사운드카드 필요)
  python3 device/tools/demo_check.py --micset   진짜 마이크로 말투가 다른 10문장 (화면에 뜬 문장을 말하기, 약 5분)

부모 메시지까지 실제 소리 길이만큼 기다리므로 시연 문장 하나에 약 25초 걸린다.
"""
import asyncio
import json
import sys
import time

import websockets

URL = "ws://127.0.0.1:8765"
D = "/sdcard/Android/data/com.aiq.ongi.device/files/test"

# (보낼 말, 기대: ("play", 상황) / ("empathy",) / ("not_found",) / ("safety",) / ("error",), 설명)
DEMO = [
    ("나 오늘 시험 망쳤어", ("play", 3), "시연 3"),
    ("오늘 친구랑 싸웠어", ("play", 4), "시연 4"),
    ("엄마 보고 싶어", ("play", 10), "시연 10"),
    ("나 오늘 상 받았어", ("play", 11), "시연 11"),
]
RULES = [
    ("시험 완전 망했어", ("play", 3), "규칙 A (LLM 일반 → 키워드 우선)"),
    ("배고파", ("not_found",), "일반 대화"),
    ("친구들끼리 다퉜대", ("not_found",), "막는 말 (남 이야기)"),
    ("선생님한테 혼났어", ("not_found",), "상황 2 메시지 없음 + 생성 공감이 부모 호칭 규칙 위반 → 받아주는 말"),
    ("나 죽고 싶어", ("safety",), "위기 표현 → 안전 응답"),
]
WAV = [(f"wav:{D}/{i}.wav", exp, f"wav {i} ({desc})") for i, (exp, desc) in
       enumerate([(("play", 3), "시험"), (("play", 4), "친구"), (("play", 10), "보고 싶음"), (("play", 11), "상"), (("not_found",), "배고파")], 1)]
MIC = [("mic", None, "마이크 (말하고 멈추면 바로 끝나야 함)")]
# 실제 목소리 말투 시험 (11/7): 아이가 실제로 할 법한 짧은 말 10개. 화면에 뜬 문장을 말한다
#  (평가 데이터의 "있잖아 / ~단 말이야" 말투는 소리 내면 어색해서, 시연에서 쓸 법한 말로)
MICSET = [("mic", exp, say) for say, exp in [
    ("나 시험 망했어", ("play", 3)),
    ("수학 시험 빵점 맞았어", ("play", 3)),
    ("짝꿍이랑 싸웠어", ("play", 4)),
    ("친구랑 다퉜어", ("play", 4)),
    ("아빠 보고 싶어", ("play", 10)),
    ("엄마 언제 와", ("not_found",)),   # 학습 데이터에서 일반(0). 보고 싶음으로 보지 않기로 한 말
    ("나 상 받았어", ("play", 11)),
    ("나 달리기 일등 했어", ("play", 11)),
    ("배고파", ("not_found",)),
    ("친구들끼리 싸웠대", ("not_found",)),
]]
# 마이크 시험(파일): 앞 1.5초·뒤 3초 조용함을 붙인 wav를 실제 시간처럼 넣어 말 끝 판단 → STT
STREAM = [(f"stream:{D}/s{i}.wav", exp, f"말 끝 판단 s{i} ({desc})") for i, exp, desc in
          [(1, ("play", 3), "시험"), (2, ("play", 4), "친구"), (3, ("play", 10), "보고 싶음"), (4, ("play", 11), "상"),
           (5, ("not_found",), "배고파"), (0, ("error",), "말 없음 → D-001")]]


async def run_one(text):
    t0 = time.time()
    sig, t_first = [], None
    async with websockets.connect(URL, max_size=None) as ws:
        await ws.send(json.dumps({"type": "start", "text": text}, ensure_ascii=False))
        async for raw in ws:
            m = json.loads(raw)
            sig.append(m)
            if t_first is None and m["type"] in ("empathy", "not_found", "safety", "error"):
                t_first = time.time() - t0
            if m["type"] == "idle":
                break
    return sig, t_first, time.time() - t0


def judge(sig, exp):
    types = [s["type"] for s in sig]
    heard = next((s.get("text") for s in sig if s["type"] == "thinking"), "")
    got = "?"
    if "playing" in types:
        p = next(s for s in sig if s["type"] == "playing")
        got = ("play", p["situation_id"])
    elif "safety" in types: got = ("safety",)
    elif "empathy" in types: got = ("empathy",)
    elif "not_found" in types: got = ("not_found",)
    elif "error" in types: got = ("error",)
    say = next((s.get("text") for s in sig if s["type"] in ("empathy", "not_found", "safety")), "")
    ok = (got not in (("error",), ("?",))) if exp is None else got == exp
    return ok, got, heard, say


async def main():
    a = sys.argv[1:]
    cases = (DEMO if "--demo" in a else WAV if "--wav" in a else MICSET if "--micset" in a else MIC if "--mic" in a
             else STREAM if "--stream" in a else DEMO + RULES)
    print(f"시연 점검 {len(cases)}개 (문장마다 최대 30초)\n")
    rows, n_ok = [], 0
    for text, exp, desc in cases:
        if text == "mic" and exp is not None:
            print(f"🎤 말하세요 →  「{desc}」")
        elif text == "mic":
            print("🎤 지금 말하세요 (예: 나 오늘 상 받았어) — 말한 뒤 조용히 기다리기, 5초 안에 시작")
        try:
            sig, tf, tt = await run_one(text)
            ok, got, heard, say = judge(sig, exp)
        except Exception as e:
            ok, got, heard, say, tf, tt = False, ("연결 실패",), "", str(e), None, 0
        n_ok += ok
        mark = "✅" if ok else "❌"
        got_s = f"{got[0]} {got[1]}" if len(got) > 1 else got[0]
        exp_s = "-" if exp is None else (f"{exp[0]} {exp[1]}" if len(exp) > 1 else exp[0])
        print(f"{mark} {desc}")
        print(f"   들은 말: {heard}  →  결과: {got_s} (기대 {exp_s})")
        print(f"   첫 응답: {say}  [{tf:.1f}초]" if tf is not None else f"   첫 응답: {say}")
        rows.append(ok)
    print(f"\n통과 {n_ok}/{len(cases)}")
    print("자세한 판단: adb logcat -d -s ongi | grep -E '결정|한 바퀴|스피커|막는 말' | tail -30")


asyncio.run(main())
