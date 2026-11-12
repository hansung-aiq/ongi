"""v3.4 xlsx → (review_fixes: 11/2 검수) → (v35_changes: 정확도 보강) → v3.5.1 xlsx.
자동 검사(형식·공감 규칙·반복·평가 겹침)까지. 공감 규칙은 ai/tools/check_empathy.py(기기와 같은 규칙).
사용 (ai/data에서):
  python3 build_v35.py 00_온기_학습데이터_v3.4.xlsx <v3.3_참고자료.xlsx> 00_온기_학습데이터_v3.5.1.xlsx
  → 같은 폴더에 제출용 2개도 만든다: 제출용/00_온기_학습데이터_v3.5.1.xlsx(탭 하나), 제출용/00_온기_평가데이터_v3.5.1.xlsx
"""
import sys, re
import pandas as pd
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE)); sys.path.insert(0, str(HERE.parent / "tools"))
from review_fixes import FIXES
from v35_changes import GEN_FIX, EVAL_LABEL, OVERLAP, REPEAT_FIX, ADD
import check_empathy
RULES = check_empathy.load_rules()

def check_line(line, feeling, query=""):
    r = check_empathy.check(line, feeling, RULES, query)
    return (not r), " / ".join(r), False

src, ref, out = sys.argv[1:4]
tr = pd.read_excel(src, sheet_name="Function_Data_싱글턴")
ev = pd.read_excel(src, sheet_name="Eval_Set")
xl = pd.ExcelFile(src)
rv = pd.read_excel(xl, sheet_name="검수용") if "검수용" in xl.sheet_names else None
P0 = re.compile(r"^<maum_0>\(situation=(-?\d+), feeling=(-?\d+)\)<maum_sep>(.*?)<maum_end>$")
G1 = "<maum_1>()<maum_end>"
mk = lambda s, f, line: f"<maum_0>(situation={s}, feeling={f})<maum_sep>{line}<maum_end>"
log = []   # 바뀐 것 기록 (검수용)

def set_line(df, i, new, why, sheet):
    m = P0.match(df.at[i, "LLM Output"]); old = m.group(3)
    df.at[i, "LLM Output"] = mk(m.group(1), m.group(2), new)
    log.append(dict(시트=sheet, 상황=int(m.group(1)), 기분=int(m.group(2)), 아이말=df.at[i, "Query(한글)"], 이전=old, 새=new, 이유=why))

# 0) 11/2 샘플 검수 반영 (의문문·검수 X → v3.4.1)
for name, df in [("학습", tr), ("평가", ev)]:
    for i, q in df["Query(한글)"].items():
        if q in FIXES and P0.match(df.at[i, "LLM Output"]):
            set_line(df, i, FIXES[q], "검수 X·의문문(v3.4.1)", name)

# 1) 두루뭉술한 공감 정답
used = set()
for name, df in [("학습", tr), ("평가", ev)]:
    for i, q in df["Query(한글)"].items():
        if q in GEN_FIX and P0.match(df.at[i, "LLM Output"]):
            set_line(df, i, GEN_FIX[q], "두루뭉술한 정답", name); used.add(q)
miss = set(GEN_FIX) - used
assert not miss, f"GEN_FIX에 없는 아이 말: {miss}"

# 2) 평가 라벨
for i, q in ev["Query(한글)"].items():
    if q in EVAL_LABEL:
        s, f, line = EVAL_LABEL[q]; old = ev.at[i, "LLM Output"]
        ev.at[i, "LLM Output"] = mk(s, f, line)
        log.append(dict(시트="평가", 상황=s, 기분=f, 아이말=q, 이전=old, 새=ev.at[i, "LLM Output"], 이유="평가 라벨 고침(학습 관례)"))

# 3) 평가와 겹치는 학습 문장
for i, q in tr["Query(한글)"].items():
    if q in OVERLAP:
        tr.at[i, "Query(한글)"] = OVERLAP[q]
        log.append(dict(시트="학습", 상황=None, 기분=None, 아이말=OVERLAP[q], 이전=q, 새=OVERLAP[q], 이유="평가와 같은 문장 → 표현 바꿈"))

