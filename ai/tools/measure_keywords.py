"""
[온기] 키워드 판단 측정 (DEV-07 재측정용)

device/android/app/src/main/assets/situations.json 을 KeywordJudge.kt 와 같은 방식으로 읽어
학습·평가 데이터에서 맞힘·틀림·잘못 잡음을 센다.

  띄어쓰기를 지우고 비교 → block 있으면 그 상황 아님 → exclude 부분을 지우고 keywords 검사
  여러 상황이 걸리면 priority 순서로 첫 번째

사용 (ai/tools에서):
  python3 measure_keywords.py ../data/00_온기_학습데이터_v3.5.1.xlsx
  → 화면에 요약, 같은 폴더에 keyword_결과.csv(틀린 문장·잘못 잡은 문장)
"""
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

import pandas as pd

HERE = Path(__file__).resolve().parent
SITU = HERE.parent.parent / "device/android/app/src/main/assets/situations.json"
P = re.compile(r"<maum_(\d)>\((?:situation=(-?\d+), feeling=(-?\d+))?\)")


def load(path=SITU):
    cfg = json.load(open(path, encoding="utf-8"))
    sq = lambda s: s.replace(" ", "")
    rules = [dict(id=s["id"], kw=[sq(k) for k in s.get("keywords", [])], ex=[sq(k) for k in s.get("exclude", [])],
                  bl=[sq(k) for k in s.get("block", [])]) for s in cfg["situations"]]
    return rules, cfg.get("priority", [])


def matches(text, rules, priority):
    base = text.replace(" ", "")
    hit = set()
    for r in rules:
        if any(b in base for b in r["bl"]):
            continue
        t = base
        for e in r["ex"]:
            t = t.replace(e, " ")
        if any(k in t for k in r["kw"]):
            hit.add(r["id"])
    return [p for p in priority if p in hit] + sorted(h for h in hit if h not in priority)


def gold(out):
    m = P.search(str(out))
    if not m:
        return None
    return 0 if m.group(1) == "1" else int(m.group(2))


def measure(df, rules, priority, name, bad):
    rows = [(q, gold(o)) for q, o in zip(df["Query(한글)"], df["LLM Output"])]
    situ = [(q, g) for q, g in rows if g and g > 0]
    other = [(q, g) for q, g in rows if g is not None and g <= 0]
    hit = right = wrong = 0
    miss_by = Counter()
    for q, g in situ:
        m = matches(q, rules, priority)
        if not m:
            miss_by[g] += 1
            continue
        hit += 1
        if m[0] == g:
            right += 1
        else:
            wrong += 1
            bad.append([name, "다른 상황으로 판단", q, g, m[0], m])
    false = 0
    for q, g in other:
        m = matches(q, rules, priority)
        if m:
            false += 1
            bad.append([name, "일반·불명확인데 잡음", q, g, m[0], m])
    n = len(situ)
    print(f"[{name}] 상황 발화 {n}: 키워드로 판단 {hit} ({hit / n * 100:.1f}%), 그중 맞음 {right}, 다른 상황 {wrong}"
          f" / 상황 맞힘 {right / n * 100:.1f}% / 일반·불명확 {len(other)} 중 잘못 잡음 {false}")
    print("   못 잡은 문장(임베딩으로 넘어감) 상황별:", dict(sorted(miss_by.items())))


def main():
    xlsx = sys.argv[1]
    rules, priority = load()
    bad = []
    for sheet, name in [("Function_Data_싱글턴", "학습"), ("Eval_Set", "평가")]:
        measure(pd.read_excel(xlsx, sheet_name=sheet), rules, priority, name, bad)
    out = HERE / "keyword_결과.csv"
    with open(out, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["데이터", "종류", "아이 말", "정답", "판단", "걸린 상황"])
        w.writerows(bad)
    print(f"틀린·잘못 잡은 문장 {len(bad)}개 → {out}")


if __name__ == "__main__":
    main()
