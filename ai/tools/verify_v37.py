"""v3.7 자동 검사(시연 4개 상황): 공감 규칙, 같은 문장 3번, 학습·평가 겹침, 키워드 판단"""
import re, sys, json
from collections import Counter
sys.path.insert(0, sys.argv[2])
import openpyxl, check_empathy as ce, measure_keywords as mk
DEMO = {3, 4, 10, 11}
rules = ce.load_rules()
P = re.compile(r"<maum_0>\(situation=(\d+), feeling=(-?\d+)\)<maum_sep>(.+)<maum_end>")
wb = openpyxl.load_workbook(sys.argv[1], read_only=True)
data = {s: list(wb[s].iter_rows(values_only=True))[1:] for s in ["Function_Data_싱글턴", "Eval_Set"]}
bad = 0
for s, rows in data.items():
    same = Counter()
    for r in rows:
        m = P.match(r[2] or "")
        if not m:
            continue
        sid, f, emp = int(m[1]), m[2], m[3]
        same[(sid, f, emp)] += 1
        rs = ce.check(emp, f, rules, query=r[3])
        if rs: bad += 1; print("규칙", s, r[3], "→", emp, rs)
    for k, v in same.items():
        if v > 3 and s.startswith("Func"): bad += 1; print("같은 문장", v, k)
tq = [r[3] for r in data["Function_Data_싱글턴"]]; eq = [r[3] for r in data["Eval_Set"]]
ov = set(tq) & set(eq); dup = [q for q, c in Counter(tq).items() if c > 1]
print("겹침", len(ov), list(ov)[:5], "/ 학습 안 중복", len(dup))
bad += len(ov) + len(dup)
kr, pr = mk.load()
for s, rows in data.items():
    ok = wrong = miss = fp = 0
    for r in rows:
        g = mk.gold(r[2]); hit = mk.matches(r[3], kr, pr); got = hit[0] if hit else 0
        if g > 0:
            if got == g: ok += 1
            elif got == 0: miss += 1; print("  키워드 못 잡음", s[:4], g, r[3])
            else: wrong += 1; print("  키워드 다른 상황", s[:4], g, got, r[3])
        elif got in DEMO: fp += 1; print("  일반인데 시연 상황으로 잡음", s[:4], got, r[3])
    print(f"키워드 {s}: 맞힘 {ok}/{ok+wrong+miss}, 다른 상황 {wrong}, 못 잡음 {miss}, 일반 잘못 잡음 {fp}")
print("자동 검사 위반", bad)
