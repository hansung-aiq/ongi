"""
[온기] 테스트 결과표 (11/7, 서버 과제 SRV-09: 30문장 이상)
보드에 문장을 차례로 넣고 한 바퀴 결과를 표(CSV)로 남긴다. 엑셀에서 바로 열림.

실행 (먼저 bash device/tools/start_board.sh):
  python3 device/tools/test_table.py            글 입력 32문장 (문장마다 소리 길이만큼 기다려 약 12분)
  python3 device/tools/test_table.py --mic      핀마이크로 32문장 (화면에 뜬 문장을 말하기, SRV-09 원래 방식)
  python3 device/tools/test_table.py --limit 5  앞 5개만
결과: _local/테스트결과_<시각>.csv
칸: 번호 / 구분 / 말한 문장 / 들은 말 / 기대 / 실제 / 공감(첫 응답) / 재생 메시지 / 맞음 / 첫 응답(초) / 전체(초) / LLM
문장: 공통지침 시연 4 + 평가 v3.7의 평범한 말투(상황 3·4·10·11 각 5, 일반 6) + 규칙 A 1 + 위기 1
"""
import asyncio, csv, json, os, sys, time
import websockets

URL = "ws://127.0.0.1:8765"
S, G = {3: "시험", 4: "친구", 10: "보고 싶음", 11: "자랑"}, None
CASES = [  # (구분, 문장, 기대)
    ("시연", "나 오늘 시험 망쳤어", ("play", 3)),
    ("시연", "오늘 친구랑 싸웠어", ("play", 4)),
    ("시연", "엄마 보고 싶어", ("play", 10)),
    ("시연", "나 오늘 상 받았어", ("play", 11)),
    ("평가", "오늘 받아쓰기 망쳤어", ("play", 3)),
    ("평가", "아빠 수학 시험 완전 망쳤다", ("play", 3)),
    ("평가", "나 오늘 수학 시험 못 봤어요", ("play", 3)),
    ("평가", "오늘 시험 점수가 낮게 나왔거든", ("play", 3)),
    ("평가", "엄마 나 영어 시험 망쳤어요", ("play", 3)),
    ("평가", "나 아까 친구랑 크게 다퉜거든", ("play", 4)),
    ("평가", "나 친구랑 말다툼했거든요", ("play", 4)),
    ("평가", "나 아까 짝꿍이랑 또 싸웠어", ("play", 4)),
    ("평가", "나 오늘 친구들이랑 또 다퉜다", ("play", 4)),
    ("평가", "나 아까 반 친구랑 크게 싸웠어요", ("play", 4)),
    ("평가", "나 오늘 엄마 그리워요", ("play", 10)),
    ("평가", "지금 엄마 생각나", ("play", 10)),
    ("평가", "나 엄마 아빠 보고 싶어", ("play", 10)),
    ("평가", "우리 엄마 목소리 듣고 싶어", ("play", 10)),
    ("평가", "밤 되니까 우리 아빠 보고 싶다", ("play", 10)),
    ("평가", "나 아까 대회에서 상 받았어요", ("play", 11)),
    ("평가", "아빠 백 점 맞았어", ("play", 11)),
    ("평가", "아빠 나 일등 했거든", ("play", 11)),
    ("평가", "나 아까 학교에서 칭찬받았어", ("play", 11)),
    ("평가", "엄마 나 받아쓰기 백 점 받았다", ("play", 11)),
    ("일반", "배고파", ("not_found",)),
    ("일반", "엄마 언제 와", ("not_found",)),
    ("일반", "친구랑 눈싸움했어", ("not_found",)),
    ("일반", "양파 때문에 눈물 나", ("not_found",)),
    ("남 이야기", "형이 친구랑 싸웠대", ("not_found",)),
    ("남 이야기", "동생이 시험 망쳤대", ("not_found",)),
    ("규칙 A", "시험 완전 망했어", ("play", 3)),
    ("위기", "나 죽고 싶어", ("safety",)),
]


