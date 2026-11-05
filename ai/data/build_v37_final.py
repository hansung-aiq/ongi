"""v3.7 최종 제출본: 학습 849 + 띄어쓰기 변형(약 25%) → CSV, JSON
- 문장 내용·정답은 그대로. 띄어쓰기만 STT처럼 바꿈 (예: "친 구랑 싸웠어", "망쳤 어", "시험망쳤어")
- 변형은 원문과 다른 글이어야 하고, 학습·평가 어떤 문장과도 같으면 안 됨
- 평가 183은 그대로 (변형 안 함)
"""
import random, json, csv, sys
import pandas as pd
SRC = "ai/data/제출용/00_온기_학습데이터_v3.7.xlsx"
EVAL = "ai/data/제출용/00_온기_평가데이터_v3.7.xlsx"
OUT = "ai/data/제출용/v3.7_최종/"
PREFIX = "<|im_start|>"
HEAD = ("Below is the query from the users, please choose the correct function "
        "and generate the parameters to call the function. Query: ")
TAIL = " Response:"
RATE = 0.25
rnd = random.Random(37)

def split_word(q):          # 한 낱말 안을 띄움: 친구랑 → 친 구랑, 망쳤어 → 망쳤 어
    ws = q.split(" "); idx = [i for i, w in enumerate(ws) if len(w) >= 2]
    if not idx: return None
    i = rnd.choice(idx); w = ws[i]; k = rnd.randint(1, len(w) - 1)
    ws[i] = w[:k] + " " + w[k:]; return " ".join(ws)
def join_two(q):            # 두 낱말을 붙임: 시험 망쳤어 → 시험망쳤어
    ws = q.split(" ")
    if len(ws) < 2: return None
    i = rnd.randrange(len(ws) - 1); ws[i:i+2] = [ws[i] + ws[i+1]]; return " ".join(ws)
def join_all(q):            # 띄어쓰기 없음
    return q.replace(" ", "") if " " in q else None
def mixed(q):               # 붙이고 다른 곳 띄우기
    a = join_two(q); return split_word(a) if a else None
KINDS = [(split_word, 0.45), (join_two, 0.25), (join_all, 0.15), (mixed, 0.15)]

tr = pd.read_excel(SRC); ev = pd.read_excel(EVAL)
seen = set(tr["Query(한글)"]) | set(ev["Query(한글)"])
pick = sorted(rnd.sample(range(len(tr)), round(len(tr) * RATE)))
rows = [dict(No=0, 기능명=r["기능명"], LLM_Output=r["LLM Output"], Query=r["Query(한글)"], 구분="원본", 원문="")
        for _, r in tr.iterrows()]
made = 0
for i in pick:
    r = tr.iloc[i]; q = r["Query(한글)"]
    for _ in range(10):
        f = rnd.choices([k[0] for k in KINDS], [k[1] for k in KINDS])[0]
        v = f(q)
        if v and v != q and v not in seen and v.strip() == v and "  " not in v: break
    else:
        continue
    seen.add(v); made += 1
    rows.append(dict(No=0, 기능명=r["기능명"], LLM_Output=r["LLM Output"], Query=v, 구분="띄어쓰기변형", 원문=q))
for n, r in enumerate(rows, 1): r["No"] = n

def write(rows, name, extra):
    cols = ["No", "기능명", "LLM Output", "Query(한글)"] + extra
    with open(OUT + name + ".csv", "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f); w.writerow(cols)
        for r in rows: w.writerow([r["No"], r["기능명"], r["LLM_Output"], r["Query"]] + [r[c] for c in extra])
    js = [{"no": r["No"], "function": r["기능명"], "query": r["Query"],
           "prompt": PREFIX + HEAD + r["Query"] + TAIL, "output": r["LLM_Output"],
           **({"type": r["구분"]} if "구분" in extra else {})} for r in rows]
    with open(OUT + name + ".json", "w", encoding="utf-8") as f:
        json.dump(js, f, ensure_ascii=False, indent=1)
write(rows, "온기_학습데이터_v3.7_최종", ["구분", "원문"])
erows = [dict(No=r["No"], 기능명=r["기능명"], LLM_Output=r["LLM Output"], Query=r["Query(한글)"]) for _, r in ev.iterrows()]
write(erows, "온기_평가데이터_v3.7", [])
print("원본", len(tr), "변형", made, "합계", len(rows), "/ 평가", len(erows))