# 4) 반복 4번 이상
for (s, f, line), new in REPEAT_FIX.items():
    idx = [i for i, o in tr["LLM Output"].items() if (m := P0.match(o)) and int(m.group(1)) == s and int(m.group(2)) == f and m.group(3) == line]
    if len(idx) > 3: set_line(tr, idx[-1], new, "같은 문장 3번 초과", "학습")

# 5) 추가
known = set(tr["Query(한글)"]); evq = set(ev["Query(한글)"])
bd = pd.read_excel(ref, sheet_name="경계 평가·검사", header=None)
bdq = {r[3] for r in bd.values.tolist() if isinstance(r[2], str) and r[2].startswith("<maum")}
rows, skipped = [], []
for s, f, q, line in ADD:
    assert q not in evq and q not in bdq, f"평가·경계 문장과 같음: {q}"
    if q in known: skipped.append(q); continue
    known.add(q)
    rows.append({"No": 0, "기능명": "일반 대화" if s == 0 else "상황 말하기",
                 "LLM Output": G1 if s == 0 else mk(s, f, line), "Query(한글)": q})
    log.append(dict(시트="학습", 상황=s, 기분=f, 아이말=q, 이전=None, 새=line, 이유="추가"))
tr = pd.concat([tr, pd.DataFrame(rows)], ignore_index=True)
n0 = len(tr); tr = tr.drop_duplicates(["Query(한글)", "LLM Output"]).reset_index(drop=True)
if len(tr) < n0: print("완전히 같은 행 삭제:", n0 - len(tr))
tr["No"] = range(1, len(tr) + 1)

# ---- 자동 검사 ----
probs = []
for name, df in [("학습", tr), ("평가", ev)]:
    for q, o in zip(df["Query(한글)"], df["LLM Output"]):
        if o == G1: continue
        m = P0.match(o)
        if not m: probs.append((name, q, o, "형식")); continue
        s, f, line = int(m.group(1)), int(m.group(2)), m.group(3)
        ok, why, _ = check_line(line, f, q)
        if not ok: probs.append((name, q, line, why))
        if re.search("형|누나|언니|오빠|동생|사촌", q) and not re.search("친구|짝꿍|애들", q) and "친구" in line:
            probs.append((name, q, line, "형제 이야기에 친구"))
ext = tr["LLM Output"].str.extract(P0)
rep = ext.groupby([0, 1, 2]).size(); rep = rep[rep > 3]
dup_q = tr["Query(한글)"][tr["Query(한글)"].duplicated()].tolist()
over = set(tr["Query(한글)"]) & evq
print(f"학습 {len(tr)} / 평가 {len(ev)} / 추가 {len(rows)} (이미 있어 건너뜀 {len(skipped)}: {skipped})")
print("규칙·형식 문제:", probs if probs else 0)
print("같은 문장 3번 초과:", rep.to_dict() if len(rep) else 0)
print("학습 안 중복 문장:", dup_q if dup_q else 0, "/ 평가와 겹침:", over if over else 0)
lens = ext[2].dropna().str.len(); print("공감 문장 최대 글자:", lens.max())

lg = pd.DataFrame(log); lg["검수(O/X)"] = ""
with pd.ExcelWriter(out) as w:
    tr.to_excel(w, sheet_name="Function_Data_싱글턴", index=False)
    ev.to_excel(w, sheet_name="Eval_Set", index=False)
    lg.to_excel(w, sheet_name="v3.5 바뀐 것", index=False)
    if rv is not None: rv.to_excel(w, sheet_name="검수용(v3.4)", index=False)
print("저장:", out, "/ 바뀐 것", len(lg))

# 제출용 (마음AI: 탭 하나, 4열)
sub = Path(out).resolve().parent / "제출용"; sub.mkdir(exist_ok=True)
ver = Path(out).stem.split("_")[-1]
cols = ["No", "기능명", "LLM Output", "Query(한글)"]
t2 = tr[cols].copy(); t2["No"] = range(1, len(t2) + 1)
e2 = ev[cols].copy(); e2["No"] = range(1, len(e2) + 1)
with pd.ExcelWriter(sub / f"00_온기_학습데이터_{ver}.xlsx") as w: t2.to_excel(w, sheet_name="Function_Data_싱글턴", index=False)
with pd.ExcelWriter(sub / f"00_온기_평가데이터_{ver}.xlsx") as w: e2.to_excel(w, sheet_name="Eval_Set", index=False)
print("제출용:", sub)