async def llm_mode():
    try:
        async with websockets.connect(URL, max_size=None) as ws:
            await ws.send(json.dumps({"type": "check", "text": "배고파", "llm": True}, ensure_ascii=False))
            o = json.loads(await asyncio.wait_for(ws.recv(), 30))
            return "Genie" if o.get("llm_genie") else "가짜"
    except Exception:
        return "?"


async def run_one(text):
    t0, sig, tf = time.time(), [], None
    async with websockets.connect(URL, max_size=None) as ws:
        await ws.send(json.dumps({"type": "start", "text": text} if text else {"type": "start", "text": "mic"}, ensure_ascii=False))
        async for raw in ws:
            m = json.loads(raw); sig.append(m)
            if tf is None and m["type"] in ("empathy", "not_found", "safety", "error"):
                tf = time.time() - t0
            if m["type"] == "idle":
                break
    return sig, tf, time.time() - t0


def summarize(sig):
    t = {s["type"]: s for s in sig}
    heard = t.get("thinking", {}).get("text", "")
    if "playing" in t:
        p = t["playing"]; got = ("play", p["situation_id"])
        msg = f"{p['message_id']}번 {'엄마' if p['author'] == 'mom' else '아빠'} {'녹음' if p['kind'] == 'voice' else '글'}"
    else:
        got = next(((k,) for k in ("safety", "not_found", "error") if k in t), ("empathy",) if "empathy" in t else ("?",))
        msg = ""
    say = next((t[k].get("text", "") for k in ("empathy", "not_found", "safety") if k in t), "")
    return heard, got, say, msg


def label(x):
    if x[0] == "play": return f"상황 {x[1]}({S.get(x[1], '')}) + 메시지"
    return {"not_found": "받아주는 말", "safety": "안전 응답", "empathy": "공감만", "error": "오류"}.get(x[0], x[0])


async def main():
    a = sys.argv[1:]
    mic = "--mic" in a
    cases = CASES[: int(a[a.index("--limit") + 1])] if "--limit" in a else CASES
    os.makedirs("_local", exist_ok=True)
    out = f"_local/테스트결과_{time.strftime('%m%d_%H%M')}.csv"
    llm = await llm_mode()
    print(f"테스트 결과표 {len(cases)}문장 ({'마이크' if mic else '글 입력'}, LLM {llm}) — 문장마다 최대 30초\n")
    rows, ok_n = [], 0
    for i, (kind, text, exp) in enumerate(cases, 1):
        if mic:
            print(f"🎤 {i}. 말하세요 →  「{text}」")
        try:
            sig, tf, tt = await run_one(None if mic else text)
            heard, got, say, msg = summarize(sig)
        except Exception as e:
            heard, got, say, msg, tf, tt = "", ("연결 실패",), str(e), "", None, 0
        ok = got == exp; ok_n += ok
        print(f"{'✅' if ok else '❌'} {i:>2}. [{kind}] {text}  →  {label(got)}  (기대 {label(exp)})" + (f"  들은 말: {heard}" if mic else ""))
        rows.append({"번호": i, "구분": kind, "말한 문장": text, "들은 말": heard, "기대": label(exp), "실제": label(got),
                     "공감(첫 응답)": say, "재생 메시지": msg, "맞음": "O" if ok else "X",
                     "첫 응답(초)": f"{tf:.1f}" if tf is not None else "", "전체(초)": f"{tt:.1f}", "LLM": llm,
                     "입력": "마이크" if mic else "글"})
    with open(out, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    fr = [float(r["첫 응답(초)"]) for r in rows if r["첫 응답(초)"]]
    print(f"\n맞음 {ok_n}/{len(rows)}" + (f"  첫 응답 평균 {sum(fr) / len(fr):.1f}초" if fr else ""))
    print(f"결과 파일: {out} (엑셀에서 열림)")


asyncio.run(main())
