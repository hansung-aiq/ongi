"""
[온기] 보드 LLM 평가 (11/7) — 평가 183문장을 보드 Genie에 넣고 Colab과 같은 기준으로 채점한다.

실행 (먼저 start_board.sh 또는 swap_llm.sh, 화면 LLM 버튼이 "Genie"):
  python3 device/tools/llm_eval.py                 183문장 전부 (문장당 1초 안팎 → 약 3~5분)
  python3 device/tools/llm_eval.py --limit 10      앞 10개만 (빨리 확인)
  python3 device/tools/llm_eval.py --fake          가짜 LLM이어도 돌림 (도구 시험용)
결과: _local/llm_eval/결과_<시각>.csv  (Colab 병합 fp16 기준: 175/183, 형식 깨짐 0, 상황 113/120, 일반 62/63)

채점 (make_train_nb.py score와 같음):
  형식  <maum_0>(situation=n, feeling=m)<maum_sep>공감<maum_end> 또는 <maum_1>()<maum_end>
        Genie는 eos(<maum_end>)를 출력에 안 넣으므로 끝에 없으면 붙여서 본다(따로 셈)
  상황  정답이 상황인 문장: 상황 번호가 같으면 맞음 / 일반  정답이 일반인 문장: <maum_1>()이면 맞음
  공감 규칙 위반: 25자 넘음(띄어쓰기 빼고) 또는 물음표 / 호칭: 공감이 "엄마"·"아빠"로 시작(11/5 미정 항목)
다른 점: 보드는 아이 말 끝의 ?·. 를 떼고 60자로 자른 뒤 넣는다(GenieLlm.infer, 실제 흐름과 같게).
"""
import asyncio, csv, json, os, re, sys, time
import websockets

URL = "ws://127.0.0.1:8765"
CSV = "ai/data/제출용/v3.7_최종/온기_평가데이터_v3.7.csv"
P = re.compile(r'^<maum_0>\(situation=(\d+), feeling=(-?\d+)\)<maum_sep>(.+)<maum_end>$', re.S)
G = re.compile(r'^<maum_1>\(\)<maum_end>$')
TAILS = ("<|eot_id|>", "<|end_of_text|>")


def sit(o):
    m = P.match(o)
    return int(m[1]) if m else 0


def norm(raw):
    y = raw.strip()
    for t in TAILS:
        if y.endswith(t):
            y = y[: -len(t)].strip()
    added = not y.endswith("<maum_end>")
    return (y + "<maum_end>" if added else y), added


async def main():
    a = sys.argv[1:]
    limit = int(a[a.index("--limit") + 1]) if "--limit" in a else None
    rows = list(csv.DictReader(open(CSV, encoding="utf-8-sig")))[:limit]
    os.makedirs("_local/llm_eval", exist_ok=True)
    out_path = f"_local/llm_eval/결과_{time.strftime('%m%d_%H%M')}.csv"
    c = dict(형식=0, 상황=0, 상황n=0, 일반=0, 일반n=0, 규칙위반=0, 호칭=0, 끝없음=0, 오류=0)
    res, ms = [], []
    print(f"보드 LLM 평가 {len(rows)}문장\n")
    async with websockets.connect(URL, max_size=None) as ws:
        for i, r in enumerate(rows, 1):
            q, gold = r["Query(한글)"], r["LLM Output"]
            for _ in range(20):
                await ws.send(json.dumps({"type": "check", "text": q, "llm": True}, ensure_ascii=False))
                o = json.loads(await asyncio.wait_for(ws.recv(), 40))
                if o.get("error") != "busy":
                    break
                await asyncio.sleep(1.5)
            if i == 1 and not o.get("llm_genie") and "--fake" not in a:
                print("❌ 지금 보드 LLM이 가짜예요(Genie 아님). 화면 LLM 버튼을 Genie로 하거나 swap_llm.sh를 먼저. (도구 시험이면 --fake)")
                return
            raw = o.get("llm_raw", "ERROR: " + str(o.get("error")))
            if raw.startswith("ERROR"):
                c["오류"] += 1
            y, added = norm(raw)
            c["끝없음"] += added
            fmt = bool(P.match(y) or G.match(y)); c["형식"] += fmt
            g, p = sit(gold), sit(y)
            if g:
                c["상황n"] += 1; c["상황"] += (p == g); hit = p == g and fmt
            else:
                c["일반n"] += 1; hit = bool(G.match(y)); c["일반"] += hit
            emp, viol, title = "", False, False
            if p:
                emp = P.match(y)[3]
                viol = len(emp.replace(" ", "")) > 25 or "?" in emp
                title = emp.startswith(("엄마", "아빠"))
                c["규칙위반"] += viol; c["호칭"] += title
            if o.get("llm_ms") is not None:
                ms.append(o["llm_ms"])
            res.append(dict(No=r.get("No", i), Query=q, 정답=gold, 출력=raw, 맞음=hit, 형식=fmt, 정답상황=g, 출력상황=p,
                            공감=emp, 규칙위반=viol, 호칭=title, 키워드판단=o.get("by"), 키워드상황=o.get("situation"),
                            ms=o.get("llm_ms")))
            print(f"\r  {i}/{len(rows)}  맞음 {sum(x['맞음'] for x in res)}", end="", flush=True)
    with open(out_path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(res[0].keys())); w.writeheader(); w.writerows(res)
    n = len(res); right = sum(x["맞음"] for x in res)
    print(f"\n\n[보드 Genie] 맞음 {right}/{n} ({right / n * 100:.1f}%)  형식 {c['형식']}/{n}  상황 {c['상황']}/{c['상황n']}  일반 {c['일반']}/{c['일반n']}")
    print(f"  공감 규칙 위반 {c['규칙위반']}  호칭 붙음 {c['호칭']}  <maum_end> 없이 끝남 {c['끝없음']}  오류 {c['오류']}")
    if ms:
        s = sorted(ms); print(f"  LLM 시간: 중간 {s[len(s) // 2]}ms / 가장 느림 {s[-1]}ms")
    print("  (Colab 병합 fp16: 175/183 = 95.6%, 형식 183/183, 상황 113/120, 일반 62/63)")
    bad = [x for x in res if not x["맞음"]]
    if bad:
        print(f"\n틀린 것 {len(bad)}개 (앞 15개):")
        for x in bad[:15]:
            kw = f"  [키워드 {x['키워드상황']}]" if x["키워드판단"] in ("keyword", "embedding") else ""
            print(f"  - {x['Query']}  정답 {x['정답상황'] or '일반'} → 출력 {x['출력상황'] or ('일반' if G.match(norm(x['출력'])[0]) else '형식 깨짐')}{kw}")
    print(f"\n결과 파일: {out_path}")


asyncio.run(main())
